import Foundation
import GRDB

/// Database manager for CalendarSync
internal class DatabaseManager {
    private let dbQueue: DatabaseQueue
    private let configuration: PersonalSyncConfiguration
    
    init(configuration: PersonalSyncConfiguration) throws {
        self.configuration = configuration
        
        // Create database queue
        self.dbQueue = try DatabaseQueue(path: configuration.effectiveDatabasePath)
        
        // Setup database
        try setupDatabase()
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() throws {
        try dbQueue.write { db in
            // Create tables
            try CalendarEvent.createTable(db)
            try ReminderEvent.createTable(db)
            try CalendarInfo.createTable(db)
            
            // Create indexes for better performance
            try createIndexes(db)
            
            // Create migration if needed
            try performMigrations(db)
        }
    }
    
    private func createIndexes(_ db: Database) throws {
        // Additional indexes for better query performance
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_calendar_events_start_date 
            ON calendar_events(startDate)
        """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_calendar_events_calendar_id 
            ON calendar_events(calendarIdentifier)
        """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_calendar_events_synced_at 
            ON calendar_events(syncedAt)
        """)
        
        // Reminder indexes
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_reminder_events_due_date 
            ON reminder_events(dueDate)
        """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_reminder_events_list_id 
            ON reminder_events(listIdentifier)
        """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_reminder_events_completed 
            ON reminder_events(isCompleted)
        """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_reminder_events_priority 
            ON reminder_events(priority)
        """)
        
        // Calendar indexes
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_calendars_type 
            ON calendars(type)
        """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_calendars_source_id 
            ON calendars(sourceIdentifier)
        """)
        
        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS idx_calendars_synced_at 
            ON calendars(syncedAt)
        """)
    }
    
