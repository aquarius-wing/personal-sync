import Foundation
import GRDB
import EventKit

/// Calendar event model that represents a synchronized calendar event
public struct CalendarEvent {
    /// Unique identifier from system calendar
    public let eventIdentifier: String
    
    /// Event title
    public let title: String?
    
    /// Event notes/description
    public let notes: String?
    
    /// Event start date
    public let startDate: Date
    
    /// Event end date
    public let endDate: Date
    
    /// Is this an all-day event
    public let isAllDay: Bool
    
    /// Calendar identifier this event belongs to
    public let calendarIdentifier: String
    
    /// Calendar title
    public let calendarTitle: String?
    
    /// Event location
    public let location: String?
    
    /// Event URL
    public let url: URL?
    
    /// Last modified date
    public let lastModifiedDate: Date?
    
    /// Creation date
    public let creationDate: Date?
    
    /// Event status (confirmed, tentative, cancelled)
    public let status: EKEventStatus
    
    /// Is event recurring
    public let hasRecurrenceRules: Bool
    
    /// Time zone
    public let timeZone: String?
    
    /// Recurrence rule in JSON format
    public let recurrenceRule: String?
    
    /// Whether the event has alarms
    public let hasAlarms: Bool
    
    /// Attendees in JSON format
    public let attendeesJson: String?
    
    /// Whether this is a detached occurrence of a recurring event
    public let isDetached: Bool
    
    /// Sync timestamp
    public var syncedAt: Date
    
    public init(
        eventIdentifier: String,
        title: String?,
        notes: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarIdentifier: String,
        calendarTitle: String?,
        location: String?,
        url: URL?,
        lastModifiedDate: Date?,
        creationDate: Date?,
        status: EKEventStatus,
        hasRecurrenceRules: Bool,
        timeZone: String?,
        recurrenceRule: String?,
        hasAlarms: Bool,
        attendeesJson: String?,
        isDetached: Bool,
        syncedAt: Date = Date()
    ) {
        self.eventIdentifier = eventIdentifier
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarIdentifier = calendarIdentifier
        self.calendarTitle = calendarTitle
        self.location = location
        self.url = url
        self.lastModifiedDate = lastModifiedDate
        self.creationDate = creationDate
        self.status = status
        self.hasRecurrenceRules = hasRecurrenceRules
        self.timeZone = timeZone
        self.recurrenceRule = recurrenceRule
        self.hasAlarms = hasAlarms
        self.attendeesJson = attendeesJson
        self.isDetached = isDetached
        self.syncedAt = syncedAt
    }
    
    /// Initialize from EKEvent
    public init(from ekEvent: EKEvent, syncedAt: Date = Date()) {
        // Helper function to normalize date precision to seconds
        func normalizeDate(_ date: Date) -> Date {
            return Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded())
        }
        
        // Helper function to normalize optional date
        func normalizeOptionalDate(_ date: Date?) -> Date? {
            guard let date = date else { return nil }
            return normalizeDate(date)
        }
        
        // Helper function to convert recurrence rules to JSON
        func recurrenceRulesToJson(_ rules: [EKRecurrenceRule]?) -> String? {
            guard let rules = rules, !rules.isEmpty else { return nil }
            let ruleStrings = rules.map { rule in
                return [
                    "frequency": rule.frequency.rawValue,
                    "interval": rule.interval,
                    "endDate": rule.recurrenceEnd?.endDate?.timeIntervalSince1970
                ].compactMapValues { $0 }
            }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: ruleStrings),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return nil
            }
            return jsonString
        }
        
        // Helper function to convert attendees to JSON
        func attendeesToJson(_ attendees: [EKParticipant]?) -> String? {
            guard let attendees = attendees, !attendees.isEmpty else { return nil }
            let attendeeData = attendees.map { attendee in
                return [
                    "name": attendee.name,
                    "url": attendee.url.absoluteString,
                    "participantRole": attendee.participantRole.rawValue,
                    "participantStatus": attendee.participantStatus.rawValue,
                    "participantType": attendee.participantType.rawValue
                ].compactMapValues { $0 }
            }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: attendeeData),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return nil
            }
            return jsonString
        }
        
        self.init(
            eventIdentifier: ekEvent.eventIdentifier,
            title: ekEvent.title,
            notes: ekEvent.notes,
            startDate: normalizeDate(ekEvent.startDate),
            endDate: normalizeDate(ekEvent.endDate),
            isAllDay: ekEvent.isAllDay,
            calendarIdentifier: ekEvent.calendar.calendarIdentifier,
            calendarTitle: ekEvent.calendar.title,
            location: ekEvent.location,
            url: ekEvent.url,
            lastModifiedDate: normalizeOptionalDate(ekEvent.lastModifiedDate),
            creationDate: normalizeOptionalDate(ekEvent.creationDate),
            status: ekEvent.status,
            hasRecurrenceRules: ekEvent.hasRecurrenceRules,
            timeZone: ekEvent.timeZone?.identifier,
            recurrenceRule: recurrenceRulesToJson(ekEvent.recurrenceRules),
            hasAlarms: ekEvent.hasAlarms,
            attendeesJson: attendeesToJson(ekEvent.attendees),
            isDetached: ekEvent.isDetached,
            syncedAt: normalizeDate(syncedAt)
        )
    }
}

