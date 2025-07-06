import Foundation
import GRDB
import EventKit

/// Represents a synchronized calendar
public struct CalendarInfo: Codable {
    /// Unique calendar identifier
    public let calendarIdentifier: String
    
    /// Calendar title/name
    public let title: String
    
    /// Calendar entity type (.event or .reminder)
    public let type: String
    
    /// Calendar source (iCloud, Local, Google, etc.)
    public let source: String
    
    /// Calendar color represented as hex string (e.g., "#FF0000")
    public let color: String?
    
    /// Whether the calendar allows content modifications
    public let allowsContentModifications: Bool
    
    /// Whether the calendar is subscribed (read-only)
    public let isSubscribed: Bool
    
    /// Calendar source identifier
    public let sourceIdentifier: String?
    
    /// Calendar source title
    public let sourceTitle: String?
    
    /// Calendar source type for internal use
    public let sourceType: String?
    
    /// When this calendar was last synchronized
    public var syncedAt: Date
    
    /// When this calendar was created
    public let createdAt: Date
    
    /// When this calendar was last modified
    public let lastModifiedDate: Date?
    
    // MARK: - Initialization
    
    /// Initialize Calendar from EKCalendar
    public init(from ekCalendar: EKCalendar, entityType: EKEntityType = .event) {
        self.calendarIdentifier = ekCalendar.calendarIdentifier
        self.title = ekCalendar.title
        self.type = CalendarInfo.entityTypeString(from: entityType)
        self.source = CalendarInfo.calendarSourceString(from: ekCalendar.source?.sourceType)
        
        // Convert CGColor to hex string
        if #available(macOS 10.15, *), let cgColor = ekCalendar.cgColor {
            self.color = CalendarInfo.hexString(from: cgColor)
        } else {
            self.color = nil
        }
        
