#!/usr/bin/env swift

import Foundation
import CalendarSync

print("🚀 CalendarSync Demo Starting...")

class CalendarSyncDemo {
    private var calendarSync: CalendarSync?
    private var isRunning = true
    
    func run() {
        print("📋 Creating CalendarSync with custom configuration...")
        
        // Create custom configuration for demo
        let config = CalendarSyncConfiguration(
            enableNotificationSync: true,
            enableBackgroundSync: false, // Disable for demo
            autoStart: false, // Manual start for demo
            enableLogging: true,
            syncInterval: 600
        )
        
        print(config.description)
        
        // Initialize CalendarSync
        do {
            calendarSync = try CalendarSync(configuration: config)
        } catch {
            print("❌ Failed to initialize CalendarSync: \(error)")
            return
        }
        
        // Set up callbacks
        setupCallbacks()
        
        // Start sync
        print("\n⚡ Starting sync...")
        calendarSync?.startSync()
        
        // Keep demo running for a bit
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.queryData()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.cleanup()
            }
        }
        
        // Keep main thread alive
        while isRunning {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
        }
    }
    
    private func setupCallbacks() {
        calendarSync?.onSyncStatusChanged = { status in
            switch status {
            case .idle:
                print("💤 Sync Status: Idle")
            case .syncing:
                print("🔄 Sync Status: Syncing...")
            case .synced(let count):
                print("✅ Sync Status: Completed with \(count) events")
            case .error(let error):
                print("❌ Sync Status: Error - \(error.localizedDescription)")
            }
        }
        
        calendarSync?.onEventUpdated = { event, updateType in
            let typeEmoji = updateType == .inserted ? "➕" : 
                           updateType == .updated ? "✏️" : "🗑️"
            let typeName = updateType == .inserted ? "New" :
                          updateType == .updated ? "Updated" : "Deleted"
            
            print("\(typeEmoji) \(typeName) Event: \(event.title ?? "Untitled")")
        }
    }
    
    private func queryData() {
        guard let sync = calendarSync else { return }
        
        print("\n📊 Current Status:")
        print("   - Is Active: \(sync.isActive)")
        print("   - Current Status: \(sync.syncStatus)")
        print("   - Last Sync: \(sync.lastSyncTime?.description ?? "Never")")
        
        let stats = sync.syncStatistics
        print("\n📈 Statistics:")
        print("   - Total Events: \(stats.totalEvents)")
        print("   - Last Duration: \(String(format: "%.2f", stats.lastSyncDuration))s")
        print("   - Successful Syncs: \(stats.successfulSyncs)")
        print("   - Failed Syncs: \(stats.failedSyncs)")
        print("   - Success Rate: \(String(format: "%.1f", stats.successRate))%")
        
        do {
            // Query some data
            let allEvents = try sync.getAllEvents()
            print("\n📅 Total Events: \(allEvents.count)")
            
            let todayEvents = try sync.getTodayEvents()
            print("📅 Today's Events: \(todayEvents.count)")
            
            if !todayEvents.isEmpty {
                print("   Today's Schedule:")
                for event in todayEvents.prefix(3) {
                    let timeFormatter = DateFormatter()
                    timeFormatter.timeStyle = .short
                    print("   - \(timeFormatter.string(from: event.startDate)): \(event.title ?? "Untitled")")
                }
            }
            
            let upcomingEvents = try sync.getUpcomingEvents(limit: 3)
            if !upcomingEvents.isEmpty {
                print("\n🔮 Upcoming Events:")
                for event in upcomingEvents {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    print("   - \(dateFormatter.string(from: event.startDate)): \(event.title ?? "Untitled")")
                }
            }
            
        } catch {
            print("❌ Error querying data: \(error)")
        }
    }
    
    private func cleanup() {
        print("\n🧹 Cleaning up...")
        calendarSync?.stopSync()
        calendarSync = nil
        
        print("✅ Demo completed!")
        isRunning = false
    }
}

// Run the demo
let demo = CalendarSyncDemo()
demo.run() 