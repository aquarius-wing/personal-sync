import SwiftUI
import CalendarSync
import UIKit

struct CalendarView: View {
    @EnvironmentObject var manager: CalendarSyncManager
    @State private var showingEventsList = false
    
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
            .navigationTitle("Calendar Sync")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                manager.loadEvents()
            }
        }
        .sheet(isPresented: $showingEventsList) {
            EventsListView()
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
                
                // Recent Events Section
                recentEventsSection
                
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
            
            if let lastSync = manager.calendarSync?.lastSyncTime {
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
                title: "Total Events",
                value: "\(manager.events.count)",
                icon: "calendar",
                color: .blue
            )
            
            StatCard(
                title: "Today's Events",
                value: "\(manager.getTodaysEvents().count)",
                icon: "calendar.badge.clock",
                color: .green
            )
            
            StatCard(
                title: "Success Rate",
                value: String(format: "%.1f%%", manager.syncStatistics.successRate),
                icon: "checkmark.circle",
                color: .orange
            )
            
            StatCard(
                title: "Sync Duration",
                value: String(format: "%.1fs", manager.syncStatistics.lastSyncDuration),
                icon: "timer",
                color: .purple
            )
        }
    }
    
    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Events")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingEventsList = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            let upcomingEvents = manager.getUpcomingEvents()
            
            if upcomingEvents.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.exclamationmark",
                    title: "No Upcoming Events",
                    subtitle: "You're all caught up!"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(upcomingEvents, id: \.eventIdentifier) { event in
                        EventRowView(event: event)
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
            
            Text("Initializing CalendarSync...")
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
            return "Syncing calendar data..."
        case .synced(let count):
            return "Successfully synced \(count) events"
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct EventRowView: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(alignment: .center, spacing: 2) {
                Text(event.startDate, style: .time)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 50)
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Untitled Event")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let location = event.location {
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
                
                Text(event.calendarTitle ?? "Unknown Calendar")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.1), in: Capsule())
            }
            
            Spacer()
            
            // All-day indicator
            if event.isAllDay {
                Text("ALL DAY")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.1), in: Capsule())
            }
        }
        .padding(.vertical, 8)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
    }
}

#Preview {
    CalendarView()
        .environmentObject(CalendarSyncManager())
} 
