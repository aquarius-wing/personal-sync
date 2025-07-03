import SwiftUI
import CalendarSync
import UIKit

struct RemindersView: View {
    @EnvironmentObject var manager: ReminderSyncManager
    @State private var showingRemindersList = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if manager.isInitialized {
                    mainContent
                } else if let error = manager.initializationError {
                    errorView(error)
                } else {
                    loadingView
                }
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                manager.loadReminders()
            }
        }
        .sheet(isPresented: $showingRemindersList) {
            RemindersListView()
                .environmentObject(manager)
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Sync Status Header
                syncStatusCard
                
                // Statistics Cards
                statisticsSection
                
                // Priority Reminders Section
                priorityRemindersSection
                
                // Today's Reminders Section
                todayRemindersSection
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }
    
    private var syncStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: syncStatusIcon)
                    .foregroundColor(syncStatusColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sync Status")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(syncStatusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    manager.forceSync()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .disabled(manager.syncStatus == .syncing)
            }
            
            if let lastSync = manager.reminderSync?.lastSyncTime {
                HStack {
                    Text("Last sync:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(lastSync, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var statisticsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Total Reminders",
                value: "\(manager.syncStatistics.totalReminders)",
                icon: "checklist",
                color: .blue
            )
            
            StatCard(
                title: "Today's Reminders",
                value: "\(manager.syncStatistics.todayReminders)",
                icon: "calendar.badge.clock",
                color: .green
            )
            
            StatCard(
                title: "Overdue",
                value: "\(manager.syncStatistics.overdueReminders)",
                icon: "exclamationmark.triangle",
                color: .red
            )
            
            StatCard(
                title: "Completed",
                value: "\(manager.syncStatistics.completedReminders)",
                icon: "checkmark.circle",
                color: .orange
            )
        }
    }
    
    private var priorityRemindersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("High Priority")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingRemindersList = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            let highPriorityReminders = manager.getHighPriorityReminders()
            
            if highPriorityReminders.isEmpty {
                EmptyStateView(
                    icon: "star",
                    title: "No High Priority Reminders",
                    subtitle: "You're all caught up with priorities!"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(highPriorityReminders, id: \.reminderIdentifier) { reminder in
                        ReminderRowView(reminder: reminder)
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var todayRemindersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Reminders")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            let todayReminders = manager.getTodaysReminders()
            
            if todayReminders.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.checkmark",
                    title: "No Reminders for Today",
                    subtitle: "Enjoy your free day!"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(todayReminders, id: \.reminderIdentifier) { reminder in
                        ReminderRowView(reminder: reminder)
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Initializing ReminderSync...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Initialization Failed")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                manager.initialize()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Computed Properties
    
    private var syncStatusIcon: String {
        switch manager.syncStatus {
        case .idle:
            return "pause.circle"
        case .syncing:
            return "arrow.clockwise"
        case .synced:
            return "checkmark.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }
    
    private var syncStatusColor: Color {
        switch manager.syncStatus {
        case .idle:
            return .gray
        case .syncing:
            return .blue
        case .synced:
            return .green
        case .error:
            return .red
        }
    }
    
    private var syncStatusText: String {
        switch manager.syncStatus {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing reminder data..."
        case .synced:
            return "Successfully synced reminders"
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Views

struct ReminderRowView: View {
    let reminder: ReminderEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            VStack(alignment: .center, spacing: 2) {
                Image(systemName: priorityIcon)
                    .font(.title3)
                    .foregroundColor(priorityColor)
                
                if let dueDate = reminder.dueDate {
                    Text(dueDate, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 50)
            
            // Reminder details
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title ?? "Untitled Reminder")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .strikethrough(reminder.isCompleted)
                    .foregroundColor(reminder.isCompleted ? .secondary : .primary)
                
                if let notes = reminder.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let location = reminder.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Text(reminder.listTitle ?? "Unknown List")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.1), in: Capsule())
            }
            
            Spacer()
            
            // Status indicators
            VStack(spacing: 4) {
                if reminder.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                
                if reminder.hasAlarms {
                    Image(systemName: "bell")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if reminder.hasRecurrenceRules {
                    Image(systemName: "repeat")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                if isOverdue {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var priorityIcon: String {
        switch reminder.priority {
        case 1:
            return "exclamationmark.3"
        case 2...4:
            return "exclamationmark.2"
        case 5...8:
            return "exclamationmark"
        default:
            return "circle"
        }
    }
    
    private var priorityColor: Color {
        switch reminder.priority {
        case 1:
            return .red
        case 2...4:
            return .orange
        case 5...8:
            return .yellow
        default:
            return .gray
        }
    }
    
    private var isOverdue: Bool {
        guard let dueDate = reminder.dueDate, !reminder.isCompleted else { return false }
        return dueDate < Date()
    }
}

struct RemindersListView: View {
    @EnvironmentObject var manager: ReminderSyncManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(manager.reminders, id: \.reminderIdentifier) { reminder in
                    ReminderRowView(reminder: reminder)
                }
            }
            .navigationTitle("All Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RemindersView()
        .environmentObject(ReminderSyncManager())
}

// MARK: - Extensions

extension ReminderEvent: @retroactive Identifiable {
    public var id: String { reminderIdentifier }
} 