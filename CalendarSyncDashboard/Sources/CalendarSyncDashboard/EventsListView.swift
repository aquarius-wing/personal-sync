import SwiftUI
import CalendarSync
import EventKit

enum TimeFilter: CaseIterable {
    case all, today, week, month, upcoming
    
    var title: String {
        switch self {
        case .all: return "All"
        case .today: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .upcoming: return "Upcoming"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "calendar"
        case .today: return "calendar.badge.clock"
        case .week: return "calendar.badge.plus"
        case .month: return "calendar.circle"
        case .upcoming: return "calendar.badge.plus"
        }
    }
}

enum SortField: CaseIterable {
    case title, startDate, endDate, calendar
    
    var title: String {
        switch self {
        case .title: return "Title"
        case .startDate: return "Start Date"
        case .endDate: return "End Date"
        case .calendar: return "Calendar"
        }
    }
}

enum SortOrder {
    case ascending, descending
    
    var title: String {
        switch self {
        case .ascending: return "Ascending"
        case .descending: return "Descending"
        }
    }
    
    var icon: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }
}

struct EventsListView: View {
    @EnvironmentObject var manager: CalendarSyncManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var selectedEvent: CalendarEvent?
    @State private var selection = Set<CalendarEvent.ID>()
    @State private var sortField: SortField = .startDate
    @State private var sortOrder: SortOrder = .ascending
    @State private var showTechnicalDetails = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar and filter section
                searchAndFilterSection
                
