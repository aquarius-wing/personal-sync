import Foundation
import EventKit
import GRDB

/// Update type for event callbacks
public enum UpdateType {
    case inserted
    case updated
    case deleted
}

/// Main CalendarSync class that handles automatic calendar synchronization
public class CalendarSync {
    
    // MARK: - Properties
    
    /// Configuration
    private let configuration: CalendarSyncConfiguration
    
    /// Database manager
    private let databaseManager: DatabaseManager
    
    /// Event store for accessing system calendar
    private let eventStore: EKEventStore
    
    /// Current sync status
    private var _syncStatus: SyncStatus = .idle
    private let statusQueue = DispatchQueue(label: "com.calendarsync.status", attributes: .concurrent)
    
    /// Sync statistics
    private var _syncStatistics: SyncStatistics = SyncStatistics()
    private let statisticsQueue = DispatchQueue(label: "com.calendarsync.statistics", attributes: .concurrent)
    
    /// Background sync timer
    private var syncTimer: Timer?
    
    /// Debounce timer for sync notifications
    private var syncDebounceTimer: Timer?
    
    /// Is sync currently active
    private var _isActive: Bool = false
    private let activeQueue = DispatchQueue(label: "com.calendarsync.active", attributes: .concurrent)
    
    /// Sync operation queue
    private let syncQueue = DispatchQueue(label: "com.calendarsync.operations", qos: .background)
    
    /// Notification observer token
    private var notificationObserver: NSObjectProtocol?
    
    /// Retry count for failed operations
    private var retryCount: Int = 0
    
    // MARK: - Public Properties
    
    /// Current sync status
    public var syncStatus: SyncStatus {
        return statusQueue.sync { _syncStatus }
    }
    
    /// Sync statistics
    public var syncStatistics: SyncStatistics {
        return statisticsQueue.sync { _syncStatistics }
    }
    
    /// Is sync currently active
    public var isActive: Bool {
        return activeQueue.sync { _isActive }
    }
    
    /// Last sync time
    public var lastSyncTime: Date? {
        return try? databaseManager.getLastSyncTime()
    }
    
    // MARK: - Callbacks
    
    /// Sync status change callback
    public var onSyncStatusChanged: ((SyncStatus) -> Void)?
    
    /// Event update callback
    public var onEventUpdated: ((CalendarEvent, UpdateType) -> Void)?
    
    // MARK: - Initialization
    
    /// Initialize with default configuration
    public convenience init() throws {
        try self.init(configuration: .default)
    }
    
    /// Initialize with custom configuration
    public init(configuration: CalendarSyncConfiguration = .default) throws {
        self.configuration = configuration
        self.eventStore = EKEventStore()
        
        // Validate configuration
        try configuration.validate()
        
        // Initialize database manager
        self.databaseManager = try DatabaseManager(configuration: configuration)
        
        // Auto start if configured
        if configuration.autoStart {
            DispatchQueue.main.async {
                self.startSync()
            }
        }
    }
    
    deinit {
        stopSync()
    }
    
    // MARK: - Public Methods
    
    /// Start automatic synchronization
    public func startSync() {
        guard !isActive else { return }
        
        setActive(true)
        
        // Request calendar permission
        requestCalendarPermission { [weak self] granted in
            guard let self = self, granted else {
                self?.updateSyncStatus(.error(CalendarSyncError.permissionDenied))
                return
            }
            
            // Setup notification observer
            if self.configuration.enableNotificationSync {
                self.setupNotificationObserver()
            }
            
            // Setup background sync timer
            if self.configuration.enableBackgroundSync {
                self.setupBackgroundSync()
            }
            
            // Perform initial sync
            self.performSync()
        }
    }
    
    /// Stop automatic synchronization
    public func stopSync() {
        setActive(false)
        
        // Remove notification observer
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        
        // Stop background sync timer
        syncTimer?.invalidate()
        syncTimer = nil
        
        // Stop debounce timer
        syncDebounceTimer?.invalidate()
        syncDebounceTimer = nil
        
        updateSyncStatus(.idle)
    }
    
