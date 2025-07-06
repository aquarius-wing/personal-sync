# PersonalSync

Automatically sync system calendar data to SQLite database in the background.

* [Overview](#overview)
* [Requirements](#requirements)
* [Getting started](#getting-started)
  * [Permission Setup](#permission-setup)
  * [Basic Usage](#basic-usage)
  * [Real-time Monitoring](#real-time-monitoring)
  * [Custom Configuration](#custom-configuration)
  * [Querying Synced Data](#querying-synced-data)
  * [Sync Status Monitoring](#sync-status-monitoring)
* [API Reference](#api-reference)
* [Best Practices](#best-practices)
* [Demo](#demo)
* [Installation](#installation)

## Overview

PersonalSync is a Swift package that automatically syncs system calendar and reminder data to a SQLite database in the background. It uses the GRDB framework for efficient database operations and starts working automatically once initialized, continuously syncing iOS/macOS system calendar events and reminders without manual intervention.

PersonalSync provides comprehensive automatic synchronization features for both calendars and reminders. You can monitor sync status, customize sync behavior, and query synced data efficiently. The package uses system notifications to listen for calendar and reminder changes and syncs data in real-time.

## Requirements

You can use PersonalSync on the following platforms:

* iOS 13.0+
* macOS 10.15+
* Swift 5.5+
* Xcode 13.0+

## Getting started

### Permission Setup

First, add calendar and reminder access permissions to your Info.plist:

```xml
<key>NSCalendarsUsageDescription</key>
<string>This app needs access to calendar to sync your events.</string>
<key>NSRemindersUsageDescription</key>
<string>This app needs access to reminders to sync your tasks.</string>
```

### Basic Usage

The simplest way to use PersonalSync is to create instances for both calendar and reminder sync with the default configuration. The sync process starts automatically once initialized.

```swift
import PersonalSync

do {
    // Create calendar sync instance and auto-start sync
    let calendarSync = try CalendarSync()
    
    // Create reminder sync instance and auto-start sync
    let reminderSync = try ReminderSync()
    
    // Optional: Set sync status listeners
    calendarSync.onSyncStatusChanged = { status in
        switch status {
        case .syncing:
            print("Syncing calendar data...")
        case .synced(let count):
            print("Successfully synced \(count) events")
        case .error(let error):
            print("Calendar sync error: \(error)")
        }
    }
    
    reminderSync.onSyncStatusChanged = { status in
        switch status {
        case .syncing:
            print("Syncing reminder data...")
        case .synced:
            print("Successfully synced reminders")
        case .error(let error):
            print("Reminder sync error: \(error)")
        }
    }
} catch {
    print("Failed to initialize sync: \(error)")
}
```

### Real-time Monitoring

PersonalSync uses system notifications to monitor calendar changes without polling:

```swift
// Listen for system calendar change notifications
NotificationCenter.default.addObserver(
    forName: .EKEventStoreChanged,
    object: eventStore,
    queue: nil
) { _ in
    // Calendar data changed, sync immediately
    self.syncChanges()
}
```

This approach ensures:
- 📡 **Instant Response**: Immediately triggered when system calendar changes
- 🔋 **Energy Efficient**: Avoids unnecessary polling
- 🎯 **Precise Sync**: Only executes sync when truly needed

### Custom Configuration

You can customize PersonalSync behavior using `PersonalSyncConfiguration`:

```swift
// Custom configuration with auto-start
let config = PersonalSyncConfiguration(
    enableBackgroundSync: true, // Enable background sync
    calendarIdentifiers: ["calendar-id-1", "calendar-id-2"], // Specific calendars to sync
    autoStart: true, // Auto-start sync (default: true)
    enableNotificationSync: true // Enable notification-based real-time sync (default: true)
)

do {
    let calendarSync = try CalendarSync(configuration: config)
    // No need to call sync() - already started listening and syncing
} catch {
    print("Failed to initialize CalendarSync: \(error)")
}
```

### Querying Synced Data

```swift
// Calendar Events
// Get all events
let events = try calendarSync.getAllEvents()

// Query by date range
let startDate = Date()
let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
let weekEvents = try calendarSync.getEvents(from: startDate, to: endDate)

// Search by keyword
let searchResults = try calendarSync.searchEvents(keyword: "meeting")

// Search with optional filters
// Search within a specific date range
let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
let timeRangeResults = try calendarSync.searchEvents(
    keyword: "conference",
    from: Date(),
    to: nextMonth
)

// Search within specific calendars
let workCalendars = ["work-calendar-id", "project-calendar-id"]
let workResults = try calendarSync.searchEvents(
    keyword: "standup",
    calendarIdentifierList: workCalendars
)

// Search with all filters combined
let complexResults = try calendarSync.searchEvents(
    keyword: "team",
    from: Date(),
    to: nextMonth,
    calendarIdentifierList: workCalendars
)

// Get today's events
let todayEvents = try calendarSync.getTodayEvents()

// Get upcoming events
let upcomingEvents = try calendarSync.getUpcomingEvents(limit: 10)

// Reminders
// Get all reminders
let allReminders = try reminderSync.getAllReminders()

// Get today's reminders
let todayReminders = try reminderSync.getTodayReminders()

// Get overdue reminders
let overdueReminders = try reminderSync.getOverdueReminders()

// Get upcoming reminders
let upcomingReminders = try reminderSync.getUpcomingReminders(limit: 10)

// Get completed reminders
let completedReminders = try reminderSync.getCompletedReminders()

// Get reminders from specific lists
let workReminders = try reminderSync.getReminders(fromList: "work-list-id")

// Search reminders by keyword
let reminderSearchResults = try reminderSync.searchReminders(keyword: "buy")

// Search reminders with filters
let urgentReminders = try reminderSync.searchReminders(
    keyword: "urgent",
    from: Date(),
    to: nextMonth,
    listIdentifierList: ["work-list-id", "personal-list-id"]
)

// Get high priority reminders
let highPriorityReminders = try reminderSync.getHighPriorityReminders()
```

### Sync Status Monitoring

```swift
// Check sync status
if calendarSync.isActive {
    print("Calendar sync is running")
}

if reminderSync.isActive {
    print("Reminder sync is running")
}

// Get last sync time
if let lastSync = calendarSync.lastSyncTime {
    print("Calendar last synced: \(lastSync)")
}

if let lastSync = reminderSync.lastSyncTime {
    print("Reminders last synced: \(lastSync)")
}

// Get sync statistics
let calendarStats = calendarSync.syncStatistics
print("Total events: \(calendarStats.totalEvents)")
print("Last sync duration: \(calendarStats.lastSyncDuration)s")

let reminderStats = reminderSync.syncStatistics
print("Total reminders: \(reminderStats.totalReminders)")
print("Completed reminders: \(reminderStats.completedReminders)")
print("Overdue reminders: \(reminderStats.overdueReminders)")
print("Today's reminders: \(reminderStats.todayReminders)")
```

## API Reference

### CalendarSync Class

#### Initialization
- `init() throws` - Create instance with default configuration and auto-start sync
- `init(configuration: PersonalSyncConfiguration) throws` - Create instance with custom configuration

**Note**: Initializers are now throwing - they will throw an error if configuration is invalid or database initialization fails.

#### Properties
- `isActive: Bool { get }` - Whether sync is active
- `lastSyncTime: Date? { get }` - Last sync time
- `syncStatistics: SyncStatistics { get }` - Sync statistics

#### Query Methods
- `getAllEvents() throws -> [CalendarEvent]` - Get all synced events
- `getEvents(from: Date, to: Date) throws -> [CalendarEvent]` - Get events in date range
- `getTodayEvents() throws -> [CalendarEvent]` - Get today's events
- `getUpcomingEvents(limit: Int) throws -> [CalendarEvent]` - Get upcoming events
- `searchEvents(keyword: String, from: Date?, to: Date?, calendarIdentifierList: [String]?) throws -> [CalendarEvent]` - Search events by keyword with optional date range and calendar filter
- `getEventsByCalendar(_ calendarIdentifier: String) throws -> [CalendarEvent]` - Get events from specific calendar

#### Control Methods (Advanced Usage)
- `pause()` - Pause automatic sync
- `resume()` - Resume automatic sync
- `forceSync()` - Force immediate sync

#### Callbacks
- `onSyncStatusChanged: ((SyncStatus) -> Void)?` - Sync status change callback
- `onEventUpdated: ((CalendarEvent, UpdateType) -> Void)?` - Event update callback

### ReminderSync Class

#### Initialization
- `init() throws` - Create instance with default configuration and auto-start sync
- `init(configuration: PersonalSyncConfiguration) throws` - Create instance with custom configuration

#### Properties
- `isActive: Bool { get }` - Whether sync is active
- `lastSyncTime: Date? { get }` - Last sync time
- `syncStatistics: ReminderSyncStatistics { get }` - Sync statistics

#### Query Methods
- `getAllReminders() throws -> [ReminderEvent]` - Get all synced reminders
- `getTodayReminders() throws -> [ReminderEvent]` - Get today's reminders
- `getOverdueReminders() throws -> [ReminderEvent]` - Get overdue reminders
- `getUpcomingReminders(limit: Int) throws -> [ReminderEvent]` - Get upcoming reminders
- `getCompletedReminders() throws -> [ReminderEvent]` - Get completed reminders
- `getReminders(fromList: String) throws -> [ReminderEvent]` - Get reminders from specific list
- `searchReminders(keyword: String, from: Date?, to: Date?, listIdentifierList: [String]?) throws -> [ReminderEvent]` - Search reminders by keyword with optional date range and list filter
- `getHighPriorityReminders() throws -> [ReminderEvent]` - Get high priority reminders

#### Control Methods (Advanced Usage)
- `startSync()` - Start automatic sync
- `stopSync()` - Stop automatic sync
- `pause()` - Pause automatic sync
- `resume()` - Resume automatic sync
- `forceSync()` - Force immediate sync

#### Callbacks
- `onSyncStatusChanged: ((ReminderSyncStatus) -> Void)?` - Sync status change callback
- `onReminderUpdated: ((ReminderEvent, ReminderUpdateType) -> Void)?` - Reminder update callback

### PersonalSyncConfiguration

Configuration options (shared by both CalendarSync and ReminderSync):
- `enableNotificationSync: Bool` - Enable notification-based real-time sync, default: true
- `enableBackgroundSync: Bool` - Enable background sync, default: true
- `calendarIdentifiers: [String]?` - Specific calendar/list IDs to sync, nil means sync all calendars/lists
- `databasePath: String?` - Custom database path
- `autoStart: Bool` - Auto-start sync after initialization, default: true
- `maxRetryAttempts: Int` - Maximum retry attempts on sync failure, default: 3

### SyncStatus Enum

```swift
enum SyncStatus {
    case idle           // Idle state
    case syncing        // Currently syncing
    case synced(Int)    // Sync completed, parameter is event count
    case error(Error)   // Sync error
}
```

### SyncStatistics Structure

- `totalEvents: Int` - Total number of events
- `lastSyncDuration: TimeInterval` - Duration of last sync
- `successfulSyncs: Int` - Number of successful syncs
- `failedSyncs: Int` - Number of failed syncs

### ReminderSyncStatistics Structure

- `totalReminders: Int` - Total number of reminders
- `completedReminders: Int` - Number of completed reminders
- `overdueReminders: Int` - Number of overdue reminders
- `todayReminders: Int` - Number of today's reminders
- `lastSyncTime: Date?` - Last sync time
- `syncDuration: TimeInterval` - Duration of last sync
- `listsCount: Int` - Number of reminder lists
- `lastInserted: Int` - Number of reminders inserted in last sync
- `lastUpdated: Int` - Number of reminders updated in last sync
- `lastDeleted: Int` - Number of reminders deleted in last sync

## Best Practices

### 1. Application Lifecycle Management

```swift
class AppDelegate: UIApplicationDelegate {
    var calendarSync: CalendarSync?
    var reminderSync: ReminderSync?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Auto-start sync when app launches
        do {
            calendarSync = try CalendarSync()
            reminderSync = try ReminderSync()
        } catch {
            print("Failed to initialize sync: \(error)")
            // Handle initialization failure
        }
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Continue sync in background (if configuration allows)
    }
}
```

### 2. Memory Management

```swift
// PersonalSync manages resources automatically, but recommended to set nil when not needed
deinit {
    calendarSync = nil
    reminderSync = nil
}
```

### 3. Error Handling

#### Initialization Error Handling

```swift
do {
    let calendarSync = try CalendarSync()
    let reminderSync = try ReminderSync()
    // Use calendarSync and reminderSync...
} catch PersonalSyncError.invalidConfiguration(let message) {
    print("Configuration error: \(message)")
} catch PersonalSyncError.databaseError(let message) {
    print("Database error: \(message)")
} catch {
    print("Unknown error: \(error)")
}
```

#### Runtime Error Handling

```swift
calendarSync.onSyncStatusChanged = { status in
    switch status {
    case .error(let error):
        // Handle calendar sync errors
        handleCalendarSyncError(error)
    default:
        break
    }
}

reminderSync.onSyncStatusChanged = { status in
    switch status {
    case .error(let error):
        // Handle reminder sync errors
        handleReminderSyncError(error)
    default:
        break
    }
}
```

## Demo

PersonalSync comes with a companion demo project that showcases its capabilities. You can explore the demo to discover the complete feature set, including:

- Real-time calendar and reminder sync visualization
- Query examples with different filters for both events and reminders
- Sync status monitoring for both calendar and reminder synchronization
- Custom configuration options
- Comprehensive search examples for events and reminders

To run the demo project:

1. Clone the repository
2. Open `PersonalSyncDashboard/Package.swift` in Xcode
3. Build and run the project

## Advanced Search Usage

Both `searchEvents` and `searchReminders` methods provide powerful filtering capabilities. Here are comprehensive examples:

```swift
import PersonalSync

do {
    let calendarSync = try CalendarSync()
    let reminderSync = try ReminderSync()
    
    // Calendar Events Search
    // Basic keyword search
    let basicResults = try calendarSync.searchEvents(keyword: "meeting")
    
    // Search within the next 30 days
    let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
    let upcomingMeetings = try calendarSync.searchEvents(
        keyword: "meeting",
        from: Date(),
        to: thirtyDaysFromNow
    )
    
    // Search in specific calendars only
    let workCalendars = ["work-calendar-id", "team-calendar-id"]
    let workEvents = try calendarSync.searchEvents(
        keyword: "project",
        calendarIdentifierList: workCalendars
    )
    
    // Search last week's events
    let lastWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    let lastWeekEvents = try calendarSync.searchEvents(
        keyword: "standup",
        from: lastWeekStart,
        to: Date()
    )
    
    // Complex search: specific keyword, date range, and calendars
    let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    let endOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.end ?? Date()
    let monthlyReports = try calendarSync.searchEvents(
        keyword: "report",
        from: startOfMonth,
        to: endOfMonth,
        calendarIdentifierList: ["work-calendar-id"]
    )
    
    // Reminder Search
    // Basic keyword search for reminders
    let shoppingReminders = try reminderSync.searchReminders(keyword: "buy")
    
    // Search reminders due in the next week
    let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    let upcomingTasks = try reminderSync.searchReminders(
        keyword: "task",
        from: Date(),
        to: nextWeek
    )
    
    // Search in specific reminder lists only
    let workLists = ["work-list-id", "project-list-id"]
    let workTasks = try reminderSync.searchReminders(
        keyword: "deadline",
        listIdentifierList: workLists
    )
    
    // Search overdue reminders from last month
    let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    let overdueReminders = try reminderSync.searchReminders(
        keyword: "urgent",
        from: lastMonth,
        to: Date()
    )
    
    // Complex reminder search: keyword, date range, and specific lists
    let importantTasks = try reminderSync.searchReminders(
        keyword: "important",
        from: Date(),
        to: endOfMonth,
        listIdentifierList: ["work-list-id"]
    )
    
    print("Found \(basicResults.count) total meetings")
    print("Found \(upcomingMeetings.count) upcoming meetings")
    print("Found \(workEvents.count) work project events")
    print("Found \(lastWeekEvents.count) standups last week")
    print("Found \(monthlyReports.count) monthly reports")
    print("Found \(shoppingReminders.count) shopping reminders")
    print("Found \(upcomingTasks.count) upcoming tasks")
    print("Found \(workTasks.count) work deadlines")
    print("Found \(overdueReminders.count) overdue urgent reminders")
    print("Found \(importantTasks.count) important work tasks")
    
} catch {
    print("Search failed: \(error)")
}
```

### Parameter Details

#### Calendar Events Search (`searchEvents`)
- **keyword**: Required. The search term to match against event title, notes, and location
- **from**: Optional. Include only events starting on or after this date
- **to**: Optional. Include only events ending on or before this date  
- **calendarIdentifierList**: Optional. Include only events from these specific calendars

#### Reminder Search (`searchReminders`)
- **keyword**: Required. The search term to match against reminder title and notes
- **from**: Optional. Include only reminders due on or after this date
- **to**: Optional. Include only reminders due on or before this date
- **listIdentifierList**: Optional. Include only reminders from these specific lists

**Note**: All parameters are optional except `keyword`. You can use any combination of the optional parameters to refine your search.

## Installation

### Adding PersonalSync to a Swift Package

To use PersonalSync in a Swift Package Manager project, add the following line to the dependencies in your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/YOUR_USERNAME/PersonalSync.git", from: "1.0.0")
]
```

Include `"PersonalSync"` as a dependency for your executable target:

```swift
.target(name: "<target>", dependencies: [
    .product(name: "PersonalSync", package: "PersonalSync")
])
```

Finally, add `import PersonalSync` to your source code.

### Adding PersonalSync to an Xcode Project

1. From the **File** menu, select **Add Package Dependencies...**
2. Enter `https://github.com/YOUR_USERNAME/PersonalSync.git` into the *Search or Enter Package URL* search field
3. Link **PersonalSync** to your application target

## FAQ

**Q: How do I ensure data is always up-to-date?**  
A: PersonalSync uses system notifications (`.EKEventStoreChanged`) to monitor calendar and reminder changes. Any system calendar or reminder change immediately triggers a sync, ensuring data is always current.

**Q: Will this affect performance?**  
A: The notification-based monitoring is more efficient than polling. Combined with incremental sync and background processing, it has minimal impact on app performance.

**Q: Can I use multiple PersonalSync instances?**  
A: Yes, but we recommend using a singleton pattern to avoid unnecessary resource consumption for both CalendarSync and ReminderSync.

**Q: What happens if sync fails?**  
A: PersonalSync will retry up to `maxRetryAttempts` times (default: 3) before reporting an error through the status callback.

**Q: Do I need separate databases for calendar and reminder data?**  
A: No, PersonalSync uses a single database with separate tables for calendar events and reminders. This allows for efficient querying and unified configuration.

**Q: Can I sync only specific calendars or reminder lists?**  
A: Yes, use the `calendarIdentifiers` configuration option to specify which calendars or reminder lists to sync. If not specified, all available calendars and reminder lists will be synced.

## Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md) first.

## License

PersonalSync is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## Changelog

### v1.0.0
- Initial release
- Automatic calendar and reminder sync functionality
- SQLite data storage with GRDB
- Background sync support
- Real-time calendar and reminder change monitoring using `.EKEventStoreChanged` notifications
- Comprehensive query API for both events and reminders
- Advanced search capabilities with optional filters (date range, calendar/list filters)
- Sync status monitoring for both calendar and reminder synchronization
- Custom configuration options
- Unified database for calendar events and reminders