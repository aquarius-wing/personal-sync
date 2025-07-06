import Foundation

/// Synchronization status enumeration
public enum SyncStatus {
    case idle           // Idle state
    case syncing        // Currently syncing
    case synced(Int)    // Sync completed with event count
    case error(Error)   // Sync error occurred
}

extension SyncStatus: Equatable {
    public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.syncing, .syncing):
            return true
        case (.synced(let lhsCount), .synced(let rhsCount)):
            return lhsCount == rhsCount
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

extension SyncStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .syncing:
            return "Syncing"
        case .synced(let count):
            return "Synced (\(count) events)"
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
} 