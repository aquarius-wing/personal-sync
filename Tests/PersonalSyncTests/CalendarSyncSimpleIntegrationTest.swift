import XCTest
@testable import PersonalSync
import EventKit

/// 简化的集成测试示例：展示如何在测试中模拟日历环境
class CalendarSyncSimpleIntegrationTest: XCTestCase {
    
    var calendarSync: CalendarSync!
    var mockEventStore: MockEventStore!
    
    override func setUpWithError() throws {
        mockEventStore = MockEventStore()
    }
    
    override func tearDownWithError() throws {
        calendarSync?.stopSync()
        // Clear callbacks to prevent retain cycles
        calendarSync?.onSyncStatusChanged = nil
        calendarSync?.onEventUpdated = nil
        calendarSync = nil
        mockEventStore = nil
    }
    
    /// 基本的模拟日历同步测试
    func testBasicMockCalendarSync() throws {
        print("🧪 开始基本模拟日历同步测试")
        
        // 1. 创建测试日历和事件
        let testCalendar = mockEventStore.addMockCalendar(identifier: "test-cal", title: "测试日历")
        
        mockEventStore.addMockEvent(
            identifier: "event-1",
            title: "会议",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 3600),
            calendar: testCalendar
        )
        
        print("📅 创建了1个测试事件")
        
        // 2. 创建 CalendarSync 实例
        let config = CalendarSyncConfiguration(
            enableNotificationSync: false,
            enableBackgroundSync: false,
            autoStart: false,
            enableLogging: true
        )
        
        calendarSync = try CalendarSync(configuration: config, eventStore: mockEventStore)
        
        // 3. 设置同步状态监听
        let syncExpectation = expectation(description: "Sync completed")
        
        calendarSync.onSyncStatusChanged = { status in
            print("📊 同步状态: \(status)")
            if case .synced(let count) = status {
                print("✅ 同步完成，事件数量: \(count)")
                syncExpectation.fulfill()
            }
        }
        
        // 4. 启动同步
        calendarSync.startSyncForTesting()
        
        // 5. 执行 mock 同步
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        
        // 6. 等待同步完成
        wait(for: [syncExpectation], timeout: 5.0)
        
        // 7. 验证结果
        let events = try calendarSync.getAllEvents()
        XCTAssertEqual(events.count, 1, "应该有1个同步的事件")
        XCTAssertEqual(events.first?.title, "会议", "事件标题应该匹配")
        
        print("✅ 基本同步测试通过！")
    }
    
    /// 测试事件添加和删除
    func testEventAdditionAndDeletion() throws {
        print("🧪 开始事件添加和删除测试")
        
        let testCalendar = mockEventStore.addMockCalendar(identifier: "test-cal", title: "测试日历")
        
        // 创建 CalendarSync
        let config = CalendarSyncConfiguration(
            enableNotificationSync: false,
            enableBackgroundSync: false,
            autoStart: false,
            enableLogging: true
        )
        
        calendarSync = try CalendarSync(configuration: config, eventStore: mockEventStore)
        calendarSync.startSyncForTesting()
        
        // 步骤1：初始同步（空状态）
        try calendarSync.syncWithMockEvents([])
        var events = try calendarSync.getAllEvents()
        XCTAssertEqual(events.count, 0, "初始状态应该没有事件")
        print("📊 初始同步完成，事件数量: 0")
        
        // 步骤2：添加一个事件
        mockEventStore.addMockEvent(
            identifier: "event-1",
            title: "新会议",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 3600),
            calendar: testCalendar
        )
        
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        events = try calendarSync.getAllEvents()
        XCTAssertEqual(events.count, 1, "应该有1个事件")
        print("📊 添加事件后，事件数量: 1")
        
        // 步骤3：再添加一个事件
        mockEventStore.addMockEvent(
            identifier: "event-2", 
            title: "另一个会议",
            startDate: Date(timeIntervalSinceNow: 7200),
            endDate: Date(timeIntervalSinceNow: 10800),
            calendar: testCalendar
        )
        
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        events = try calendarSync.getAllEvents()
        XCTAssertEqual(events.count, 2, "应该有2个事件")
        print("📊 再次添加事件后，事件数量: 2")
        
        // 步骤4：删除一个事件
        mockEventStore.removeMockEvent(identifier: "event-1")
        
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        events = try calendarSync.getAllEvents()
        XCTAssertEqual(events.count, 1, "应该有1个事件")
        XCTAssertEqual(events.first?.title, "另一个会议", "剩余的应该是第二个事件")
        print("📊 删除事件后，事件数量: 1")
        
        print("✅ 事件添加和删除测试通过！")
    }
    
    /// 测试事件更新
    func testEventUpdate() throws {
        print("🧪 开始事件更新测试")
        
        let testCalendar = mockEventStore.addMockCalendar(identifier: "test-cal", title: "测试日历")
        
        // 添加初始事件
        mockEventStore.addMockEvent(
            identifier: "updatable-event",
            title: "原始标题",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 3600),
            calendar: testCalendar
        )
        
        // 创建 CalendarSync
        let config = CalendarSyncConfiguration(
            enableNotificationSync: false,
            enableBackgroundSync: false,
            autoStart: false,
            enableLogging: true
        )
        
        calendarSync = try CalendarSync(configuration: config, eventStore: mockEventStore)
        calendarSync.startSyncForTesting()
        
        // 初始同步
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        var events = try calendarSync.getAllEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.title, "原始标题")
        print("📊 初始同步完成，事件标题: 原始标题")
        
        // 更新事件标题
        mockEventStore.updateMockEvent(identifier: "updatable-event", newTitle: "更新后的标题")
        
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        events = try calendarSync.getAllEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.title, "更新后的标题")
        print("📊 更新后，事件标题: 更新后的标题")
        
        print("✅ 事件更新测试通过！")
    }
    
    /// 测试同步统计功能
    func testSyncStatistics() throws {
        print("🧪 开始同步统计测试")
        
        let testCalendar = mockEventStore.addMockCalendar(identifier: "test-cal", title: "测试日历")
        
        mockEventStore.addMockEvent(
            identifier: "stats-event",
            title: "统计测试事件",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 3600),
            calendar: testCalendar
        )
        
        // 创建 CalendarSync
        let config = CalendarSyncConfiguration(
            enableNotificationSync: false,
            enableBackgroundSync: false,
            autoStart: false,
            enableLogging: true
        )
        
        calendarSync = try CalendarSync(configuration: config, eventStore: mockEventStore)
        calendarSync.startSyncForTesting()
        
        // 执行同步
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        
        // 检查统计数据
        let stats = calendarSync.syncStatistics
        XCTAssertEqual(stats.totalEvents, 1, "总事件数应该为1")
        XCTAssertEqual(stats.successfulSyncs, 1, "成功同步次数应该为1")
        XCTAssertEqual(stats.failedSyncs, 0, "失败同步次数应该为0")
        XCTAssertGreaterThan(stats.lastSyncDuration, 0, "同步持续时间应该大于0")
        
        print("📊 同步统计: \(stats.totalEvents) 事件, \(stats.successfulSyncs) 成功, \(stats.failedSyncs) 失败")
        print("📊 上次同步时长: \(stats.lastSyncDuration) 秒")
        print("✅ 同步统计测试通过！")
    }
} 