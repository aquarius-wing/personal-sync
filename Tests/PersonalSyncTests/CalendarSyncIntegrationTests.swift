import XCTest
@testable import PersonalSync
import EventKit

/// 集成测试示例：展示如何在测试中模拟日历环境
class CalendarSyncIntegrationTests: XCTestCase {
    
    var calendarSync: CalendarSync!
    var mockEventStore: MockEventStore!
    var testConfiguration: PersonalSyncConfiguration!
    
    override func setUpWithError() throws {
        // Setup mock event store
        mockEventStore = MockEventStore()
        
                // Setup test configuration
        testConfiguration = PersonalSyncConfiguration(
            enableNotificationSync: true,
            enableBackgroundSync: false,
            autoStart: false,
            enableLogging: true
        )
    }
    
    override func tearDownWithError() throws {
        calendarSync?.stopSync()
        // Clear callbacks to prevent retain cycles
        calendarSync?.onSyncStatusChanged = nil
        calendarSync?.onEventUpdated = nil
        calendarSync = nil
        mockEventStore = nil
    }
    
    /// 测试完整的日历同步流程
    func testCompleteCalendarSyncFlow() throws {
        // 1. 创建测试日历
        let workCalendar = mockEventStore.addMockCalendar(identifier: "work-calendar", title: "工作日历")
        let personalCalendar = mockEventStore.addMockCalendar(identifier: "personal-calendar", title: "个人日历")
        
        // 2. 添加初始事件
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        mockEventStore.addMockEvent(
            identifier: "meeting-1",
            title: "项目会议",
            startDate: today,
            endDate: Date(timeInterval: 3600, since: today),
            calendar: workCalendar
        )
        
        mockEventStore.addMockEvent(
            identifier: "lunch-1", 
            title: "午餐约会",
            startDate: tomorrow,
            endDate: Date(timeInterval: 3600, since: tomorrow),
            calendar: personalCalendar
        )
        
        // 3. 创建并启动同步
        calendarSync = try CalendarSync(configuration: testConfiguration, eventStore: mockEventStore)
        
        // 4. 启动同步（测试模式，跳过权限检查）
        calendarSync.startSyncForTesting()
        
        // 5. 执行初始同步并验证
        print("\n执行初始同步...")
        var syncCallbackCount = 0
        let initialSyncExpectation = expectation(description: "Initial sync completed")
        
        calendarSync.onSyncStatusChanged = { status in
            print("同步状态变化: \(status)")
            if case .synced = status {
                syncCallbackCount += 1
                // Only fulfill once to avoid multiple fulfillment
                if syncCallbackCount == 1 {
                    initialSyncExpectation.fulfill()
                }
            }
        }
        
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        wait(for: [initialSyncExpectation], timeout: 5.0)
        
        // 6. 验证初始同步结果
        let syncedEvents = try calendarSync.getAllEvents()
        XCTAssertEqual(syncedEvents.count, 2, "应该有2个同步的事件")
        XCTAssertTrue(syncedEvents.contains { $0.title == "项目会议" }, "应该包含项目会议")
        XCTAssertTrue(syncedEvents.contains { $0.title == "午餐约会" }, "应该包含午餐约会")
        
        // 7. 模拟日历更新：添加新事件
        print("\n模拟添加新事件...")
        syncCallbackCount = 0
        let updateSyncExpectation = expectation(description: "Update sync completed")
        
        calendarSync.onSyncStatusChanged = { status in
            if case .synced = status {
                syncCallbackCount += 1
                if syncCallbackCount == 1 {
                    updateSyncExpectation.fulfill()
                }
            }
        }
        
        mockEventStore.addMockEvent(
            identifier: "new-meeting",
            title: "紧急会议", 
            startDate: Date(timeInterval: 7200, since: today),
            endDate: Date(timeInterval: 10800, since: today),
            calendar: workCalendar
        )
        
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        wait(for: [updateSyncExpectation], timeout: 5.0)
        
        // 8. 验证新事件已同步
        let updatedEvents = try calendarSync.getAllEvents()
        XCTAssertEqual(updatedEvents.count, 3, "应该有3个事件")
        XCTAssertTrue(updatedEvents.contains { $0.title == "紧急会议" }, "应该包含紧急会议")
        
        // 9. 模拟事件更新
        print("\n模拟更新事件...")
        syncCallbackCount = 0
        mockEventStore.updateMockEvent(identifier: "meeting-1", newTitle: "项目会议 (已更新)")
        
        let modifySyncExpectation = expectation(description: "Modify sync completed")
        calendarSync.onSyncStatusChanged = { status in
            if case .synced = status {
                syncCallbackCount += 1
                if syncCallbackCount == 1 {
                    modifySyncExpectation.fulfill()
                }
            }
        }
        
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        wait(for: [modifySyncExpectation], timeout: 5.0)
        
        // 10. 验证事件更新
        let modifiedEvents = try calendarSync.getAllEvents()
        XCTAssertTrue(modifiedEvents.contains { $0.title == "项目会议 (已更新)" }, "应该包含更新后的会议标题")
        XCTAssertFalse(modifiedEvents.contains { $0.title == "项目会议" }, "不应该包含旧的会议标题")
        
        // 11. 模拟事件删除
        print("\n模拟删除事件...")
        syncCallbackCount = 0
        mockEventStore.removeMockEvent(identifier: "lunch-1")
        
        let deleteSyncExpectation = expectation(description: "Delete sync completed")
        calendarSync.onSyncStatusChanged = { status in
            if case .synced = status {
                syncCallbackCount += 1
                if syncCallbackCount == 1 {
                    deleteSyncExpectation.fulfill()
                }
            }
        }
        
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        wait(for: [deleteSyncExpectation], timeout: 5.0)
        
        // 12. 验证事件删除
        let finalEvents = try calendarSync.getAllEvents()
        XCTAssertEqual(finalEvents.count, 2, "删除后应该有2个事件")
        XCTAssertFalse(finalEvents.contains { $0.title == "午餐约会" }, "不应该包含已删除的午餐约会")
        
        print("\n✅ 完整的日历同步流程测试通过！")
        print("最终事件数量: \(finalEvents.count)")
        for event in finalEvents {
            print("- \(event.title ?? "未知事件")")
        }
    }
    
    /// 测试通知系统的响应
    func testNotificationResponse() throws {
        let calendar = mockEventStore.addMockCalendar(identifier: "test-calendar", title: "测试日历")
        
        calendarSync = try CalendarSync(
            configuration: PersonalSyncConfiguration(
                enableNotificationSync: true,
                enableBackgroundSync: false,
                autoStart: false,
                enableLogging: true
            ),
            eventStore: mockEventStore
        )
        
        // 设置通知监听
        var notificationReceived = false
        mockEventStore.onCalendarChanged = {
            notificationReceived = true
            print("📱 收到日历变化通知")
        }
        
        calendarSync.startSyncForTesting()
        
        // 模拟日历变化
        mockEventStore.addMockEvent(
            identifier: "notification-test",
            title: "通知测试事件",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 3600),
            calendar: calendar
        )
        
        // 触发通知
        mockEventStore.simulateCalendarChange()
        
        // 等待通知处理
        let expectation = XCTestExpectation(description: "Notification processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // 验证通知被接收
        XCTAssertTrue(notificationReceived, "应该收到日历变化通知")
        
        print("✅ 通知系统测试通过！")
    }
} 