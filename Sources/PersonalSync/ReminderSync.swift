import Foundation
import EventKit
import GRDB

/// Protocol for abstracting EventKit store for reminders testing
public protocol ReminderStoreProtocol {
    func requestAccess(to entityType: EKEntityType, completion: @escaping (Bool, Error?) -> Void)
    func calendars(for entityType: EKEntityType) -> [EKCalendar]
    func reminders(matching predicate: NSPredicate) -> [EKReminder]
    func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate
    static func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus
}

/// Extension to make EKEventStore conform to ReminderStoreProtocol
extension EKEventStore: ReminderStoreProtocol {
    public func reminders(matching predicate: NSPredicate) -> [EKReminder] {
        // This is a synchronous wrapper - in real implementation, you might want async handling
        var results: [EKReminder] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        fetchReminders(matching: predicate) { reminders in
            results = reminders ?? []
            semaphore.signal()
        }
        
        semaphore.wait()
        return results
    }
}

/// Update type for reminder callbacks
public enum ReminderUpdateType {
    case inserted
    case updated
    case deleted
}

/// Reminder synchronization status
public enum ReminderSyncStatus {
    case idle
    case syncing
    case synced
    case error(Error)
    
    public var isError: Bool {
        if case .error = self { return true }
        return false
    }
    
    public var errorDescription: String? {
        if case .error(let error) = self {
            return error.localizedDescription
        }
        return nil
    }
}

extension ReminderSyncStatus: Equatable {
    public static func == (lhs: ReminderSyncStatus, rhs: ReminderSyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.syncing, .syncing):
            return true
        case (.synced, .synced):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Reminder sync statistics
public struct ReminderSyncStatistics {
    public var totalReminders: Int = 0
    public var completedReminders: Int = 0
    public var overdueReminders: Int = 0
    public var todayReminders: Int = 0
    public var lastSyncTime: Date?
    public var syncDuration: TimeInterval = 0
    public var listsCount: Int = 0
    
    // Detailed sync statistics
    public var lastInserted: Int = 0
    public var lastUpdated: Int = 0
    public var lastDeleted: Int = 0
    
    public init() {}
}

/// Main ReminderSync class that handles automatic reminder synchronization
public class ReminderSync {
    
    // MARK: - Properties
    
    /// Configuration
    private let configuration: PersonalSyncConfiguration
    
    /// Database manager
    private let databaseManager: DatabaseManager
    
    /// Event store for accessing system reminders
    private let eventStore: ReminderStoreProtocol
    
    /// Current sync status
    private var _syncStatus: ReminderSyncStatus = .idle
    private let statusQueue = DispatchQueue(label: "com.remindersync.status", attributes: .concurrent)
    
    /// Sync statistics
    private var _syncStatistics: ReminderSyncStatistics = ReminderSyncStatistics()
    private let statisticsQueue = DispatchQueue(label: "com.remindersync.statistics", attributes: .concurrent)
    
    /// Background sync timer
    private var syncTimer: Timer?
    
    /// Debounce timer for sync notifications
    private var syncDebounceTimer: Timer?
    
    /// Is sync currently active
    private var _isActive: Bool = false
    private let activeQueue = DispatchQueue(label: "com.remindersync.active", attributes: .concurrent)
    
    /// Sync operation queue
    private let syncQueue = DispatchQueue(label: "com.remindersync.operations", qos: .background)
    
    /// Notification observer token
    private var notificationObserver: NSObjectProtocol?
    
    /// Retry count for failed operations
    private var retryCount: Int = 0
    
    // MARK: - Public Properties
    
    /// Current sync status
    public var syncStatus: ReminderSyncStatus {
        return statusQueue.sync { _syncStatus }
    }
    
    /// Sync statistics
    public var syncStatistics: ReminderSyncStatistics {
        return statisticsQueue.sync { _syncStatistics }
    }
    
    /// Is sync currently active
    public var isActive: Bool {
        return activeQueue.sync { _isActive }
    }
    
    /// Last sync time
    public var lastSyncTime: Date? {
        return try? databaseManager.getLastReminderSyncTime()
    }
    
