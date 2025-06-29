import SwiftUI
import CalendarSync

struct EventsListView: View {
    @EnvironmentObject var manager: CalendarSyncManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var showingEventDetail = false
    @State private var selectedEvent: CalendarEvent?
    
    enum TimeFilter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case upcoming = "Upcoming"
        
        var icon: String {
            switch self {
            case .all: return "calendar"
            case .today: return "calendar.badge.clock"
            case .week: return "calendar.badge.minus"
            case .month: return "calendar.circle"
            case .upcoming: return "calendar.badge.plus"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Section
                VStack(spacing: 16) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search events...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    
                    // Time Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TimeFilter.allCases, id: \.self) { filter in
                                FilterPill(
                                    title: filter.rawValue,
                                    icon: filter.icon,
                                    isSelected: selectedTimeFilter == filter
                                ) {
                                    selectedTimeFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial)
                
                // Events List
                if filteredEvents.isEmpty {
                    emptyStateView
                } else {
                    eventsList
                }
            }
            .navigationTitle("All Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        manager.forceSync()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(manager.syncStatus == .syncing)
                }
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
    }
    
    private var eventsList: some View {
        List {
            ForEach(groupedEvents.keys.sorted(), id: \.self) { date in
                Section {
                    ForEach(groupedEvents[date] ?? [], id: \.eventIdentifier) { event in
                        EventListRowView(event: event) {
                            selectedEvent = event
                            showingEventDetail = true
                        }
                    }
                } header: {
                    Text(formatSectionDate(date))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            manager.loadEvents()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: searchText.isEmpty ? "calendar.badge.exclamationmark" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Events Found" : "No Search Results")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(searchText.isEmpty ? 
                     "There are no events for the selected time period." :
                     "Try adjusting your search terms or filters.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if !searchText.isEmpty {
                Button("Clear Search") {
                    searchText = ""
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Computed Properties
    
    private var filteredEvents: [CalendarEvent] {
        let timeFilteredEvents = filterEventsByTime(manager.events)
        
        if searchText.isEmpty {
            return timeFilteredEvents
        }
        
        return timeFilteredEvents.filter { event in
            let searchLower = searchText.lowercased()
            return (event.title?.lowercased().contains(searchLower) ?? false) ||
                   (event.notes?.lowercased().contains(searchLower) ?? false) ||
                   (event.location?.lowercased().contains(searchLower) ?? false) ||
                   (event.calendarTitle?.lowercased().contains(searchLower) ?? false)
        }
    }
    
    private var groupedEvents: [Date: [CalendarEvent]] {
        let calendar = Calendar.current
        
        return Dictionary(grouping: filteredEvents.sorted { $0.startDate < $1.startDate }) { event in
            calendar.startOfDay(for: event.startDate)
        }
    }
    
    private func filterEventsByTime(_ events: [CalendarEvent]) -> [CalendarEvent] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeFilter {
        case .all:
            return events
            
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return events.filter { event in
                event.startDate >= startOfDay && event.startDate < endOfDay
            }
            
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
            return events.filter { event in
                event.startDate >= startOfWeek && event.startDate <= endOfWeek
            }
            
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
            return events.filter { event in
                event.startDate >= startOfMonth && event.startDate <= endOfMonth
            }
            
        case .upcoming:
            return events.filter { event in
                event.startDate > now
            }
        }
    }
    
    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            return formatter.string(from: date)
        }
    }
}

// MARK: - Supporting Views

struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? .blue : .clear,
                in: Capsule()
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                Capsule()
                    .stroke(.secondary.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct EventListRowView: View {
    let event: CalendarEvent
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Time and status indicator
                VStack(alignment: .leading, spacing: 4) {
                    if event.isAllDay {
                        Text("ALL DAY")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    } else {
                        Text(event.startDate, style: .time)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        if event.startDate != event.endDate {
                            Text(event.endDate, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(width: 60, alignment: .leading)
                
                // Event content
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title ?? "Untitled Event")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
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
                    
                    HStack(spacing: 8) {
                        Text(event.calendarTitle ?? "Unknown Calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.1), in: Capsule())
                        
                        if event.hasRecurrenceRules {
                            HStack(spacing: 2) {
                                Image(systemName: "repeat")
                                    .font(.caption2)
                                Text("Recurring")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extensions

extension CalendarEvent: Identifiable {
    public var id: String { eventIdentifier }
}

#Preview {
    EventsListView()
        .environmentObject(CalendarSyncManager())
} 