                // Events table
                if filteredAndSortedEvents.isEmpty {
                    emptyStateView
                } else {
                    if showTechnicalDetails {
                        technicalTable
                    } else {
                        standardTable
                    }
                }
            }
            .navigationTitle("Events Database Table")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    HStack {
                        Button(action: {
                            showTechnicalDetails.toggle()
                        }) {
                            Image(systemName: showTechnicalDetails ? "eye.slash" : "eye")
                                .foregroundColor(.blue)
                        }
                        
                        Menu {
                            Button("Export Data") {
                                // Future: Export functionality
                            }
                            
                            Button("Refresh") {
                                manager.forceSync()
                            }
                            .disabled(manager.syncStatus == .syncing)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
        .searchable(text: $searchText, prompt: "Search all fields...")
    }
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TimeFilter.allCases, id: \.self) { filter in
                        FilterPill(
                            title: filter.title,
                            icon: filter.icon,
                            isSelected: selectedTimeFilter == filter,
                            action: {
                                selectedTimeFilter = filter
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            // Sort controls
            HStack {
                Menu {
                    ForEach(SortField.allCases, id: \.self) { field in
                        Button(action: { sortField = field }) {
                            HStack {
                                Text(field.title)
                                if sortField == field {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("Sort: \(sortField.title)")
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                Button(action: {
                    sortOrder = sortOrder == .ascending ? .descending : .ascending
                }) {
                    Image(systemName: sortOrder.icon)
                        .font(.caption)
                        .padding(4)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Stats info and view toggle
            HStack {
                Text("\(filteredAndSortedEvents.count) events")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(showTechnicalDetails ? "Technical View" : "Standard View")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                if !selection.isEmpty {
                    Text("• \(selection.count) selected")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
    
    // Standard user-friendly table with most important columns
    private var standardTable: some View {
        Table(filteredAndSortedEvents, selection: $selection) {
            TableColumn("Title") { event in
                Button(action: { selectedEvent = event }) {
                    HStack {
                        Text(event.title ?? "Untitled")
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if sortField == .title {
                            Image(systemName: sortOrder.icon)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .width(min: 200, max: 300)
            
            TableColumn("Calendar") { event in
                HStack {
                    Text(event.calendarTitle ?? "Unknown")
                        .font(.caption)
                        .lineLimit(1)
                    if sortField == .calendar {
                        Image(systemName: sortOrder.icon)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .width(min: 120, max: 180)
            
            TableColumn("Start") { event in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(event.startDate))
                            .font(.caption)
                        if !event.isAllDay {
                            Text(formatTime(event.startDate))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    if sortField == .startDate {
                        Image(systemName: sortOrder.icon)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .width(min: 80, max: 120)
            
            TableColumn("End") { event in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(event.endDate))
                            .font(.caption)
                        if !event.isAllDay {
                            Text(formatTime(event.endDate))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    if sortField == .endDate {
                        Image(systemName: sortOrder.icon)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .width(min: 80, max: 120)
            
            TableColumn("All Day") { event in
                Image(systemName: event.isAllDay ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(event.isAllDay ? .green : .secondary)
            }
            .width(60)
            
            TableColumn("Status") { event in
                Text(statusText(event.status))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor(event.status).opacity(0.2))
                    .foregroundColor(statusColor(event.status))
                    .clipShape(Capsule())
            }
            .width(min: 80, max: 100)
            
            TableColumn("Location") { event in
                Text(event.location ?? "")
                    .font(.caption)
                    .foregroundColor(event.location != nil ? .primary : .secondary)
                    .lineLimit(2)
            }
            .width(min: 100, max: 200)
        }
        .refreshable {
            manager.loadEvents()
        }
    }
    
    // Technical database view with all SQLite columns
    private var technicalTable: some View {
        Table(filteredAndSortedEvents, selection: $selection) {
            TableColumn("Event ID") { event in
                Text(String(event.eventIdentifier.prefix(12)) + "...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .width(min: 100, max: 140)
            
            TableColumn("Title") { event in
                Button(action: { selectedEvent = event }) {
                    Text(event.title ?? "Untitled")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
            .width(min: 120, max: 180)
            
            TableColumn("Calendar ID") { event in
                Text(String(event.calendarIdentifier.prefix(8)) + "...")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .width(min: 80, max: 120)
            
            TableColumn("Start Date") { event in
                Text(formatDateTime(event.startDate))
                    .font(.caption2)
            }
            .width(min: 120, max: 160)
            
            TableColumn("End Date") { event in
                Text(formatDateTime(event.endDate))
                    .font(.caption2)
            }
            .width(min: 120, max: 160)
            
            TableColumn("All Day") { event in
                Text(event.isAllDay ? "TRUE" : "FALSE")
                    .font(.caption2)
                    .foregroundColor(event.isAllDay ? .green : .secondary)
            }
            .width(60)
            
            TableColumn("Has Rules") { event in
                Text(event.hasRecurrenceRules ? "TRUE" : "FALSE")
                    .font(.caption2)
                    .foregroundColor(event.hasRecurrenceRules ? .blue : .secondary)
            }
            .width(80)
        }
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
                   (event.calendarTitle?.lowercased().contains(searchLower) ?? false) ||
                   event.eventIdentifier.lowercased().contains(searchLower) ||
                   event.calendarIdentifier.lowercased().contains(searchLower) ||
                   statusText(event.status).lowercased().contains(searchLower)
        }
    }
    
    private var filteredAndSortedEvents: [CalendarEvent] {
        let events = filteredEvents
        
        switch sortField {
        case .title:
            return events.sorted { lhs, rhs in
                let lhsTitle = lhs.title ?? ""
                let rhsTitle = rhs.title ?? ""
                return sortOrder == .ascending ? lhsTitle < rhsTitle : lhsTitle > rhsTitle
            }
        case .startDate:
            return events.sorted { lhs, rhs in
                return sortOrder == .ascending ? lhs.startDate < rhs.startDate : lhs.startDate > rhs.startDate
            }
        case .endDate:
            return events.sorted { lhs, rhs in
                return sortOrder == .ascending ? lhs.endDate < rhs.endDate : lhs.endDate > rhs.endDate
            }
        case .calendar:
            return events.sorted { lhs, rhs in
                let lhsCalendar = lhs.calendarTitle ?? ""
                let rhsCalendar = rhs.calendarTitle ?? ""
                return sortOrder == .ascending ? lhsCalendar < rhsCalendar : lhsCalendar > rhsCalendar
            }
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
    
    // MARK: - Formatting Functions
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func statusText(_ status: EKEventStatus) -> String {
        switch status {
        case .none:
            return "None"
        case .confirmed:
            return "Confirmed"
        case .tentative:
            return "Tentative"
        case .canceled:
            return "Canceled"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func statusColor(_ status: EKEventStatus) -> Color {
        switch status {
        case .none:
            return .gray
        case .confirmed:
            return .green
        case .tentative:
            return .orange
        case .canceled:
            return .red
        @unknown default:
            return .gray
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

// MARK: - Extensions

extension CalendarEvent: @retroactive Identifiable {
    public var id: String { eventIdentifier }
}

extension TimeFilter: Hashable {}

#Preview {
    EventsListView()
        .environmentObject(CalendarSyncManager())
} 