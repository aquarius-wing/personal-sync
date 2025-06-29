import Foundation

/// Configuration for CalendarSync
public struct CalendarSyncConfiguration {
    /// Enable notification-based real-time sync
    public let enableNotificationSync: Bool
    
    /// Enable background sync
    public let enableBackgroundSync: Bool
    
    /// Specific calendar identifiers to sync, nil means sync all calendars
    public let calendarIdentifiers: [String]?
    
    /// Custom database path
    public let databasePath: String?
    
    /// Auto start sync after initialization
    public let autoStart: Bool
    
    /// Maximum retry attempts on sync failure
    public let maxRetryAttempts: Int
    
    /// Sync interval for periodic sync (in seconds)
    public let syncInterval: TimeInterval
    
    /// Enable verbose logging
    public let enableLogging: Bool
    
    /// Maximum events to process in one batch
    public let batchSize: Int
    
    /// Default configuration
    public static let `default` = CalendarSyncConfiguration()
    
    public init(
        enableNotificationSync: Bool = true,
        enableBackgroundSync: Bool = true,
        calendarIdentifiers: [String]? = nil,
        databasePath: String? = nil,
        autoStart: Bool = true,
        maxRetryAttempts: Int = 3,
        syncInterval: TimeInterval = 300, // 5 minutes
        enableLogging: Bool = false,
        batchSize: Int = 100
    ) {
        self.enableNotificationSync = enableNotificationSync
        self.enableBackgroundSync = enableBackgroundSync
        self.calendarIdentifiers = calendarIdentifiers
        self.databasePath = databasePath
        self.autoStart = autoStart
        self.maxRetryAttempts = maxRetryAttempts
        self.syncInterval = syncInterval
        self.enableLogging = enableLogging
        self.batchSize = batchSize
    }
    
    /// Get default database path
    public var effectiveDatabasePath: String {
        if let customPath = databasePath {
            return customPath
        }
        
        // Default to Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("CalendarSync.sqlite").path
    }
    
    /// Validate configuration
    public func validate() throws {
        if maxRetryAttempts < 0 {
            throw CalendarSyncError.invalidConfiguration("maxRetryAttempts must be >= 0")
        }
        
        if syncInterval < 60 {
            throw CalendarSyncError.invalidConfiguration("syncInterval must be >= 60 seconds")
        }
        
        if batchSize <= 0 {
            throw CalendarSyncError.invalidConfiguration("batchSize must be > 0")
        }
        
        // Validate database path if provided
        if let path = databasePath {
            let directory = URL(fileURLWithPath: path).deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                throw CalendarSyncError.invalidConfiguration("Database directory does not exist: \(directory.path)")
            }
        }
    }
}

// MARK: - CalendarSyncError
public enum CalendarSyncError: Error, LocalizedError {
    case permissionDenied
    case databaseError(String)
    case invalidConfiguration(String)
    case syncInProgress
    case calendarNotFound(String)
    case networkError(Error)
    case unknownError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Calendar access permission denied"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .syncInProgress:
            return "Sync operation already in progress"
        case .calendarNotFound(let identifier):
            return "Calendar not found: \(identifier)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

extension CalendarSyncConfiguration: CustomStringConvertible {
    public var description: String {
        return """
        CalendarSyncConfiguration:
        - Notification Sync: \(enableNotificationSync)
        - Background Sync: \(enableBackgroundSync)
        - Calendar IDs: \(calendarIdentifiers?.joined(separator: ", ") ?? "All")
        - Database Path: \(effectiveDatabasePath)
        - Auto Start: \(autoStart)
        - Max Retry Attempts: \(maxRetryAttempts)
        - Sync Interval: \(syncInterval)s
        - Logging: \(enableLogging)
        - Batch Size: \(batchSize)
        """
    }
} 