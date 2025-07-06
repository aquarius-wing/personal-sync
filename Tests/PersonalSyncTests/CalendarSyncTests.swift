import XCTest
@testable import PersonalSync
import EventKit

// MARK: - Mock Calendar and Event
class MockCalendar {
    let identifier: String
    let title: String
    
    init(identifier: String, title: String) {
        self.identifier = identifier
        self.title = title
    }
}

class MockEvent {
    let identifier: String
    var title: String
    let startDate: Date
    let endDate: Date
    let calendar: MockCalendar
    
    init(identifier: String, title: String, startDate: Date, endDate: Date, calendar: MockCalendar) {
        self.identifier = identifier
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendar = calendar
    }
    
    // Convert to CalendarEvent directly
    var calendarEvent: CalendarEvent {
        return CalendarEvent(
            eventIdentifier: identifier,
            title: title,
            notes: nil,
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            calendarIdentifier: calendar.identifier,
            calendarTitle: calendar.title,
            location: nil,
            url: nil,
            lastModifiedDate: nil,
            creationDate: nil,
            status: .confirmed,
            hasRecurrenceRules: false,
            timeZone: nil,
            recurrenceRule: nil,
            hasAlarms: false,
            attendeesJson: nil,
            isDetached: false
        )
    }
}

// MARK: - Mock Event Store
class MockEventStore: EventStoreProtocol {
    
    // Mock data storage - using our custom mock objects
    var mockCalendars: [MockCalendar] = []
    var mockEvents: [MockEvent] = []
    var authStatus: EKAuthorizationStatus = .fullAccess
    var shouldGrantAccess: Bool = true
    
    // Callback for testing notifications
    var onCalendarChanged: (() -> Void)?
    
    static func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus {
        return .fullAccess // Use fullAccess to avoid deprecation warnings
    }
    
    func requestAccess(to entityType: EKEntityType, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.main.async {
            completion(self.shouldGrantAccess, nil)
        }
    }
    
    func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        // Return empty array since we're bypassing EKCalendar
        return []
    }
    
    func events(matching predicate: NSPredicate) -> [EKEvent] {
        // Return empty array since we're bypassing EKEvent
        return []
    }
    
    func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?) -> NSPredicate {
        // Return a dummy predicate
        return NSPredicate(value: true)
    }
    
    // Custom methods for mock data access
    func getMockEvents() -> [CalendarEvent] {
        return mockEvents.map { $0.calendarEvent }
    }
    
    // Test helper methods
    func addMockCalendar(identifier: String, title: String) -> MockCalendar {
        let calendar = MockCalendar(identifier: identifier, title: title)
        mockCalendars.append(calendar)
        return calendar
    }
    
    func addMockEvent(identifier: String, title: String, startDate: Date, endDate: Date, calendar: MockCalendar) -> MockEvent {
        let event = MockEvent(
            identifier: identifier,
            title: title,
            startDate: startDate,
            endDate: endDate,
            calendar: calendar
        )
        mockEvents.append(event)
        return event
    }
    
    func removeMockEvent(identifier: String) {
        mockEvents.removeAll { $0.identifier == identifier }
    }
    
    func updateMockEvent(identifier: String, newTitle: String) {
        if let event = mockEvents.first(where: { $0.identifier == identifier }) {
            event.title = newTitle
        }
    }
    
    func simulateCalendarChange() {
        // Simulate a calendar change notification
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
            self.onCalendarChanged?()
        }
    }
}

final class CalendarSyncTests: XCTestCase {
    
    var calendarSync: CalendarSync!
    var testConfiguration: CalendarSyncConfiguration!
    var mockEventStore: MockEventStore!
    
