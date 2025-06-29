import Foundation
import CalendarSync

// MARK: - Basic Usage Example

class CalendarSyncExample {
    private var calendarSync: CalendarSync?
    
    func basicUsageExample() {
        print("=== CalendarSync Basic Usage Example ===")
        
        // 1. Create with default configuration - auto starts syncing
        do {
            calendarSync = try CalendarSync()
        } catch {
            print("❌ Failed to initialize CalendarSync: \(error)")
            return
        }
        
        // 2. Set up sync status monitoring
        calendarSync?.onSyncStatusChanged = { status in
            switch status {
            case .idle:
                print("📱 Sync is idle")
            case .syncing:
                print("🔄 Syncing calendar data...")
            case .synced(let count):
                print("✅ Successfully synced \(count) events")
            case .error(let error):
                print("❌ Sync error: \(error.localizedDescription)")
            }
        }
        
        // 3. Set up event update monitoring
        calendarSync?.onEventUpdated = { event, updateType in
            switch updateType {
            case .inserted:
                print("➕ New event: \(event.title ?? "Untitled")")
            case .updated:
                print("✏️ Updated event: \(event.title ?? "Untitled")")
            case .deleted:
                print("🗑️ Deleted event")
            }
        }
    }
    
    func customConfigurationExample() {
        print("\n=== Custom Configuration Example ===")
        
        // Create custom configuration
        let config = CalendarSyncConfiguration(
            enableNotificationSync: true,        // Enable real-time sync
            enableBackgroundSync: true,          // Enable periodic sync
            calendarIdentifiers: nil,            // Sync all calendars
            autoStart: true,                     // Auto start on init
            maxRetryAttempts: 5,                // More retry attempts
            syncInterval: 600,                   // Sync every 10 minutes
            enableLogging: true,                 // Enable verbose logging
            batchSize: 50                        // Process 50 events at a time
        )
        
        do {
            calendarSync = try CalendarSync(configuration: config)
        } catch {
            print("❌ Failed to initialize CalendarSync: \(error)")
            return
        }
        
        print("📋 Configuration:")
        print(config.description)
    }
    
    func queryingDataExample() {
        print("\n=== Querying Data Example ===")
        
        guard let sync = calendarSync else {
            print("❌ CalendarSync not initialized")
            return
        }
        
        do {
            // Get all events
            let allEvents = try sync.getAllEvents()
            print("📅 Total events: \(allEvents.count)")
            
            // Get today's events
            let todayEvents = try sync.getTodayEvents()
            print("📅 Today's events: \(todayEvents.count)")
            
            // Get upcoming events
            let upcomingEvents = try sync.getUpcomingEvents(limit: 5)
            print("📅 Next 5 events:")
            for event in upcomingEvents {
                print("  - \(event.title ?? "Untitled") at \(formatDate(event.startDate))")
            }
            
            // Search events
            let meetingEvents = try sync.searchEvents(keyword: "meeting")
            print("📅 Events containing 'meeting': \(meetingEvents.count)")
            
            // Get events in date range
            let calendar = Calendar.current
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.end ?? Date()
            
            let weekEvents = try sync.getEvents(from: startOfWeek, to: endOfWeek)
            print("📅 This week's events: \(weekEvents.count)")
            
        } catch {
            print("❌ Error querying events: \(error)")
        }
    }
    
    func syncControlExample() {
        print("\n=== Sync Control Example ===")
        
        guard let sync = calendarSync else {
            print("❌ CalendarSync not initialized")
            return
        }
        
        // Check sync status
        print("🔍 Is active: \(sync.isActive)")
        print("🔍 Current status: \(sync.syncStatus)")
        print("🔍 Last sync time: \(sync.lastSyncTime?.description ?? "Never")")
        
        // Get statistics
        let stats = sync.syncStatistics
        print("📊 Sync Statistics:")
        print(stats.description)
        
        // Manual sync control
        print("\n🎮 Manual Control:")
        
        // Force immediate sync
        sync.forceSync()
        print("⚡ Forced immediate sync")
        
        // Pause and resume
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            sync.pause()
            print("⏸️ Paused sync")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                sync.resume()
                print("▶️ Resumed sync")
            }
        }
    }
    
    func lifecycleExample() {
        print("\n=== Lifecycle Management Example ===")
        
        // Proper cleanup
        calendarSync?.stopSync()
        calendarSync = nil
        print("🧹 Cleaned up CalendarSync")
    }
    
    // Helper function
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - App Integration Example