    /// Pause synchronization
    public func pause() {
        syncTimer?.invalidate()
        syncTimer = nil
        updateSyncStatus(.idle)
    }
    
    /// Resume synchronization
    public func resume() {
        guard isActive else { return }
        
        if configuration.enableBackgroundSync {
            setupBackgroundSync()
        }
        
        performSync()
    }
    
    /// Force immediate synchronization
    public func forceSync() {
        performSync()
    }
    
    // MARK: - Query Methods
    
    /// Get all synchronized events
    public func getAllEvents() throws -> [CalendarEvent] {
        return try databaseManager.getAllEvents()
    }
    
    /// Get events in date range
    public func getEvents(from startDate: Date, to endDate: Date) throws -> [CalendarEvent] {
        return try databaseManager.getEvents(from: startDate, to: endDate)
    }
    
    /// Get today's events
    public func getTodayEvents() throws -> [CalendarEvent] {
        return try databaseManager.getTodayEvents()
    }
    
    /// Get upcoming events
    public func getUpcomingEvents(limit: Int = 10) throws -> [CalendarEvent] {
        return try databaseManager.getUpcomingEvents(limit: limit)
    }
    
    /// Search events by keyword
    public func searchEvents(keyword: String) throws -> [CalendarEvent] {
        return try databaseManager.searchEvents(keyword: keyword)
    }
    
    /// Get events by calendar
    public func getEventsByCalendar(_ calendarIdentifier: String) throws -> [CalendarEvent] {
        return try databaseManager.getEventsByCalendar(calendarIdentifier)
    }
    
    // MARK: - Private Methods
    
    private func setActive(_ active: Bool) {
        activeQueue.async(flags: .barrier) {
            self._isActive = active
        }
    }
    
    private func updateSyncStatus(_ status: SyncStatus) {
        statusQueue.async(flags: .barrier) {
            self._syncStatus = status
            
            DispatchQueue.main.async {
                self.onSyncStatusChanged?(status)
            }
        }
    }
    
    private func updateSyncStatistics(_ statistics: SyncStatistics) {
        statisticsQueue.async(flags: .barrier) {
            self._syncStatistics = statistics
        }
    }
    