    // MARK: - Callbacks
    
    /// Sync status change callback
    public var onSyncStatusChanged: ((ReminderSyncStatus) -> Void)?
    
    /// Reminder update callback
    public var onReminderUpdated: ((ReminderEvent, ReminderUpdateType) -> Void)?
    
    // MARK: - Initialization
    
    /// Initialize with default configuration
    public convenience init() throws {
        try self.init(configuration: .default)
    }
    
    /// Initialize with custom configuration
    public init(configuration: PersonalSyncConfiguration = .default, eventStore: ReminderStoreProtocol? = nil) throws {
        self.configuration = configuration
        self.eventStore = eventStore ?? EKEventStore()
        
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
        
        // Request reminder permission
        requestReminderPermission { [weak self] granted in
            guard let self = self, granted else {
                self?.updateSyncStatus(.error(PersonalSyncError.permissionDenied))
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
    
    /// Get all reminders
    public func getAllReminders() throws -> [ReminderEvent] {
        return try databaseManager.getAllReminders()
    }
    
    /// Get today's reminders
    public func getTodayReminders() throws -> [ReminderEvent] {
        return try databaseManager.getTodayReminders()
    }
    
    /// Get overdue reminders
    public func getOverdueReminders() throws -> [ReminderEvent] {
        return try databaseManager.getOverdueReminders()
    }
    
    /// Get upcoming reminders
    public func getUpcomingReminders(limit: Int = 10) throws -> [ReminderEvent] {
        return try databaseManager.getUpcomingReminders(limit: limit)
    }
    
    /// Get completed reminders
    public func getCompletedReminders() throws -> [ReminderEvent] {
        return try databaseManager.getCompletedReminders()
    }
    
    /// Get reminders by list
    public func getReminders(fromList listIdentifier: String) throws -> [ReminderEvent] {
        return try databaseManager.getReminders(fromList: listIdentifier)
    }
    
    /// Search reminders
    public func searchReminders(keyword: String, from: Date? = nil, to: Date? = nil, listIdentifierList: [String]? = nil) throws -> [ReminderEvent] {
        return try databaseManager.searchReminders(keyword: keyword, from: from, to: to, listIdentifierList: listIdentifierList)
    }
    
    /// Get high priority reminders
    public func getHighPriorityReminders() throws -> [ReminderEvent] {
        return try databaseManager.getHighPriorityReminders()
    }
    
    // MARK: - Private Methods
    
    /// Request reminder permission
    private func requestReminderPermission(completion: @escaping (Bool) -> Void) {
        let authStatus = type(of: eventStore).authorizationStatus(for: .reminder)
        
        switch authStatus {
        case .authorized:
            completion(true)
        case .notDetermined:
            eventStore.requestAccess(to: .reminder) { granted, _ in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }
    
    /// Setup notification observer for reminder changes
    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            self?.handleEventStoreChanged()
        }
    }
    
    /// Handle EventKit store changes
    private func handleEventStoreChanged() {
        // Debounce notifications
        syncDebounceTimer?.invalidate()
        syncDebounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.performSync()
        }
    }
    
    /// Setup background sync timer
    private func setupBackgroundSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: configuration.syncInterval, repeats: true) { [weak self] _ in
            self?.performSync()
        }
    }
    
    /// Perform sync operation
    private func performSync() {
        guard isActive else { return }
        
        syncQueue.async { [weak self] in
            self?.performSyncInternal()
        }
    }
    