class AppDelegate {
    var calendarSync: CalendarSync?
    
    func applicationDidFinishLaunching() {
        // Initialize CalendarSync when app starts
        do {
            calendarSync = try CalendarSync()
        } catch {
            print("❌ Failed to initialize CalendarSync: \(error)")
            return
        }
        
        // Set up monitoring
        calendarSync?.onSyncStatusChanged = { [weak self] status in
            self?.handleSyncStatusChange(status)
        }
        
        print("🚀 App launched with CalendarSync")
    }
    
    func applicationDidEnterBackground() {
        // CalendarSync continues running in background automatically
        // if enableBackgroundSync is true
        print("📱 App entered background, sync continues")
    }
    
    func applicationWillTerminate() {
        // Clean up
        calendarSync?.stopSync()
        calendarSync = nil
        print("🛑 App terminating, cleaned up CalendarSync")
    }
    
    private func handleSyncStatusChange(_ status: SyncStatus) {
        // Handle status changes - update UI, send notifications, etc.
        switch status {
        case .synced(let count):
            // Could show a notification or update UI
            print("🔔 Sync completed with \(count) events")
        case .error(let error):
            // Handle error - show alert, log error, etc.
            print("⚠️ Sync error occurred: \(error)")
        default:
            break
        }
    }
}

// MARK: - Usage in SwiftUI

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, macOS 10.15, *)
struct CalendarSyncView: View {
    @StateObject private var viewModel = CalendarSyncViewModel()
    
    var body: some View {
        VStack {
            Text("Calendar Sync Status")
                .font(.title)
            
            Text(viewModel.statusText)
                .foregroundColor(viewModel.statusColor)
            
            Text("Total Events: \(viewModel.totalEvents)")
            
            Button("Force Sync") {
                viewModel.forceSync()
            }
            .disabled(!viewModel.isActive)
        }
        .onAppear {
            viewModel.startSync()
        }
        .onDisappear {
            viewModel.stopSync()
        }
    }
}

@available(iOS 13.0, macOS 10.15, *)
class CalendarSyncViewModel: ObservableObject {
    @Published var statusText: String = "Idle"
    @Published var statusColor: Color = .gray
    @Published var totalEvents: Int = 0
    @Published var isActive: Bool = false
    
    private var calendarSync: CalendarSync?
    
    func startSync() {
        do {
            calendarSync = try CalendarSync()
        } catch {
            statusText = "Initialization Error"
            statusColor = .red
            return
        }
        
        calendarSync?.onSyncStatusChanged = { [weak self] status in
            DispatchQueue.main.async {
                self?.updateStatus(status)
            }
        }
        
        isActive = calendarSync?.isActive ?? false
    }
    
    func stopSync() {
        calendarSync?.stopSync()
        calendarSync = nil
        isActive = false
    }
    
    func forceSync() {
        calendarSync?.forceSync()
    }
    
    private func updateStatus(_ status: SyncStatus) {
        switch status {
        case .idle:
            statusText = "Idle"
            statusColor = .gray
        case .syncing:
            statusText = "Syncing..."
            statusColor = .blue
        case .synced(let count):
            statusText = "Synced"
            statusColor = .green
            totalEvents = count
        case .error(let error):
            statusText = "Error: \(error.localizedDescription)"
            statusColor = .red
        }
    }
}
#endif

// MARK: - Run Example

func runCalendarSyncExample() {
    let example = CalendarSyncExample()
    
    // Run all examples
    example.basicUsageExample()
    example.customConfigurationExample()
    
    // Wait a bit for initial sync
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        example.queryingDataExample()
        example.syncControlExample()
        
        // Clean up after demonstration
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            example.lifecycleExample()
        }
    }
} 