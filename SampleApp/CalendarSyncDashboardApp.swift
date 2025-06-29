import SwiftUI
import CalendarSync

@main
struct CalendarSyncDashboardApp: App {
    @StateObject private var calendarSyncManager = CalendarSyncManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(calendarSyncManager)
                .onAppear {
                    calendarSyncManager.initialize()
                }
        }
    }
}

// MARK: - CalendarSync Manager
@MainActor
class CalendarSyncManager: ObservableObject {
    @Published var calendarSync: CalendarSync?
    @Published var syncStatus: SyncStatus = .idle
    @Published var isInitialized = false
    @Published var initializationError: String?
    @Published var events: [CalendarEvent] = []
    @Published var syncStatistics = SyncStatistics()
    
    func initialize() {
        guard !isInitialized else { return }
        
        do {
            let config = CalendarSyncConfiguration(
                enableNotificationSync: true,
                enableBackgroundSync: true,
                autoStart: true,
                enableLogging: true
            )
            
            calendarSync = try CalendarSync(configuration: config)
            setupCallbacks()
            isInitialized = true
            loadEvents()
        } catch {
            initializationError = error.localizedDescription
            print("Failed to initialize CalendarSync: \(error)")
        }
    }
    
    private func setupCallbacks() {
        calendarSync?.onSyncStatusChanged = { [weak self] status in
            Task { @MainActor in
                self?.syncStatus = status
                self?.syncStatistics = self?.calendarSync?.syncStatistics ?? SyncStatistics()
                
                if case .synced = status {
                    self?.loadEvents()
                }
            }
        }
    }
    
    func loadEvents() {
        guard let calendarSync = calendarSync else { return }
        
        Task {
            do {
                let allEvents = try calendarSync.getAllEvents()
                await MainActor.run {
                    self.events = allEvents
                }
            } catch {
                print("Failed to load events: \(error)")
            }
        }
    }
    
    func forceSync() {
        calendarSync?.forceSync()
    }
    
    func getTodaysEvents() -> [CalendarEvent] {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return events.filter { event in
            event.startDate >= startOfDay && event.startDate < endOfDay
        }.sorted { $0.startDate < $1.startDate }
    }
    
    func getUpcomingEvents(limit: Int = 3) -> [CalendarEvent] {
        let now = Date()
        return events.filter { event in
            event.startDate > now
        }.sorted { $0.startDate < $1.startDate }
        .prefix(limit)
        .map { $0 }
    }
} 