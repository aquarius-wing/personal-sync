import Foundation
import GRDB

/// Database manager for CalendarSync
internal class DatabaseManager {
    private let dbQueue: DatabaseQueue
    private let configuration: CalendarSyncConfiguration
    
    init(configuration: CalendarSyncConfiguration) throws {
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
    }
    
    private func performMigrations(_ db: Database) throws {
        // Future migrations can be added here
        let currentVersion = try db.tableExists("calendar_events") ? 1 : 0
        
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
    func searchEvents(keyword: String) throws -> [CalendarEvent] {
        return try dbQueue.read { db in
            return try CalendarEvent
                .searchEvents(keyword: keyword)
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
            
            // Insert or update events
            for event in newEvents {
                let exists = try CalendarEvent
                    .filter(CalendarEvent.Columns.eventIdentifier == event.eventIdentifier)
                    .fetchCount(db) > 0
                
                var mutableEvent = event
                try mutableEvent.save(db)
                
                if exists {
                    updated += 1
                } else {
                    inserted += 1
                }
            }
            
            // Delete removed events
            let deleted = try CalendarEvent
                .filter(removedIdentifiers.contains(CalendarEvent.Columns.eventIdentifier))
                .deleteAll(db)
            
            return (inserted: inserted, updated: updated, deleted: deleted)
        }
    }
} 