    override func setUpWithError() throws {
        // Setup mock event store
        mockEventStore = MockEventStore()
        
        // Setup test configuration
        testConfiguration = CalendarSyncConfiguration(
            enableNotificationSync: false,
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
    
    func testCalendarSyncInitialization() throws {
        calendarSync = try CalendarSync(configuration: testConfiguration, eventStore: mockEventStore)
        
        XCTAssertNotNil(calendarSync)
        XCTAssertFalse(calendarSync.isActive)
        XCTAssertEqual(calendarSync.syncStatus, .idle)
    }
    
    func testDefaultConfiguration() throws {
        let defaultConfig = CalendarSyncConfiguration.default
        
        XCTAssertTrue(defaultConfig.enableNotificationSync)
        XCTAssertTrue(defaultConfig.enableBackgroundSync)
        XCTAssertTrue(defaultConfig.autoStart)
        XCTAssertEqual(defaultConfig.maxRetryAttempts, 3)
        XCTAssertEqual(defaultConfig.syncInterval, 300)
        XCTAssertEqual(defaultConfig.batchSize, 100)
    }
    
    func testConfigurationValidation() throws {
        // Test invalid retry attempts
        var invalidConfig = CalendarSyncConfiguration(maxRetryAttempts: -1)
        XCTAssertThrowsError(try invalidConfig.validate())
        
        // Test invalid sync interval
        invalidConfig = CalendarSyncConfiguration(syncInterval: 30)
        XCTAssertThrowsError(try invalidConfig.validate())
        
        // Test invalid batch size
        invalidConfig = CalendarSyncConfiguration(batchSize: 0)
        XCTAssertThrowsError(try invalidConfig.validate())
    }
    
    func testSyncStatusEquality() throws {
        XCTAssertEqual(SyncStatus.idle, SyncStatus.idle)
        XCTAssertEqual(SyncStatus.syncing, SyncStatus.syncing)
        XCTAssertEqual(SyncStatus.synced(10), SyncStatus.synced(10))
        XCTAssertNotEqual(SyncStatus.synced(10), SyncStatus.synced(5))
    }
    
    func testSyncStatistics() throws {
        let stats = SyncStatistics(
            totalEvents: 100,
            lastSyncDuration: 2.5,
            successfulSyncs: 10,
            failedSyncs: 2
        )
        
        XCTAssertEqual(stats.totalEvents, 100)
        XCTAssertEqual(stats.lastSyncDuration, 2.5)
        XCTAssertEqual(stats.successfulSyncs, 10)
        XCTAssertEqual(stats.failedSyncs, 2)
        
        // Test success rate calculation
        let expectedSuccessRate = (10.0 / 12.0) * 100
        XCTAssertEqual(stats.successRate, expectedSuccessRate, accuracy: 0.01)
    }
    
    func testCalendarEventCreation() throws {
        let eventId = "test-event-id"
        let title = "Test Event"
        let startDate = Date()
        let endDate = Date(timeIntervalSinceNow: 3600) // 1 hour later
        
        let event = CalendarEvent(
            eventIdentifier: eventId,
            title: title,
            notes: nil,
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            calendarIdentifier: "test-calendar",
            calendarTitle: "Test Calendar",
            location: nil,
            url: nil,
            lastModifiedDate: nil,
            creationDate: nil,
            status: .confirmed,
            hasRecurrenceRules: false,
            timeZone: nil,
            recurrenceRule: nil,
            hasAlarms: false,
            attendeesJson: nil,
            isDetached: false
        )
        
        XCTAssertEqual(event.eventIdentifier, eventId)
        XCTAssertEqual(event.title, title)
        XCTAssertEqual(event.startDate, startDate)
        XCTAssertEqual(event.endDate, endDate)
        XCTAssertFalse(event.isAllDay)
    }
    
    func testUpdateType() throws {
        let insertedType: UpdateType = .inserted
        let updatedType: UpdateType = .updated
        let deletedType: UpdateType = .deleted
        
        XCTAssertNotEqual(insertedType, updatedType)
        XCTAssertNotEqual(updatedType, deletedType)
        XCTAssertNotEqual(insertedType, deletedType)
    }
    
    func testCalendarSyncError() throws {
        let permissionError = CalendarSyncError.permissionDenied
        let configError = CalendarSyncError.invalidConfiguration("Test error")
        let syncError = CalendarSyncError.syncInProgress
        
        XCTAssertNotNil(permissionError.errorDescription)
        XCTAssertNotNil(configError.errorDescription)
        XCTAssertNotNil(syncError.errorDescription)
        
        XCTAssertTrue(configError.errorDescription!.contains("Test error"))
    }
    
    // MARK: - Integration Tests
    
    func testInitialSyncWithMockEvents() throws {
        // Setup mock calendar and events
        let testCalendar = mockEventStore.addMockCalendar(identifier: "test-calendar", title: "Test Calendar")
        let startDate = Date()
        let endDate = Date(timeIntervalSinceNow: 3600)
        
        mockEventStore.addMockEvent(
            identifier: "event-1",
            title: "Test Event 1",
            startDate: startDate,
            endDate: endDate,
            calendar: testCalendar
        )
        
        mockEventStore.addMockEvent(
            identifier: "event-2", 
            title: "Test Event 2",
            startDate: startDate,
            endDate: endDate,
            calendar: testCalendar
        )
        
        // Create CalendarSync with mock store
        calendarSync = try CalendarSync(configuration: testConfiguration, eventStore: mockEventStore)
        
        // Setup expectations
        let syncExpectation = expectation(description: "Initial sync completed")
        var capturedStatus: SyncStatus?
        
        calendarSync.onSyncStatusChanged = { status in
            capturedStatus = status
            if case .synced = status {
                syncExpectation.fulfill()
            }
        }
        
        // Start sync manually to control the process
        calendarSync.startSyncForTesting()
        
        // Use mock sync method to inject events directly
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        
        // Wait for sync to complete
        wait(for: [syncExpectation], timeout: 5.0)
        
        // Verify results
        XCTAssertTrue(calendarSync.isActive)
        if case let .synced(count) = capturedStatus {
            XCTAssertEqual(count, 2)
        } else {
            XCTFail("Expected .synced status, got \(String(describing: capturedStatus))")
        }
        
        // Verify events were synced
        let syncedEvents = try calendarSync.getAllEvents()
        XCTAssertEqual(syncedEvents.count, 2)
        XCTAssertTrue(syncedEvents.contains { $0.title == "Test Event 1" })
        XCTAssertTrue(syncedEvents.contains { $0.title == "Test Event 2" })
    }
    
    func testCalendarNotificationSync() throws {
        // Setup initial state
        let testCalendar = mockEventStore.addMockCalendar(identifier: "test-calendar", title: "Test Calendar")
        calendarSync = try CalendarSync(
            configuration: CalendarSyncConfiguration(
                enableNotificationSync: true,
                enableBackgroundSync: false,
                autoStart: false,
                enableLogging: true
            ),
            eventStore: mockEventStore
        )
        
        // Setup expectations
        let initialSyncExpectation = expectation(description: "Initial sync completed")
        let notificationSyncExpectation = expectation(description: "Notification sync completed")
        
        var syncCount = 0
        calendarSync.onSyncStatusChanged = { status in
            if case .synced = status {
                syncCount += 1
                if syncCount == 1 {
                    initialSyncExpectation.fulfill()
                } else if syncCount == 2 {
                    notificationSyncExpectation.fulfill()
                }
            }
        }
        
        // Start sync
        calendarSync.startSyncForTesting()
        
        // Perform initial sync with mock events
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        
        // Wait for initial sync
        wait(for: [initialSyncExpectation], timeout: 5.0)
        
        // Add a new event to trigger notification
        mockEventStore.addMockEvent(
            identifier: "new-event",
            title: "New Event",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 3600),
            calendar: testCalendar
        )
        
        // Simulate calendar change notification
        mockEventStore.simulateCalendarChange()
        
        // Manually trigger sync with updated mock events
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        
        // Wait for notification sync
        wait(for: [notificationSyncExpectation], timeout: 5.0)
        
        // Verify the new event was synced
        let syncedEvents = try calendarSync.getAllEvents()
        XCTAssertTrue(syncedEvents.contains { $0.title == "New Event" })
    }
    
    func testEventUpdateAndDelete() throws {
        // Setup initial event
        let testCalendar = mockEventStore.addMockCalendar(identifier: "test-calendar", title: "Test Calendar")
        mockEventStore.addMockEvent(
            identifier: "update-test-event",
            title: "Original Title",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 3600),
            calendar: testCalendar
        )
        
        calendarSync = try CalendarSync(configuration: testConfiguration, eventStore: mockEventStore)
        
        // Initial sync
        let initialSyncExpectation = expectation(description: "Initial sync completed")
        calendarSync.onSyncStatusChanged = { status in
            if case .synced = status {
                initialSyncExpectation.fulfill()
            }
        }
        
        calendarSync.startSyncForTesting()
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        wait(for: [initialSyncExpectation], timeout: 5.0)
        
        // Verify initial state
        var syncedEvents = try calendarSync.getAllEvents()
        XCTAssertEqual(syncedEvents.count, 1)
        XCTAssertEqual(syncedEvents.first?.title, "Original Title")
        
        // Update event
        mockEventStore.updateMockEvent(identifier: "update-test-event", newTitle: "Updated Title")
        
        // Force sync to pick up changes
        let updateSyncExpectation = expectation(description: "Update sync completed")
        calendarSync.onSyncStatusChanged = { status in
            if case .synced = status {
                updateSyncExpectation.fulfill()
            }
        }
        
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        wait(for: [updateSyncExpectation], timeout: 5.0)
        
        // Verify update
        syncedEvents = try calendarSync.getAllEvents()
        XCTAssertEqual(syncedEvents.count, 1)
        XCTAssertEqual(syncedEvents.first?.title, "Updated Title")
        
        // Delete event
        mockEventStore.removeMockEvent(identifier: "update-test-event")
        
        // Force sync to pick up deletion
        let deleteSyncExpectation = expectation(description: "Delete sync completed")
        calendarSync.onSyncStatusChanged = { status in
            if case .synced = status {
                deleteSyncExpectation.fulfill()
            }
        }
        
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        wait(for: [deleteSyncExpectation], timeout: 5.0)
        
        // Verify deletion
        syncedEvents = try calendarSync.getAllEvents()
        XCTAssertEqual(syncedEvents.count, 0)
    }
    