// MARK: - GRDB Conformance
extension CalendarEvent: FetchableRecord, MutablePersistableRecord {
    /// Database table name
    public static let databaseTableName = "calendar_events"
    
    /// Database column names
    public enum Columns {
        static let eventIdentifier = Column("eventIdentifier")
        static let title = Column("title")
        static let notes = Column("notes")
        static let startDate = Column("startDate")
        static let endDate = Column("endDate")
        static let isAllDay = Column("isAllDay")
        static let calendarIdentifier = Column("calendarIdentifier")
        static let calendarTitle = Column("calendarTitle")
        static let location = Column("location")
        static let url = Column("url")
        static let lastModifiedDate = Column("lastModifiedDate")
        static let creationDate = Column("creationDate")
        static let status = Column("status")
        static let hasRecurrenceRules = Column("hasRecurrenceRules")
        static let timeZone = Column("timeZone")
        static let recurrenceRule = Column("recurrenceRule")
        static let hasAlarms = Column("hasAlarms")
        static let attendeesJson = Column("attendeesJson")
        static let isDetached = Column("isDetached")
        static let syncedAt = Column("syncedAt")
    }
    
    /// Primary key
    public mutating func didInsert(with rowID: Int64, for column: String?) {
        // Event identifier is our natural primary key
    }
}

// MARK: - Manual Codable Implementation
extension CalendarEvent: Codable {
    enum CodingKeys: String, CodingKey {
        case eventIdentifier
        case title
        case notes
        case startDate
        case endDate
        case isAllDay
        case calendarIdentifier
        case calendarTitle
        case location
        case url
        case lastModifiedDate
        case creationDate
        case status
        case hasRecurrenceRules
        case timeZone
        case recurrenceRule
        case hasAlarms
        case attendeesJson
        case isDetached
        case syncedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        eventIdentifier = try container.decode(String.self, forKey: .eventIdentifier)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        isAllDay = try container.decode(Bool.self, forKey: .isAllDay)
        calendarIdentifier = try container.decode(String.self, forKey: .calendarIdentifier)
        calendarTitle = try container.decodeIfPresent(String.self, forKey: .calendarTitle)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        lastModifiedDate = try container.decodeIfPresent(Date.self, forKey: .lastModifiedDate)
        creationDate = try container.decodeIfPresent(Date.self, forKey: .creationDate)
        
        // Decode EKEventStatus as Int
        let statusRawValue = try container.decode(Int.self, forKey: .status)
        status = EKEventStatus(rawValue: statusRawValue) ?? .none
        
