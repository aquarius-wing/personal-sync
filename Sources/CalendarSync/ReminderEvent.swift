import Foundation
import GRDB
import EventKit

/// Reminder event model that represents a synchronized reminder
public struct ReminderEvent {
    /// Unique identifier from system reminders
    public let reminderIdentifier: String
    
    /// Reminder title
    public let title: String?
    
    /// Reminder notes/description
    public let notes: String?
    
    /// Due date (optional)
    public let dueDate: Date?
    
    /// Completion date (if completed)
    public let completionDate: Date?
    
    /// Is this reminder completed
    public let isCompleted: Bool
    
    /// Priority level (0-9, where 0 = no priority, 1 = high, 5 = medium, 9 = low)
    public let priority: Int
    
    /// List identifier this reminder belongs to
    public let listIdentifier: String
    
    /// List title
    public let listTitle: String?
    
    /// Reminder location
    public let location: String?
    
    /// Reminder URL
    public let url: URL?
    
    /// Last modified date
    public let lastModifiedDate: Date?
    
    /// Creation date
    public let creationDate: Date?
    
    /// Has alarms/alerts
    public let hasAlarms: Bool
    
    /// Is recurring reminder
    public let hasRecurrenceRules: Bool
    
    /// Sync timestamp
    public var syncedAt: Date
    
    public init(
        reminderIdentifier: String,
        title: String?,
        notes: String?,
        dueDate: Date?,
        completionDate: Date?,
        isCompleted: Bool,
        priority: Int,
        listIdentifier: String,
        listTitle: String?,
        location: String?,
        url: URL?,
        lastModifiedDate: Date?,
        creationDate: Date?,
        hasAlarms: Bool,
        hasRecurrenceRules: Bool,
        syncedAt: Date = Date()
    ) {
        self.reminderIdentifier = reminderIdentifier
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.completionDate = completionDate
        self.isCompleted = isCompleted
        self.priority = priority
        self.listIdentifier = listIdentifier
        self.listTitle = listTitle
        self.location = location
        self.url = url
        self.lastModifiedDate = lastModifiedDate
        self.creationDate = creationDate
        self.hasAlarms = hasAlarms
        self.hasRecurrenceRules = hasRecurrenceRules
        self.syncedAt = syncedAt
    }
    
    /// Initialize from EKReminder
    public init(from ekReminder: EKReminder, syncedAt: Date = Date()) {
        // Helper function to normalize date precision to seconds
        func normalizeDate(_ date: Date) -> Date {
            return Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded())
        }
        
        // Helper function to normalize optional date
        func normalizeOptionalDate(_ date: Date?) -> Date? {
            guard let date = date else { return nil }
            return normalizeDate(date)
        }
        
        self.init(
            reminderIdentifier: ekReminder.calendarItemIdentifier,
            title: ekReminder.title,
            notes: ekReminder.notes,
            dueDate: normalizeOptionalDate(ekReminder.dueDateComponents?.date),
            completionDate: normalizeOptionalDate(ekReminder.completionDate),
            isCompleted: ekReminder.isCompleted,
            priority: ekReminder.priority,
            listIdentifier: ekReminder.calendar.calendarIdentifier,
            listTitle: ekReminder.calendar.title,
            location: ekReminder.location,
            url: ekReminder.url,
            lastModifiedDate: normalizeOptionalDate(ekReminder.lastModifiedDate),
            creationDate: normalizeOptionalDate(ekReminder.creationDate),
            hasAlarms: !(ekReminder.alarms?.isEmpty ?? true),
            hasRecurrenceRules: ekReminder.hasRecurrenceRules,
            syncedAt: normalizeDate(syncedAt)
        )
    }
}

// MARK: - GRDB Conformance
extension ReminderEvent: FetchableRecord, MutablePersistableRecord {
    /// Database table name
    public static let databaseTableName = "reminder_events"
    
    /// Database column names
    public enum Columns {
        static let reminderIdentifier = Column("reminderIdentifier")
        static let title = Column("title")
        static let notes = Column("notes")
        static let dueDate = Column("dueDate")
        static let completionDate = Column("completionDate")
        static let isCompleted = Column("isCompleted")
        static let priority = Column("priority")
        static let listIdentifier = Column("listIdentifier")
        static let listTitle = Column("listTitle")
        static let location = Column("location")
        static let url = Column("url")
        static let lastModifiedDate = Column("lastModifiedDate")
        static let creationDate = Column("creationDate")
        static let hasAlarms = Column("hasAlarms")
        static let hasRecurrenceRules = Column("hasRecurrenceRules")
        static let syncedAt = Column("syncedAt")
    }
    