        self.allowsContentModifications = ekCalendar.allowsContentModifications
        self.isSubscribed = ekCalendar.isSubscribed
        self.sourceIdentifier = ekCalendar.source?.sourceIdentifier
        self.sourceTitle = ekCalendar.source?.title
        self.sourceType = CalendarInfo.sourceTypeString(from: ekCalendar.source?.sourceType)
        self.syncedAt = Date()
        self.createdAt = Date()
        self.lastModifiedDate = nil // EKCalendar doesn't provide lastModifiedDate
    }
    
    /// Initialize Calendar manually
    public init(
        calendarIdentifier: String,
        title: String,
        type: String,
        source: String,
        color: String? = nil,
        allowsContentModifications: Bool = true,
        isSubscribed: Bool = false,
        sourceIdentifier: String? = nil,
        sourceTitle: String? = nil,
        sourceType: String? = nil,
        syncedAt: Date = Date(),
        createdAt: Date = Date(),
        lastModifiedDate: Date? = nil
    ) {
        self.calendarIdentifier = calendarIdentifier
        self.title = title
        self.type = type
        self.source = source
        self.color = color
        self.allowsContentModifications = allowsContentModifications
        self.isSubscribed = isSubscribed
        self.sourceIdentifier = sourceIdentifier
        self.sourceTitle = sourceTitle
        self.sourceType = sourceType
        self.syncedAt = syncedAt
        self.createdAt = createdAt
        self.lastModifiedDate = lastModifiedDate
    }
    
    // MARK: - Helper Methods
    
    /// Convert EKEntityType to string
    private static func entityTypeString(from type: EKEntityType) -> String {
        switch type {
        case .event:
            return "event"
        case .reminder:
            return "reminder"
        @unknown default:
            return "event"
        }
    }
    
    /// Convert EKSourceType to user-friendly source string
    private static func calendarSourceString(from type: EKSourceType?) -> String {
        guard let type = type else { return "Local" }
        
        switch type {
        case .local:
            return "Local"
        case .exchange:
            return "Exchange"
        case .calDAV:
            return "CalDAV"
        case .mobileMe:
            return "iCloud"
        case .subscribed:
            return "Subscribed"
        case .birthdays:
            return "Birthdays"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Convert EKSourceType to string for internal use
    private static func sourceTypeString(from type: EKSourceType?) -> String? {
        guard let type = type else { return nil }
        
        switch type {
        case .local:
            return "local"
        case .exchange:
            return "exchange"
        case .calDAV:
            return "caldav"
        case .mobileMe:
            return "mobileme"
        case .subscribed:
            return "subscribed"
        case .birthdays:
            return "birthdays"
        @unknown default:
            return "unknown"
        }
    }
    
    /// Convert CGColor to hex string
    private static func hexString(from cgColor: CGColor) -> String {
        guard let components = cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - GRDB Database Support

extension CalendarInfo: TableRecord, FetchableRecord, PersistableRecord {
    /// Database table name
    public static let databaseTableName = "calendars"
    
    /// Column names
    public enum Columns {
        public static let calendarIdentifier = Column(CodingKeys.calendarIdentifier)
        public static let title = Column(CodingKeys.title)
        public static let type = Column(CodingKeys.type)
        public static let source = Column(CodingKeys.source)
        public static let color = Column(CodingKeys.color)
        public static let allowsContentModifications = Column(CodingKeys.allowsContentModifications)
        public static let isSubscribed = Column(CodingKeys.isSubscribed)
        public static let sourceIdentifier = Column(CodingKeys.sourceIdentifier)
        public static let sourceTitle = Column(CodingKeys.sourceTitle)
        public static let sourceType = Column(CodingKeys.sourceType)
        public static let syncedAt = Column(CodingKeys.syncedAt)
        public static let createdAt = Column(CodingKeys.createdAt)
        public static let lastModifiedDate = Column(CodingKeys.lastModifiedDate)
    }
    
    /// Create table
    public static func createTable(_ db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.column(Columns.calendarIdentifier.name, .text).primaryKey()
            t.column(Columns.title.name, .text).notNull()
            t.column(Columns.type.name, .text).notNull()
            t.column(Columns.source.name, .text).notNull()
            t.column(Columns.color.name, .text)
            t.column(Columns.allowsContentModifications.name, .boolean).notNull().defaults(to: true)
            t.column(Columns.isSubscribed.name, .boolean).notNull().defaults(to: false)
            t.column(Columns.sourceIdentifier.name, .text)
            t.column(Columns.sourceTitle.name, .text)
            t.column(Columns.sourceType.name, .text)
            t.column(Columns.syncedAt.name, .datetime).notNull()
            t.column(Columns.createdAt.name, .datetime).notNull()
            t.column(Columns.lastModifiedDate.name, .datetime)
        }
    }
}

// MARK: - Query Extensions

extension CalendarInfo {
    /// Get all calendars ordered by title
    public static func allCalendars() -> QueryInterfaceRequest<CalendarInfo> {
        return CalendarInfo.order(Columns.title)
    }
    
    /// Get calendars by entity type (event or reminder)
    public static func calendarsByType(_ type: String) -> QueryInterfaceRequest<CalendarInfo> {
        return CalendarInfo.filter(Columns.type == type).order(Columns.title)
    }
    
    /// Get event calendars
    public static func eventCalendars() -> QueryInterfaceRequest<CalendarInfo> {
        return CalendarInfo.filter(Columns.type == "event").order(Columns.title)
    }
    
    /// Get reminder calendars
    public static func reminderCalendars() -> QueryInterfaceRequest<CalendarInfo> {
        return CalendarInfo.filter(Columns.type == "reminder").order(Columns.title)
    }
    
    /// Get calendars that allow modifications
    public static func modifiableCalendars() -> QueryInterfaceRequest<CalendarInfo> {
        return CalendarInfo.filter(Columns.allowsContentModifications == true).order(Columns.title)
    }
    
    /// Get subscribed calendars
    public static func subscribedCalendars() -> QueryInterfaceRequest<CalendarInfo> {
        return CalendarInfo.filter(Columns.isSubscribed == true).order(Columns.title)
    }
    
    /// Search calendars by title
    public static func searchCalendars(keyword: String) -> QueryInterfaceRequest<CalendarInfo> {
        let pattern = "%\(keyword)%"
        return CalendarInfo
            .filter(Columns.title.like(pattern))
            .order(Columns.title)
    }
    
    /// Get calendars by source
    public static func calendarsBySource(_ source: String) -> QueryInterfaceRequest<CalendarInfo> {
        return CalendarInfo
            .filter(Columns.source == source)
            .order(Columns.title)
    }
    
    /// Get calendars by source identifier
    public static func calendarsBySourceIdentifier(_ sourceIdentifier: String) -> QueryInterfaceRequest<CalendarInfo> {
        return CalendarInfo
            .filter(Columns.sourceIdentifier == sourceIdentifier)
            .order(Columns.title)
    }
}

// MARK: - Equatable

extension CalendarInfo: Equatable {
    public static func == (lhs: CalendarInfo, rhs: CalendarInfo) -> Bool {
        return lhs.calendarIdentifier == rhs.calendarIdentifier &&
               lhs.title == rhs.title &&
               lhs.type == rhs.type &&
               lhs.source == rhs.source &&
               lhs.color == rhs.color &&
               lhs.allowsContentModifications == rhs.allowsContentModifications &&
               lhs.isSubscribed == rhs.isSubscribed &&
               lhs.sourceIdentifier == rhs.sourceIdentifier &&
               lhs.sourceTitle == rhs.sourceTitle &&
               lhs.sourceType == rhs.sourceType
    }
}

// MARK: - CustomStringConvertible

extension CalendarInfo: CustomStringConvertible {
    public var description: String {
        return "Calendar(identifier: \(calendarIdentifier), title: \(title), type: \(type), source: \(source))"
    }
} 