    private func performMigrations(_ db: Database) throws {
        // Check if we need to migrate the calendar_events table
        if try db.tableExists("calendar_events") {
            // Check if the table has the new columns
            let tableInfo = try db.columns(in: "calendar_events")
            let columnNames = Set(tableInfo.map { $0.name })
            
            let requiredColumns = Set([
                "eventIdentifier", "title", "notes", "startDate", "endDate", "isAllDay",
                "calendarIdentifier", "calendarTitle", "location", "url", "lastModifiedDate",
                "creationDate", "status", "hasRecurrenceRules", "timeZone", "recurrenceRule",
                "hasAlarms", "attendeesJson", "isDetached", "syncedAt"
            ])
            
            let missingColumns = requiredColumns.subtracting(columnNames)
            
            if !missingColumns.isEmpty {
                if configuration.enableLogging {
                    print("Migrating calendar_events table - adding missing columns: \(missingColumns)")
                }
                
                // Add missing columns
                for column in missingColumns {
                    switch column {
                    case "timeZone":
                        try db.alter(table: "calendar_events") { t in
                            t.add(column: "timeZone", .text)
                        }
                    case "recurrenceRule":
                        try db.alter(table: "calendar_events") { t in
                            t.add(column: "recurrenceRule", .text)
                        }
                    case "hasAlarms":
                        try db.alter(table: "calendar_events") { t in
                            t.add(column: "hasAlarms", .boolean).notNull().defaults(to: false)
                        }
                    case "attendeesJson":
                        try db.alter(table: "calendar_events") { t in
                            t.add(column: "attendeesJson", .text)
                        }
                    case "isDetached":
                        try db.alter(table: "calendar_events") { t in
                            t.add(column: "isDetached", .boolean).notNull().defaults(to: false)
                        }
                    default:
                        break
                    }
                }
            }
        }
        
        // Check and migrate reminder_events table if needed
        if try db.tableExists("reminder_events") {
            let tableInfo = try db.columns(in: "reminder_events")
            let columnNames = Set(tableInfo.map { $0.name })
            
            let requiredColumns = Set([
                "reminderIdentifier", "title", "notes", "dueDate", "completionDate", "isCompleted",
                "priority", "listIdentifier", "listTitle", "url", "lastModifiedDate",
                "creationDate", "hasAlarms", "syncedAt"
            ])
            
            let missingColumns = requiredColumns.subtracting(columnNames)
            
            if !missingColumns.isEmpty && configuration.enableLogging {
                print("Migrating reminder_events table - adding missing columns: \(missingColumns)")
            }
        }
        
        let currentVersion = try db.tableExists("calendar_events") ? 2 : 0
        
        if configuration.enableLogging {
            print("Database version: \(currentVersion)")
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Save events to database
    func saveEvents(_ events: [CalendarEvent]) throws -> Int {
        return try dbQueue.write { db in
            var savedCount = 0
            
            for event in events {
                do {
                    var mutableEvent = event
                    try mutableEvent.save(db)
                    savedCount += 1
                } catch {
                    if configuration.enableLogging {
                        print("Failed to save event \(event.eventIdentifier): \(error)")
                    }
                    // Continue with other events
                }
            }
            
            return savedCount
        }
    }
    
    /// Delete events by identifiers
    func deleteEvents(with identifiers: [String]) throws -> Int {
        return try dbQueue.write { db in
            return try CalendarEvent
                .filter(identifiers.contains(CalendarEvent.Columns.eventIdentifier))
                .deleteAll(db)
        }
    }
    
    /// Get all events
    func getAllEvents() throws -> [CalendarEvent] {
        return try dbQueue.read { db in
            return try CalendarEvent
                .order(CalendarEvent.Columns.startDate)
                .fetchAll(db)
        }
    }
    
    /// Get events in date range
    func getEvents(from startDate: Date, to endDate: Date) throws -> [CalendarEvent] {
        return try dbQueue.read { db in
            return try CalendarEvent
                .eventsInRange(from: startDate, to: endDate)
                .fetchAll(db)
        }
    }
    
    /// Get today's events
    func getTodayEvents() throws -> [CalendarEvent] {
        return try dbQueue.read { db in
            return try CalendarEvent
                .todaysEvents()
                .fetchAll(db)
        }
    }
    
    /// Get upcoming events
    func getUpcomingEvents(limit: Int) throws -> [CalendarEvent] {
        return try dbQueue.read { db in
            return try CalendarEvent
                .upcomingEvents(limit: limit)
                .fetchAll(db)
        }
    }
    
    /// Search events by keyword
    func searchEvents(keyword: String, from: Date? = nil, to: Date? = nil, calendarIdentifierList: [String]? = nil) throws -> [CalendarEvent] {
        return try dbQueue.read { db in
            return try CalendarEvent
                .searchEvents(keyword: keyword, from: from, to: to, calendarIdentifierList: calendarIdentifierList)
                .fetchAll(db)
        }
    }
    
    /// Get events by calendar
    func getEventsByCalendar(_ calendarIdentifier: String) throws -> [CalendarEvent] {
        return try dbQueue.read { db in
            return try CalendarEvent
                .eventsByCalendar(calendarIdentifier)
                .fetchAll(db)
        }
    }
    
    /// Get event by identifier
    func getEvent(by identifier: String) throws -> CalendarEvent? {
        return try dbQueue.read { db in
            return try CalendarEvent
                .filter(CalendarEvent.Columns.eventIdentifier == identifier)
                .fetchOne(db)
        }
    }
    
    /// Check if event exists
    func eventExists(identifier: String) throws -> Bool {
        return try dbQueue.read { db in
            return try CalendarEvent
                .filter(CalendarEvent.Columns.eventIdentifier == identifier)
                .fetchCount(db) > 0
        }
    }
    
    // MARK: - Statistics
    
    /// Get total event count
    func getTotalEventCount() throws -> Int {
        return try dbQueue.read { db in
            return try CalendarEvent.fetchCount(db)
        }
    }
    
    /// Get event count by calendar
    func getEventCount(for calendarIdentifier: String) throws -> Int {
        return try dbQueue.read { db in
            return try CalendarEvent
                .filter(CalendarEvent.Columns.calendarIdentifier == calendarIdentifier)
                .fetchCount(db)
        }
    }
    
    /// Get calendar identifiers with event counts
    func getCalendarStats() throws -> [String: Int] {
        return try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT calendarIdentifier, COUNT(*) as count 
                FROM calendar_events 
                GROUP BY calendarIdentifier
            """)
            
            var stats: [String: Int] = [:]
            for row in rows {
                stats[row["calendarIdentifier"]] = row["count"]
            }
            return stats
        }
    }
    
    /// Get last sync time
    func getLastSyncTime() throws -> Date? {
        return try dbQueue.read { db in
            return try CalendarEvent
                .select(max(CalendarEvent.Columns.syncedAt))
                .fetchOne(db)
        }
    }
    
    // MARK: - Maintenance
    
    /// Clean up old events (older than specified days)
    func cleanupOldEvents(olderThanDays days: Int) throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        return try dbQueue.write { db in
            return try CalendarEvent
                .filter(CalendarEvent.Columns.endDate < cutoffDate)
                .deleteAll(db)
        }
    }
    
    /// Vacuum database to reclaim space
    func vacuumDatabase() throws {
        try dbQueue.write { db in
            try db.execute(sql: "VACUUM")
        }
    }
    
    /// Get database file size
    func getDatabaseSize() throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: configuration.effectiveDatabasePath)
        return attributes[.size] as? Int64 ?? 0
    }
    
    // MARK: - Batch Operations
    
    /// Perform batch update with transaction
    func performBatchUpdate<T>(_ operation: @escaping (Database) throws -> T) throws -> T {
        return try dbQueue.write(operation)
    }
    
    /// Sync events with database (insert new, update existing, delete removed)
    func syncEvents(_ newEvents: [CalendarEvent], removedIdentifiers: [String] = []) throws -> (inserted: Int, updated: Int, deleted: Int) {
        return try dbQueue.write { db in
            var inserted = 0
            var updated = 0
            
            if configuration.enableLogging {
                print("[CalendarSync] Starting sync with \(newEvents.count) events from system")
            }
            
            // Insert or update events
            for event in newEvents {
                let existingEvent = try CalendarEvent
                    .filter(CalendarEvent.Columns.eventIdentifier == event.eventIdentifier)
                    .fetchOne(db)
                
                if let existing = existingEvent {
                    // Check if event actually changed
                    if hasEventChanged(existing: existing, new: event) {
                        var mutableEvent = event
                        // Update syncedAt to current time for changed events
                        mutableEvent.syncedAt = Date()
                        try mutableEvent.save(db)
                        updated += 1
                    }
                    // If no changes, keep existing event as-is (no database update)
                } else {
                    // New event - insert
                    var mutableEvent = event
                    // Set syncedAt to current time for new events
                    mutableEvent.syncedAt = Date()
                    try mutableEvent.save(db)
                    inserted += 1
                    
                    if configuration.enableLogging {
                        print("[CalendarSync] Inserted new event: \(event.eventIdentifier)")
                    }
                }
            }
            
            // Delete removed events
            let deleted = try CalendarEvent
                .filter(removedIdentifiers.contains(CalendarEvent.Columns.eventIdentifier))
                .deleteAll(db)
            
            if configuration.enableLogging && deleted > 0 {
                print("Deleted \(deleted) events")
            }
            
            return (inserted: inserted, updated: updated, deleted: deleted)
        }
    }
    
    /// Check if event has changed (excluding syncedAt timestamp)
    private func hasEventChanged(existing: CalendarEvent, new: CalendarEvent) -> Bool {
        var changedFields: [String] = []
        
        if existing.title != new.title {
            changedFields.append("title")
        }
        if existing.location != new.location {
            changedFields.append("location")
        }
        if existing.notes != new.notes {
            changedFields.append("notes")
        }
        if existing.startDate != new.startDate {
            let diff = existing.startDate.timeIntervalSince(new.startDate)
            changedFields.append("startDate(diff: \(String(format: "%.3f", diff))s)")
        }
        if existing.endDate != new.endDate {
            let diff = existing.endDate.timeIntervalSince(new.endDate)
            changedFields.append("endDate(diff: \(String(format: "%.3f", diff))s)")
        }
        if existing.isAllDay != new.isAllDay {
            changedFields.append("isAllDay")
        }
        if existing.url != new.url {
            changedFields.append("url")
        }
        if existing.status != new.status {
            changedFields.append("status")
        }
        // Skip lastModifiedDate and creationDate comparison as these are system-managed
        // and small precision differences shouldn't trigger updates
        if existing.hasRecurrenceRules != new.hasRecurrenceRules {
            changedFields.append("hasRecurrenceRules")
        }
        if existing.calendarIdentifier != new.calendarIdentifier {
            changedFields.append("calendarIdentifier")
        }
        if existing.calendarTitle != new.calendarTitle {
            changedFields.append("calendarTitle")
        }
        
        let hasChanged = !changedFields.isEmpty
        
        if hasChanged && configuration.enableLogging {
            print("Event \(existing.eventIdentifier) changed fields: \(changedFields.joined(separator: ", "))")
        }
        
        return hasChanged
    }
    
    // MARK: - Reminder CRUD Operations
    
    /// Save reminders to database
    func saveReminders(_ reminders: [ReminderEvent]) throws -> Int {
        return try dbQueue.write { db in
            var savedCount = 0
            
            for reminder in reminders {
                do {
                    var mutableReminder = reminder
                    try mutableReminder.save(db)
                    savedCount += 1
                } catch {
                    if configuration.enableLogging {
                        print("Failed to save reminder \(reminder.reminderIdentifier): \(error)")
                    }
                    // Continue with other reminders
                }
            }
            
            return savedCount
        }
    }
    
    /// Delete reminders by identifiers
    func deleteReminders(with identifiers: [String]) throws -> Int {
        return try dbQueue.write { db in
            return try ReminderEvent
                .filter(identifiers.contains(ReminderEvent.Columns.reminderIdentifier))
                .deleteAll(db)
        }
    }
    
    /// Get all reminders
    func getAllReminders() throws -> [ReminderEvent] {
        return try dbQueue.read { db in
            return try ReminderEvent
                .order(ReminderEvent.Columns.dueDate, ReminderEvent.Columns.priority)
                .fetchAll(db)
        }
    }
    
    /// Get today's reminders
    func getTodayReminders() throws -> [ReminderEvent] {
        return try dbQueue.read { db in
            return try ReminderEvent
                .dueTodayReminders()
                .fetchAll(db)
        }
    }
    
    /// Get overdue reminders
    func getOverdueReminders() throws -> [ReminderEvent] {
        return try dbQueue.read { db in
            return try ReminderEvent
                .overdueReminders()
                .fetchAll(db)
        }
    }
    
    /// Get upcoming reminders
    func getUpcomingReminders(limit: Int) throws -> [ReminderEvent] {
        return try dbQueue.read { db in
            return try ReminderEvent
                .upcomingReminders(limit: limit)
                .fetchAll(db)
        }
    }
    
    /// Get completed reminders
    func getCompletedReminders() throws -> [ReminderEvent] {
        return try dbQueue.read { db in
            return try ReminderEvent
                .completedReminders()
                .fetchAll(db)
        }
    }
    
    /// Get reminders by list
    func getReminders(fromList listIdentifier: String) throws -> [ReminderEvent] {
        return try dbQueue.read { db in
            return try ReminderEvent
                .remindersByList(listIdentifier)
                .fetchAll(db)
        }
    }
    
    /// Search reminders by keyword
    func searchReminders(keyword: String, from: Date? = nil, to: Date? = nil, listIdentifierList: [String]? = nil) throws -> [ReminderEvent] {
        return try dbQueue.read { db in
            return try ReminderEvent
                .searchReminders(keyword: keyword, from: from, to: to, listIdentifierList: listIdentifierList)
                .fetchAll(db)
        }
    }
    
    /// Get high priority reminders
    func getHighPriorityReminders() throws -> [ReminderEvent] {
        return try dbQueue.read { db in
            return try ReminderEvent
                .highPriorityReminders()
                .fetchAll(db)
        }
    }
    
    /// Get reminder by identifier
    func getReminder(by identifier: String) throws -> ReminderEvent? {
        return try dbQueue.read { db in
            return try ReminderEvent
                .filter(ReminderEvent.Columns.reminderIdentifier == identifier)
                .fetchOne(db)
        }
    }
    
    /// Check if reminder exists
    func reminderExists(identifier: String) throws -> Bool {
        return try dbQueue.read { db in
            return try ReminderEvent
                .filter(ReminderEvent.Columns.reminderIdentifier == identifier)
                .fetchCount(db) > 0
        }
    }
    
    // MARK: - Reminder Statistics
    
    /// Get total reminder count
    func getTotalReminderCount() throws -> Int {
        return try dbQueue.read { db in
            return try ReminderEvent.fetchCount(db)
        }
    }
    
    /// Get completed reminder count
    func getCompletedReminderCount() throws -> Int {
        return try dbQueue.read { db in
            return try ReminderEvent
                .filter(ReminderEvent.Columns.isCompleted == true)
                .fetchCount(db)
        }
    }
    
    /// Get overdue reminder count
    func getOverdueReminderCount() throws -> Int {
        let now = Date()
        return try dbQueue.read { db in
            return try ReminderEvent
                .filter(ReminderEvent.Columns.dueDate < now)
                .filter(ReminderEvent.Columns.isCompleted == false)
                .fetchCount(db)
        }
    }
    
    /// Get today reminder count
    func getTodayReminderCount() throws -> Int {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return try dbQueue.read { db in
            return try ReminderEvent
                .filter(ReminderEvent.Columns.dueDate >= startOfDay && ReminderEvent.Columns.dueDate < endOfDay)
                .filter(ReminderEvent.Columns.isCompleted == false)
                .fetchCount(db)
        }
    }
    
    /// Get reminder count by list
    func getReminderCount(for listIdentifier: String) throws -> Int {
        return try dbQueue.read { db in
            return try ReminderEvent
                .filter(ReminderEvent.Columns.listIdentifier == listIdentifier)
                .fetchCount(db)
        }
    }
    
    /// Get reminder list count
    func getReminderListCount() throws -> Int {
        return try dbQueue.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT COUNT(DISTINCT listIdentifier) as count 
                FROM reminder_events
            """)
            return row?["count"] ?? 0
        }
    }
    