    /// Primary key
    public mutating func didInsert(with rowID: Int64, for column: String?) {
        // Reminder identifier is our natural primary key
    }
    
    /// Create table SQL
    public static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.column("reminderIdentifier", .text).primaryKey()
            t.column("title", .text)
            t.column("notes", .text)
            t.column("dueDate", .datetime)
            t.column("completionDate", .datetime)
            t.column("isCompleted", .boolean).notNull()
            t.column("priority", .integer).notNull()
            t.column("listIdentifier", .text).notNull()
            t.column("listTitle", .text)
            t.column("location", .text)
            t.column("url", .text)
            t.column("lastModifiedDate", .datetime)
            t.column("creationDate", .datetime)
            t.column("hasAlarms", .boolean).notNull()
            t.column("hasRecurrenceRules", .boolean).notNull()
            t.column("syncedAt", .datetime).notNull()
        }
    }
}

// MARK: - Manual Codable Implementation
extension ReminderEvent: Codable {
    enum CodingKeys: String, CodingKey {
        case reminderIdentifier
        case title
        case notes
        case dueDate
        case completionDate
        case isCompleted
        case priority
        case listIdentifier
        case listTitle
        case location
        case url
        case lastModifiedDate
        case creationDate
        case hasAlarms
        case hasRecurrenceRules
        case syncedAt
    }
}

// MARK: - Query Extensions
extension ReminderEvent {
    /// Get reminders due today
    public static func dueTodayReminders() -> QueryInterfaceRequest<ReminderEvent> {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return ReminderEvent
            .filter(Columns.dueDate >= startOfDay && Columns.dueDate < endOfDay)
            .filter(Columns.isCompleted == false)
            .order(Columns.dueDate, Columns.priority)
    }
    
    /// Get overdue reminders
    public static func overdueReminders() -> QueryInterfaceRequest<ReminderEvent> {
        let now = Date()
        
        return ReminderEvent
            .filter(Columns.dueDate < now)
            .filter(Columns.isCompleted == false)
            .order(Columns.dueDate, Columns.priority)
    }
    
    /// Get upcoming reminders
    public static func upcomingReminders(limit: Int = 10) -> QueryInterfaceRequest<ReminderEvent> {
        let now = Date()
        
        return ReminderEvent
            .filter(Columns.dueDate > now)
            .filter(Columns.isCompleted == false)
            .order(Columns.dueDate, Columns.priority)
            .limit(limit)
    }
    
    /// Get completed reminders
    public static func completedReminders() -> QueryInterfaceRequest<ReminderEvent> {
        return ReminderEvent
            .filter(Columns.isCompleted == true)
            .order(Columns.completionDate.desc)
    }
    
    /// Get reminders by list
    public static func remindersByList(_ listIdentifier: String) -> QueryInterfaceRequest<ReminderEvent> {
        return ReminderEvent
            .filter(Columns.listIdentifier == listIdentifier)
            .order(Columns.dueDate, Columns.priority)
    }
    
    /// Search reminders by keyword
    public static func searchReminders(keyword: String) -> QueryInterfaceRequest<ReminderEvent> {
        return ReminderEvent
            .filter(Columns.title.like("%\(keyword)%") || Columns.notes.like("%\(keyword)%"))
            .order(Columns.dueDate, Columns.priority)
    }
    
    /// Get high priority reminders
    public static func highPriorityReminders() -> QueryInterfaceRequest<ReminderEvent> {
        return ReminderEvent
            .filter(Columns.priority == 1)
            .filter(Columns.isCompleted == false)
            .order(Columns.dueDate, Columns.syncedAt.desc)
    }
}

extension ReminderEvent: CustomStringConvertible {
    public var description: String {
        let dueDateStr: String
        if let dueDate = dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            dueDateStr = formatter.string(from: dueDate)
        } else {
            dueDateStr = "No due date"
        }
        let completedStr = isCompleted ? "✅" : "⏳"
        return "\(completedStr) \(title ?? "Untitled") - Due: \(dueDateStr)"
    }
} 