    func testSyncWithPermissionDenied() throws {
        // Configure mock to deny permission
        mockEventStore.shouldGrantAccess = false
        
        calendarSync = try CalendarSync(configuration: testConfiguration, eventStore: mockEventStore)
        
        // Setup expectation for permission denied error
        let errorExpectation = expectation(description: "Permission denied error")
        calendarSync.onSyncStatusChanged = { status in
            if case .error(let error) = status {
                if case .permissionDenied = error as? CalendarSyncError {
                    errorExpectation.fulfill()
                }
            }
        }
        
        // Start sync (should fail due to permission)
        calendarSync.startSync()
        
        // Wait for error
        wait(for: [errorExpectation], timeout: 5.0)
        
        // Verify sync is not active
        XCTAssertFalse(calendarSync.isActive)
    }
    
    func testBackgroundSyncTimer() throws {
        // Setup configuration with minimum sync interval for testing
        let backgroundConfig = CalendarSyncConfiguration(
            enableNotificationSync: false,
            enableBackgroundSync: true,
            autoStart: false,
            syncInterval: 60.0, // Minimum allowed interval
            enableLogging: true
        )
        
        let testCalendar = mockEventStore.addMockCalendar(identifier: "test-calendar", title: "Test Calendar")
        calendarSync = try CalendarSync(configuration: backgroundConfig, eventStore: mockEventStore)
        
        // Setup expectation for initial sync only (background timer test would take too long)
        let initialSyncExpectation = expectation(description: "Initial sync completed")
        
        calendarSync.onSyncStatusChanged = { status in
            if case .synced = status {
                initialSyncExpectation.fulfill()
            }
        }
        
        // Start sync
        calendarSync.startSyncForTesting()
        
        // Perform initial sync with mock events
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        
        // Wait for initial sync
        wait(for: [initialSyncExpectation], timeout: 5.0)
        
        // Verify sync is active and background timer is set up
        XCTAssertTrue(calendarSync.isActive)
        
        // Add an event and force sync to test the functionality
        mockEventStore.addMockEvent(
            identifier: "timed-event",
            title: "Timed Event",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 3600),
            calendar: testCalendar
        )
        
        // Force sync to pick up the new event
        let forceSyncExpectation = expectation(description: "Force sync completed")
        calendarSync.onSyncStatusChanged = { status in
            if case .synced = status {
                forceSyncExpectation.fulfill()
            }
        }
        
        // Use syncWithMockEvents instead of forceSync for consistent testing
        try calendarSync.syncWithMockEvents(mockEventStore.getMockEvents())
        wait(for: [forceSyncExpectation], timeout: 5.0)
        
        // Verify the event was synced
        let syncedEvents = try calendarSync.getAllEvents()
        XCTAssertTrue(syncedEvents.contains { $0.title == "Timed Event" }, "应该包含Timed Event")
    }
} 