    /// Get list identifiers with reminder counts
    func getReminderListStats() throws -> [String: Int] {
        return try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT listIdentifier, COUNT(*) as count 
                FROM reminder_events 
                GROUP BY listIdentifier
            """)
            
            var stats: [String: Int] = [:]
            for row in rows {
                stats[row["listIdentifier"]] = row["count"]
            }
            return stats
        }
    }
    
    /// Get last reminder sync time
    func getLastReminderSyncTime() throws -> Date? {
        return try dbQueue.read { db in
            return try ReminderEvent
                .select(max(ReminderEvent.Columns.syncedAt))
                .fetchOne(db)
        }
    }
    
    /// Save last reminder sync time
    func saveLastReminderSyncTime(_ date: Date) throws {
        // This is implicitly saved when we update reminder syncedAt timestamps
        // No separate storage needed as we can derive it from the reminder data
    }
    
    // MARK: - Reminder Maintenance
    
    /// Clean up completed reminders (older than specified days)
    func cleanupCompletedReminders(olderThanDays days: Int) throws -> Int {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        return try dbQueue.write { db in
            return try ReminderEvent
                .filter(ReminderEvent.Columns.isCompleted == true)
                .filter(ReminderEvent.Columns.completionDate < cutoffDate)
                .deleteAll(db)
        }
    }
    
    /// Sync reminders with database (insert new, update existing, delete removed)
    func syncReminders(_ newReminders: [ReminderEvent], removedIdentifiers: [String] = []) throws -> (inserted: Int, updated: Int, deleted: Int) {
        return try dbQueue.write { db in
            var inserted = 0
            var updated = 0
            
            if configuration.enableLogging {
                print("[ReminderSync] Starting reminder sync with \(newReminders.count) reminders from system")
            }
            
            // Insert or update reminders
            for reminder in newReminders {
                let existingReminder = try ReminderEvent
                    .filter(ReminderEvent.Columns.reminderIdentifier == reminder.reminderIdentifier)
                    .fetchOne(db)
                
                if let existing = existingReminder {
                    // Check if reminder actually changed
                    if hasReminderChanged(existing: existing, new: reminder) {
                        var mutableReminder = reminder
                        // Update syncedAt to current time for changed reminders
                        mutableReminder.syncedAt = Date()
                        try mutableReminder.save(db)
                        updated += 1
                    }
                    // If no changes, keep existing reminder as-is (no database update)
                } else {
                    // New reminder - insert
                    var mutableReminder = reminder
                    // Set syncedAt to current time for new reminders
                    mutableReminder.syncedAt = Date()
                    try mutableReminder.save(db)
                    inserted += 1
                    
                    if configuration.enableLogging {
                        print("[ReminderSync] Inserted new reminder: \(reminder.reminderIdentifier)")
                    }
                }
            }
            
            // Delete removed reminders
            let deleted = try ReminderEvent
                .filter(removedIdentifiers.contains(ReminderEvent.Columns.reminderIdentifier))
                .deleteAll(db)
            
            if configuration.enableLogging && deleted > 0 {
                print("Deleted \(deleted) reminders")
            }
            
            return (inserted: inserted, updated: updated, deleted: deleted)
        }
    }
    
    /// Check if reminder has changed (excluding syncedAt timestamp)
    private func hasReminderChanged(existing: ReminderEvent, new: ReminderEvent) -> Bool {
        var changedFields: [String] = []
        
        if existing.title != new.title {
            changedFields.append("title")
        }
        if existing.notes != new.notes {
            changedFields.append("notes")
        }
        if existing.dueDate != new.dueDate {
            changedFields.append("dueDate")
        }
        if existing.completionDate != new.completionDate {
            changedFields.append("completionDate")
        }
        if existing.isCompleted != new.isCompleted {
            changedFields.append("isCompleted")
        }
        if existing.priority != new.priority {
            changedFields.append("priority")
        }
        if existing.location != new.location {
            changedFields.append("location")
        }
        if existing.url != new.url {
            changedFields.append("url")
        }
        if existing.hasAlarms != new.hasAlarms {
            changedFields.append("hasAlarms")
        }
        if existing.hasRecurrenceRules != new.hasRecurrenceRules {
            changedFields.append("hasRecurrenceRules")
        }
        if existing.listIdentifier != new.listIdentifier {
            changedFields.append("listIdentifier")
        }
        if existing.listTitle != new.listTitle {
            changedFields.append("listTitle")
        }
        
        let hasChanged = !changedFields.isEmpty
        
        if hasChanged && configuration.enableLogging {
            print("Reminder \(existing.reminderIdentifier) changed fields: \(changedFields.joined(separator: ", "))")
        }
        
        return hasChanged
    }
    
    // MARK: - Calendar CRUD Operations
    
    /// Save calendars to database
    func saveCalendars(_ calendars: [CalendarInfo]) throws -> Int {
        return try dbQueue.write { db in
            var savedCount = 0
            
            for calendar in calendars {
                do {
                    let mutableCalendar = calendar
                    try mutableCalendar.save(db)
                    savedCount += 1
                } catch {
                    if configuration.enableLogging {
                        print("Failed to save calendar \(calendar.calendarIdentifier): \(error)")
                    }
                    // Continue with other calendars
                }
            }
            
            return savedCount
        }
    }
    
    /// Delete calendars by identifiers
    func deleteCalendars(with identifiers: [String]) throws -> Int {
        return try dbQueue.write { db in
            return try CalendarInfo
                .filter(identifiers.contains(CalendarInfo.Columns.calendarIdentifier))
                .deleteAll(db)
        }
    }
    
    /// Get all calendars
    func getAllCalendars() throws -> [CalendarInfo] {
        return try dbQueue.read { db in
            return try CalendarInfo
                .allCalendars()
                .fetchAll(db)
        }
    }
    
    /// Get calendar by identifier
    func getCalendar(by identifier: String) throws -> CalendarInfo? {
        return try dbQueue.read { db in
            return try CalendarInfo
                .filter(CalendarInfo.Columns.calendarIdentifier == identifier)
                .fetchOne(db)
        }
    }
    
    /// Get calendars by type
    func getCalendars(byType type: String) throws -> [CalendarInfo] {
        return try dbQueue.read { db in
            return try CalendarInfo
                .calendarsByType(type)
                .fetchAll(db)
        }
    }
    
    /// Get modifiable calendars
    func getModifiableCalendars() throws -> [CalendarInfo] {
        return try dbQueue.read { db in
            return try CalendarInfo
                .modifiableCalendars()
                .fetchAll(db)
        }
    }
    
    /// Get subscribed calendars
    func getSubscribedCalendars() throws -> [CalendarInfo] {
        return try dbQueue.read { db in
            return try CalendarInfo
                .subscribedCalendars()
                .fetchAll(db)
        }
    }
    
    /// Search calendars by title
    func searchCalendars(keyword: String) throws -> [CalendarInfo] {
        return try dbQueue.read { db in
            return try CalendarInfo
                .searchCalendars(keyword: keyword)
                .fetchAll(db)
        }
    }
    
    /// Get calendars by source
    func getCalendars(bySource sourceIdentifier: String) throws -> [CalendarInfo] {
        return try dbQueue.read { db in
            return try CalendarInfo
                .calendarsBySource(sourceIdentifier)
                .fetchAll(db)
        }
    }
    
    /// Check if calendar exists
    func calendarExists(identifier: String) throws -> Bool {
        return try dbQueue.read { db in
            return try CalendarInfo
                .filter(CalendarInfo.Columns.calendarIdentifier == identifier)
                .fetchCount(db) > 0
        }
    }
    
    // MARK: - Calendar Statistics
    
    /// Get total calendar count
    func getTotalCalendarCount() throws -> Int {
        return try dbQueue.read { db in
            return try CalendarInfo.fetchCount(db)
        }
    }
    
    /// Get calendar count by type
    func getCalendarCount(byType type: String) throws -> Int {
        return try dbQueue.read { db in
            return try CalendarInfo
                .filter(CalendarInfo.Columns.type == type)
                .fetchCount(db)
        }
    }
    
    /// Get calendar type statistics
    func getCalendarTypeStats() throws -> [String: Int] {
        return try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT type, COUNT(*) as count 
                FROM calendars 
                GROUP BY type
            """)
            