    /// Internal sync implementation
    private func performSyncInternal() {
        let startTime = Date()
        
        do {
            updateSyncStatus(.syncing)
            
            if configuration.enableLogging {
                print("[ReminderSync] Starting reminder sync...")
            }
            
            // Get reminder lists
            let lists = eventStore.calendars(for: .reminder)
            
            // Filter lists if specific identifiers are provided
            let targetLists: [EKCalendar]
            if let identifiers = configuration.calendarIdentifiers {
                targetLists = lists.filter { identifiers.contains($0.calendarIdentifier) }
            } else {
                targetLists = lists
            }
            
            // Get all reminders from target lists
            let predicate = eventStore.predicateForReminders(in: targetLists.isEmpty ? nil : targetLists)
            let systemReminders = eventStore.reminders(matching: predicate)
            
            // Convert to ReminderEvent objects
            let reminderEvents = systemReminders.map { ReminderEvent(from: $0, syncedAt: Date()) }
            
            // Get existing reminders from database to determine what was removed
            let existingReminders = try databaseManager.getAllReminders()
            let existingIdentifiers = Set(existingReminders.map { $0.reminderIdentifier })
            let systemIdentifiers = Set(reminderEvents.map { $0.reminderIdentifier })
            
            // Find reminders to delete (no longer in system)
            let remindersToDelete = existingIdentifiers.subtracting(systemIdentifiers)
            
            // Sync with database using detailed method
            let syncResult = try databaseManager.syncReminders(
                reminderEvents,
                removedIdentifiers: Array(remindersToDelete)
            )
            
            // Update statistics
            updateStatistics(syncResult: syncResult, syncDuration: Date().timeIntervalSince(startTime))
            
            updateSyncStatus(.synced)
            retryCount = 0
            
            if configuration.enableLogging {
                print("[ReminderSync] Sync completed: \(syncResult.inserted) inserted, \(syncResult.updated) updated, \(syncResult.deleted) deleted")
            }
            
        } catch {
            handleSyncError(error)
        }
    }
    
    /// Handle sync errors
    private func handleSyncError(_ error: Error) {
        retryCount += 1
        
        if retryCount <= configuration.maxRetryAttempts {
            if configuration.enableLogging {
                print("Reminder sync failed, retrying... (\(retryCount)/\(configuration.maxRetryAttempts))")
            }
            
            // Retry after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount) * 2.0) { [weak self] in
                self?.performSync()
            }
        } else {
            if configuration.enableLogging {
                print("Reminder sync failed after \(configuration.maxRetryAttempts) attempts: \(error)")
            }
            
            updateSyncStatus(.error(error))
            retryCount = 0
        }
    }
    
    /// Update sync status
    private func updateSyncStatus(_ status: ReminderSyncStatus) {
        statusQueue.async(flags: .barrier) { [weak self] in
            self?._syncStatus = status
            
            DispatchQueue.main.async {
                self?.onSyncStatusChanged?(status)
            }
        }
    }
    
    /// Update statistics
    private func updateStatistics(syncResult: (inserted: Int, updated: Int, deleted: Int), syncDuration: TimeInterval) {
        statisticsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            do {
                let totalReminders = try self.databaseManager.getTotalReminderCount()
                let completedReminders = try self.databaseManager.getCompletedReminderCount()
                let overdueReminders = try self.databaseManager.getOverdueReminderCount()
                let todayReminders = try self.databaseManager.getTodayReminderCount()
                let listsCount = try self.databaseManager.getReminderListCount()
                
                self._syncStatistics = ReminderSyncStatistics()
                self._syncStatistics.totalReminders = totalReminders
                self._syncStatistics.completedReminders = completedReminders
                self._syncStatistics.overdueReminders = overdueReminders
                self._syncStatistics.todayReminders = todayReminders
                self._syncStatistics.lastSyncTime = Date()
                self._syncStatistics.syncDuration = syncDuration
                self._syncStatistics.listsCount = listsCount
                
                // Store detailed sync statistics
                self._syncStatistics.lastInserted = syncResult.inserted
                self._syncStatistics.lastUpdated = syncResult.updated
                self._syncStatistics.lastDeleted = syncResult.deleted
                
                // Save sync time to database
                try self.databaseManager.saveLastReminderSyncTime(Date())
                
                if self.configuration.enableLogging {
                    print("[ReminderSync] Statistics updated: Total: \(totalReminders), Completed: \(completedReminders), Overdue: \(overdueReminders)")
                }
                
            } catch {
                if self.configuration.enableLogging {
                    print("[ReminderSync] Failed to update reminder statistics: \(error)")
                }
            }
        }
    }
    
    /// Set active state
    private func setActive(_ active: Bool) {
        activeQueue.async(flags: .barrier) { [weak self] in
            self?._isActive = active
        }
    }
} 