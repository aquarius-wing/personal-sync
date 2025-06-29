import XCTest
@testable import CalendarSync

final class CalendarSyncTests: XCTestCase {
    
    var calendarSync: CalendarSync!
    var testConfiguration: CalendarSyncConfiguration!
    
    override func setUpWithError() throws {
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
        calendarSync = nil
    }
    
    func testCalendarSyncInitialization() throws {
        calendarSync = try CalendarSync(configuration: testConfiguration)
        
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
            hasRecurrenceRules: false
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
} 