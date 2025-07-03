import Foundation

/// Synchronization statistics structure
public struct SyncStatistics {
    /// Total number of events in database
    public let totalEvents: Int
    
    /// Total number of calendars in database
    public let totalCalendars: Int
    
    /// Duration of last sync operation in seconds
    public let lastSyncDuration: TimeInterval
    
    /// Number of successful sync operations
    public let successfulSyncs: Int
    
    /// Number of failed sync operations
    public let failedSyncs: Int
    
    /// Average sync duration
    public var averageSyncDuration: TimeInterval {
        guard successfulSyncs > 0 else { return 0 }
        return lastSyncDuration // This could be enhanced to track all durations
    }
    
    /// Success rate as percentage
    public var successRate: Double {
        let totalAttempts = successfulSyncs + failedSyncs
        guard totalAttempts > 0 else { return 0 }
        return Double(successfulSyncs) / Double(totalAttempts) * 100
    }
    
    public init(
        totalEvents: Int = 0,
        totalCalendars: Int = 0,
        lastSyncDuration: TimeInterval = 0,
        successfulSyncs: Int = 0,
        failedSyncs: Int = 0
    ) {
        self.totalEvents = totalEvents
        self.totalCalendars = totalCalendars
        self.lastSyncDuration = lastSyncDuration
        self.successfulSyncs = successfulSyncs
        self.failedSyncs = failedSyncs
    }
}

extension SyncStatistics: CustomStringConvertible {
    public var description: String {
        return """
        SyncStatistics:
        - Total Events: \(totalEvents)
        - Total Calendars: \(totalCalendars)
        - Last Sync Duration: \(String(format: "%.2f", lastSyncDuration))s
        - Successful Syncs: \(successfulSyncs)
        - Failed Syncs: \(failedSyncs)
        - Success Rate: \(String(format: "%.1f", successRate))%
        """
    }
} 