    private func requestCalendarPermission(completion: @escaping (Bool) -> Void) {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .authorized:
            completion(true)
        case .fullAccess:
            completion(true)
        case .writeOnly:
            completion(true) // Write-only access is sufficient for sync
        case .notDetermined:
            eventStore.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: nil
        ) { [weak self] _ in
            // Calendar data changed, trigger sync with debounce
            self?.scheduleDelayedSync()
        }
    }
    
    private func scheduleDelayedSync() {
        // Cancel existing delayed sync if any
        syncDebounceTimer?.invalidate()
        
        // Schedule new sync with 1 second delay to avoid duplicate notifications
        syncDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.performSync()
        }
    }
    
    private func setupBackgroundSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: configuration.syncInterval, repeats: true) { [weak self] _ in
            self?.performSync()
        }
    }
    
    private func performSync() {
        print("performSync")
        guard isActive else { return }
        
        // Prevent concurrent sync operations
        guard syncStatus != .syncing else {
            if configuration.enableLogging {
                print("Sync already in progress, skipping")
            }
            return
        }
        
        updateSyncStatus(.syncing)
        
        syncQueue.async { [weak self] in
            self?.executeSyncOperation()
        }
    }
    
    private func executeSyncOperation() {
        let startTime = Date()
        
        do {
            // Get calendars to sync
            let calendarsToSync = try getCalendarsToSync()
            
            // Get events from system calendar
            let systemEvents = try getSystemEvents(from: calendarsToSync)
            
            // Convert to CalendarEvent objects (syncedAt will be handled by DatabaseManager)
            let calendarEvents = systemEvents.map { CalendarEvent(from: $0) }
            
            // Remove duplicates based on eventIdentifier
            var uniqueEvents: [String: CalendarEvent] = [:]
            for event in calendarEvents {
                uniqueEvents[event.eventIdentifier] = event
            }
            let uniqueCalendarEvents = Array(uniqueEvents.values)
            
            if configuration.enableLogging && calendarEvents.count != uniqueCalendarEvents.count {
                print("Removed \(calendarEvents.count - uniqueCalendarEvents.count) duplicate events")
            }
            
            // Get existing events from database
            let existingEvents = try databaseManager.getAllEvents()
            let existingIdentifiers = Set(existingEvents.map { $0.eventIdentifier })
            let systemIdentifiers = Set(uniqueCalendarEvents.map { $0.eventIdentifier })
            
            // Find events to delete (no longer in system calendar)
            let eventsToDelete = existingIdentifiers.subtracting(systemIdentifiers)
            
            // Sync with database
            let syncResult = try databaseManager.syncEvents(
                uniqueCalendarEvents,
                removedIdentifiers: Array(eventsToDelete)
            )
            
            // Update statistics
            let duration = Date().timeIntervalSince(startTime)
            let totalEvents = try databaseManager.getTotalEventCount()
            
            let newStats = SyncStatistics(
                totalEvents: totalEvents,
                lastSyncDuration: duration,
                successfulSyncs: syncStatistics.successfulSyncs + 1,
                failedSyncs: syncStatistics.failedSyncs
            )
            
            updateSyncStatistics(newStats)
            
            // Notify about changes
            notifyEventUpdates(
                inserted: syncResult.inserted,
                updated: syncResult.updated,
                deleted: syncResult.deleted
            )
            
            // Reset retry count on success
            retryCount = 0
            
            updateSyncStatus(.synced(totalEvents))
            
            if configuration.enableLogging {
                print("Sync completed: \(syncResult.inserted) inserted, \(syncResult.updated) updated, \(syncResult.deleted) deleted")
            }
            
        } catch {
            handleSyncError(error)
        }
    }
    
    private func getCalendarsToSync() throws -> [EKCalendar] {
        let allCalendars = eventStore.calendars(for: .event)
        
        if let specificCalendarIds = configuration.calendarIdentifiers {
            return allCalendars.filter { specificCalendarIds.contains($0.calendarIdentifier) }
        } else {
            return allCalendars
        }
    }
    
    private func getSystemEvents(from calendars: [EKCalendar]) throws -> [EKEvent] {
        // Get events from a reasonable time range (1 year ago to 2 years ahead)
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let endDate = Calendar.current.date(byAdding: .year, value: 2, to: Date())!
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )
        
        return eventStore.events(matching: predicate)
    }
    
    private func handleSyncError(_ error: Error) {
        retryCount += 1
        
        if retryCount <= configuration.maxRetryAttempts {
            // Schedule retry after delay
            let delay = Double(retryCount) * 2.0 // Exponential backoff
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.performSync()
            }
            
            if configuration.enableLogging {
                print("Sync failed, retrying in \(delay) seconds (attempt \(retryCount)/\(configuration.maxRetryAttempts))")
            }
        } else {
            // Max retries reached
            retryCount = 0
            
            let newStats = SyncStatistics(
                totalEvents: syncStatistics.totalEvents,
                lastSyncDuration: syncStatistics.lastSyncDuration,
                successfulSyncs: syncStatistics.successfulSyncs,
                failedSyncs: syncStatistics.failedSyncs + 1
            )
            
            updateSyncStatistics(newStats)
            updateSyncStatus(.error(error))
            
            if configuration.enableLogging {
                print("Sync failed after \(configuration.maxRetryAttempts) attempts: \(error)")
            }
        }
    }
    
    private func notifyEventUpdates(inserted: Int, updated: Int, deleted: Int) {
        // This is a simplified notification - in a real implementation,
        // you might want to track specific events that changed
        DispatchQueue.main.async {
            // Placeholder for specific event update notifications
            // In a full implementation, you would track specific events that changed
            // and call self.onEventUpdated?(event, updateType) for each one
        }
    }
} 