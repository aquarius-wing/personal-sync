import SwiftUI
import CalendarSync

@main
struct CalendarSyncDashboardApp: App {
    @StateObject private var calendarSyncManager = CalendarSyncManager()
    @StateObject private var reminderSyncManager = ReminderSyncManager()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(calendarSyncManager)
                .environmentObject(reminderSyncManager)
                .onAppear {
                    calendarSyncManager.initialize()
                    reminderSyncManager.initialize()
                }
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    var body: some View {
        TabView {
            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
            
            RemindersView()
                .tabItem {
                    Image(systemName: "checklist")
                    Text("Reminders")
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

// MARK: - ReminderSync Manager
@MainActor
class ReminderSyncManager: ObservableObject {
    @Published var reminderSync: ReminderSync?
    @Published var syncStatus: ReminderSyncStatus = .idle
    @Published var isInitialized = false
    @Published var initializationError: String?
    @Published var reminders: [ReminderEvent] = []
    @Published var syncStatistics = ReminderSyncStatistics()
    
    func initialize() {
        guard !isInitialized else { return }
        
        do {
            let config = CalendarSyncConfiguration(
                enableNotificationSync: true,
                enableBackgroundSync: true,
                autoStart: true,
                enableLogging: true
            )
            
            reminderSync = try ReminderSync(configuration: config)
            setupCallbacks()
            isInitialized = true
            loadReminders()
        } catch {
            initializationError = error.localizedDescription
            print("Failed to initialize ReminderSync: \(error)")
        }
    }
    
    private func setupCallbacks() {
        reminderSync?.onSyncStatusChanged = { [weak self] status in
            Task { @MainActor in
                self?.syncStatus = status
                self?.syncStatistics = self?.reminderSync?.syncStatistics ?? ReminderSyncStatistics()
                
                if case .synced = status {
                    self?.loadReminders()
                }
            }
        }
    }
    
    func loadReminders() {
        guard let reminderSync = reminderSync else { return }
        
        Task {
            do {
                let allReminders = try reminderSync.getAllReminders()
                await MainActor.run {
                    self.reminders = allReminders
                }
            } catch {
                print("Failed to load reminders: \(error)")
            }
        }
    }
    
    func forceSync() {
        reminderSync?.forceSync()
    }
    
    func getTodaysReminders() -> [ReminderEvent] {
        guard let reminderSync = reminderSync else { return [] }
        
        do {
            return try reminderSync.getTodayReminders()
        } catch {
            print("Failed to get today's reminders: \(error)")
            return []
        }
    }
    
    func getOverdueReminders() -> [ReminderEvent] {
        guard let reminderSync = reminderSync else { return [] }
        
        do {
            return try reminderSync.getOverdueReminders()
        } catch {
            print("Failed to get overdue reminders: \(error)")
            return []
        }
    }
    
    func getUpcomingReminders(limit: Int = 5) -> [ReminderEvent] {
        guard let reminderSync = reminderSync else { return [] }
        
        do {
            return try reminderSync.getUpcomingReminders(limit: limit)
        } catch {
            print("Failed to get upcoming reminders: \(error)")
            return []
        }
    }
    
    func getHighPriorityReminders() -> [ReminderEvent] {
        guard let reminderSync = reminderSync else { return [] }
        
        do {
            return try reminderSync.getHighPriorityReminders()
        } catch {
            print("Failed to get high priority reminders: \(error)")
            return []
        }
    }
} 