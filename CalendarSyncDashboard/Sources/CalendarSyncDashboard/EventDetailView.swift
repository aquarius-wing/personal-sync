import SwiftUI
import PersonalSync

struct EventDetailView: View {
    let event: CalendarEvent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Event Header
                    eventHeader
                    
                    // Event Details
                    eventDetails
                    
                    // Additional Information
                    additionalInfo
                    
                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .background(.regularMaterial)
            .navigationTitle("Event Details")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var eventHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and calendar
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title ?? "Untitled Event")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text(event.calendarTitle ?? "Unknown Calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if event.hasRecurrenceRules {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                                .font(.caption)
                            Text("Recurring")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.1), in: Capsule())
                    }
                }
            }
            
            Divider()
        }
    }
    
    private var eventDetails: some View {
        VStack(spacing: 20) {
            // Date and Time
            DetailSection(
                icon: "clock",
                title: "Date & Time",
                iconColor: .blue
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    if event.isAllDay {
                        HStack {
                            Text("All Day Event")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("ALL DAY")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.1), in: Capsule())
                        }
                        
                        HStack {
                            Text(event.startDate, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if !Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate) {
                                Text("to")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(event.endDate, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Starts:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(event.startDate, style: .date)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(event.startDate, style: .time)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Ends:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(event.endDate, style: .date)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(event.endDate, style: .time)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            // Duration
                            HStack {
                                Text("Duration:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(formatDuration())
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            }
            
            // Location
            if let location = event.location {
                DetailSection(
                    icon: "location",
                    title: "Location",
                    iconColor: .red
                ) {
                    Text(location)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                }
            }
            
            // Notes
            if let notes = event.notes, !notes.isEmpty {
                DetailSection(
                    icon: "note.text",
                    title: "Notes",
                    iconColor: .green
                ) {
                    Text(notes)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                }
            }
            
            // URL
            if let url = event.url {
                DetailSection(
                    icon: "link",
                    title: "URL",
                    iconColor: .purple
                ) {
                    Link(destination: url) {
                        Text(url.absoluteString)
                            .font(.body)
                            .foregroundColor(.blue)
                            .underline()
                    }
                }
            }
        }
    }
    
    private var additionalInfo: some View {
        VStack(spacing: 16) {
            Text("Additional Information")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                InfoRow(label: "Event ID", value: event.eventIdentifier)
                InfoRow(label: "Status", value: formatEventStatus())
                
                if let creationDate = event.creationDate {
                    InfoRow(label: "Created", value: formatDetailDate(creationDate))
                }
                
                if let modifiedDate = event.lastModifiedDate {
                    InfoRow(label: "Last Modified", value: formatDetailDate(modifiedDate))
                }
                
                InfoRow(label: "Synced At", value: formatDetailDate(event.syncedAt))
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration() -> String {
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatEventStatus() -> String {
        switch event.status {
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
    
    private func formatDetailDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct DetailSection<Content: View>: View {
    let icon: String
    let title: String
    let iconColor: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                    .frame(width: 20)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            content
                .padding(.leading, 28)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    let sampleEvent = CalendarEvent(
        eventIdentifier: "sample-event-id",
        title: "Sample Meeting",
        notes: "This is a sample meeting with some notes about the agenda and what to discuss.",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        isAllDay: false,
        calendarIdentifier: "sample-calendar-id",
        calendarTitle: "Work Calendar",
        location: "Conference Room A",
        url: URL(string: "https://example.com/meeting"),
        lastModifiedDate: Date().addingTimeInterval(-86400),
        creationDate: Date().addingTimeInterval(-172800),
        status: .confirmed,
        hasRecurrenceRules: true,
        timeZone: "America/New_York",
        recurrenceRule: nil,
        hasAlarms: false,
        attendeesJson: nil,
        isDetached: false,
        syncedAt: Date()
    )
    
    EventDetailView(event: sampleEvent)
} 