        hasRecurrenceRules = try container.decode(Bool.self, forKey: .hasRecurrenceRules)
        timeZone = try container.decodeIfPresent(String.self, forKey: .timeZone)
        recurrenceRule = try container.decodeIfPresent(String.self, forKey: .recurrenceRule)
        hasAlarms = try container.decode(Bool.self, forKey: .hasAlarms)
        attendeesJson = try container.decodeIfPresent(String.self, forKey: .attendeesJson)
        isDetached = try container.decode(Bool.self, forKey: .isDetached)
        syncedAt = try container.decode(Date.self, forKey: .syncedAt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(eventIdentifier, forKey: .eventIdentifier)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(isAllDay, forKey: .isAllDay)
        try container.encode(calendarIdentifier, forKey: .calendarIdentifier)
        try container.encodeIfPresent(calendarTitle, forKey: .calendarTitle)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(lastModifiedDate, forKey: .lastModifiedDate)
        try container.encodeIfPresent(creationDate, forKey: .creationDate)
        
        // Encode EKEventStatus as Int
        try container.encode(status.rawValue, forKey: .status)
        
        try container.encode(hasRecurrenceRules, forKey: .hasRecurrenceRules)
        try container.encodeIfPresent(timeZone, forKey: .timeZone)
        try container.encodeIfPresent(recurrenceRule, forKey: .recurrenceRule)
        try container.encode(hasAlarms, forKey: .hasAlarms)
        try container.encodeIfPresent(attendeesJson, forKey: .attendeesJson)
        try container.encode(isDetached, forKey: .isDetached)
        try container.encode(syncedAt, forKey: .syncedAt)
    }
}

// MARK: - Database Schema
extension CalendarEvent {
    /// Create database table
    public static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.column(Columns.eventIdentifier.name, .text).primaryKey()
            t.column(Columns.title.name, .text)
            t.column(Columns.notes.name, .text)
            t.column(Columns.startDate.name, .datetime).notNull().indexed()
            t.column(Columns.endDate.name, .datetime).notNull().indexed()
            t.column(Columns.isAllDay.name, .boolean).notNull()
            t.column(Columns.calendarIdentifier.name, .text).notNull().indexed()
            t.column(Columns.calendarTitle.name, .text)
            t.column(Columns.location.name, .text)
            t.column(Columns.url.name, .text)
            t.column(Columns.lastModifiedDate.name, .datetime)
            t.column(Columns.creationDate.name, .datetime)
            t.column(Columns.status.name, .integer).notNull()
            t.column(Columns.hasRecurrenceRules.name, .boolean).notNull()
            t.column(Columns.timeZone.name, .text)
            t.column(Columns.recurrenceRule.name, .text)
            t.column(Columns.hasAlarms.name, .boolean).notNull()
            t.column(Columns.attendeesJson.name, .text)
            t.column(Columns.isDetached.name, .boolean).notNull()
            t.column(Columns.syncedAt.name, .datetime).notNull().indexed()
        }
    }
}

// MARK: - Query Extensions
extension CalendarEvent {
    /// Get events within date range
    public static func eventsInRange(from startDate: Date, to endDate: Date) -> QueryInterfaceRequest<CalendarEvent> {
        return CalendarEvent
            .filter(Columns.startDate >= startDate && Columns.endDate <= endDate)
            .order(Columns.startDate)
    }
    
    /// Get today's events
    public static func todaysEvents() -> QueryInterfaceRequest<CalendarEvent> {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return eventsInRange(from: startOfDay, to: endOfDay)
    }
    
    /// Get upcoming events
    public static func upcomingEvents(limit: Int = 10) -> QueryInterfaceRequest<CalendarEvent> {
        return CalendarEvent
            .filter(Columns.startDate >= Date())
            .order(Columns.startDate)
            .limit(limit)
    }
    
    /// Search events by keyword
    public static func searchEvents(keyword: String, from: Date? = nil, to: Date? = nil, calendarIdentifierList: [String]? = nil) -> QueryInterfaceRequest<CalendarEvent> {
        let pattern = "%\(keyword)%"
        var query = CalendarEvent
            .filter(Columns.title.like(pattern) || Columns.notes.like(pattern) || Columns.location.like(pattern))
        
        // Add date range filter if provided
        if let fromDate = from {
            query = query.filter(Columns.startDate >= fromDate)
        }
        
        if let toDate = to {
            query = query.filter(Columns.endDate <= toDate)
        }
        
        // Add calendar identifier filter if provided
        if let calendarIds = calendarIdentifierList, !calendarIds.isEmpty {
            query = query.filter(calendarIds.contains(Columns.calendarIdentifier))
        }
        
        return query.order(Columns.startDate.desc)
    }
    
    /// Get events by calendar
    public static func eventsByCalendar(_ calendarIdentifier: String) -> QueryInterfaceRequest<CalendarEvent> {
        return CalendarEvent
            .filter(Columns.calendarIdentifier == calendarIdentifier)
            .order(Columns.startDate)
    }
} 