            var stats: [String: Int] = [:]
            for row in rows {
                stats[row["type"]] = row["count"]
            }
            return stats
        }
    }
    
    /// Get last calendar sync time
    func getLastCalendarSyncTime() throws -> Date? {
        return try dbQueue.read { db in
            return try CalendarInfo
                .select(max(CalendarInfo.Columns.syncedAt))
                .fetchOne(db)
        }
    }
    
    // MARK: - Calendar Sync Operations
    
    /// Sync calendars with database (insert new, update existing, delete removed)
    func syncCalendars(_ newCalendars: [CalendarInfo], removedIdentifiers: [String] = []) throws -> (inserted: Int, updated: Int, deleted: Int) {
        return try dbQueue.write { db in
            var inserted = 0
            var updated = 0
            
            if configuration.enableLogging {
                print("[CalendarSync] Starting calendar sync with \(newCalendars.count) calendars from system")
            }
            
            // Insert or update calendars
            for calendar in newCalendars {
                let existingCalendar = try CalendarInfo
                    .filter(CalendarInfo.Columns.calendarIdentifier == calendar.calendarIdentifier)
                    .fetchOne(db)
                
                if let existing = existingCalendar {
                    // Check if calendar actually changed
                    if hasCalendarChanged(existing: existing, new: calendar) {
                        var mutableCalendar = calendar
                        // Update syncedAt to current time for changed calendars
                        mutableCalendar.syncedAt = Date()
                        try mutableCalendar.save(db)
                        updated += 1
                    }
                    // If no changes, keep existing calendar as-is (no database update)
                } else {
                    // New calendar - insert
                    var mutableCalendar = calendar
                    // Set syncedAt to current time for new calendars
                    mutableCalendar.syncedAt = Date()
                    try mutableCalendar.save(db)
                    inserted += 1
                    
                    if configuration.enableLogging {
                        print("[CalendarSync] Inserted new calendar: \(calendar.calendarIdentifier)")
                    }
                }
            }
            
            // Delete removed calendars
            let deleted = try CalendarInfo
                .filter(removedIdentifiers.contains(CalendarInfo.Columns.calendarIdentifier))
                .deleteAll(db)
            
            if configuration.enableLogging && deleted > 0 {
                print("Deleted \(deleted) calendars")
            }
            
            return (inserted: inserted, updated: updated, deleted: deleted)
        }
    }
    
    /// Check if calendar has changed (excluding syncedAt timestamp)
    private func hasCalendarChanged(existing: CalendarInfo, new: CalendarInfo) -> Bool {
        var changedFields: [String] = []
        
        if existing.title != new.title {
            changedFields.append("title")
        }
        if existing.type != new.type {
            changedFields.append("type")
        }
        if existing.color != new.color {
            changedFields.append("color")
        }
        if existing.isSubscribed != new.isSubscribed {
            changedFields.append("isSubscribed")
        }
        if existing.allowsContentModifications != new.allowsContentModifications {
            changedFields.append("allowsContentModifications")
        }
        if existing.sourceIdentifier != new.sourceIdentifier {
            changedFields.append("sourceIdentifier")
        }
        if existing.sourceTitle != new.sourceTitle {
            changedFields.append("sourceTitle")
        }
        if existing.sourceType != new.sourceType {
            changedFields.append("sourceType")
        }
        
        let hasChanged = !changedFields.isEmpty
        
        if hasChanged && configuration.enableLogging {
            print("Calendar \(existing.calendarIdentifier) changed fields: \(changedFields.joined(separator: ", "))")
        }
        
        return hasChanged
    }
} 