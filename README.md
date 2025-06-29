# CalendarSync

## What to do?

CalendarSync 是一个Swift包，专门用于自动后台同步系统日历数据到SQLite数据库。它使用GRDB框架提供高效的数据库操作，一旦初始化后即自动开始工作，无需手动干预即可持续同步iOS/macOS系统日历中的事件数据。

### 主要功能

- 🤖 **完全自动**: 初始化后自动开始同步，无需手动调用
- 🗓️ **后台同步**: 在后台持续监听和同步系统日历变化
- 🗃️ **SQLite存储**: 使用GRDB框架进行高效的SQLite数据库操作
- 🔄 **实时监听**: 基于系统通知监听日历变化，立即同步数据
- 📱 **跨平台**: 支持iOS和macOS平台
- ⚡ **高性能**: 优化的增量同步算法，减少资源消耗
- 🔒 **线程安全**: 支持多线程安全访问

## Requirements

- iOS 13.0+ / macOS 10.15+
- Swift 5.5+
- Xcode 13.0+

## Installation

### Swift Package Manager

在Xcode中添加包依赖：

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/swift-sync-system-data", from: "1.0.0")
]
```

## Usage

### 权限配置

首先，在Info.plist中添加日历访问权限：

```xml
<key>NSCalendarsUsageDescription</key>
<string>This app needs access to calendar to sync your events.</string>
```

### 基本用法

```swift
import CalendarSync

do {
    // 创建实例即自动开始同步
    let calendarSync = try CalendarSync()
    
    // 可选：设置同步状态监听
    calendarSync.onSyncStatusChanged = { status in
        switch status {
        case .syncing:
            print("Syncing calendar data...")
        case .synced(let count):
            print("Successfully synced \(count) events")
        case .error(let error):
            print("Sync error: \(error)")
        }
    }
} catch {
    print("Failed to initialize CalendarSync: \(error)")
}
```

### 实时监听机制

CalendarSync内部使用系统通知来监听日历变化，无需轮询：

```swift
// 监听系统日历变化通知
NotificationCenter.default.addObserver(
    forName: .EKEventStoreChanged,
    object: eventStore,
    queue: nil
) { _ in
    // 日历数据发生变化，立即同步
    self.syncChanges()
}
```

这种方式确保了：
- 📡 **即时响应**: 系统日历变化时立即触发同步
- 🔋 **节能高效**: 避免不必要的轮询检查
- 🎯 **精确同步**: 只在真正需要时才执行同步操作

### 自定义配置

```swift
// 自定义配置后自动开始同步
let config = CalendarSyncConfiguration(
    enableBackgroundSync: true, // 启用后台同步
    calendarIdentifiers: ["calendar-id-1", "calendar-id-2"], // 指定要同步的日历
    autoStart: true, // 是否自动开始同步（默认true）
    enableNotificationSync: true // 启用基于通知的实时同步（默认true）
)

do {
    let calendarSync = try CalendarSync(configuration: config)
    // 无需调用sync()，已自动开始监听和同步
} catch {
    print("Failed to initialize CalendarSync: \(error)")
}
```

### 查询同步的数据

```swift
// 查询所有事件
let events = try calendarSync.getAllEvents()

// 按日期范围查询
let startDate = Date()
let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
let weekEvents = try calendarSync.getEvents(from: startDate, to: endDate)

// 按关键词搜索
let searchResults = try calendarSync.searchEvents(keyword: "meeting")

// 获取今日事件
let todayEvents = try calendarSync.getTodayEvents()

// 获取即将到来的事件
let upcomingEvents = try calendarSync.getUpcomingEvents(limit: 10)
```

### 同步状态监控

```swift
// 检查同步状态
if calendarSync.isActive {
    print("Calendar sync is running")
}

// 获取最后同步时间
if let lastSync = calendarSync.lastSyncTime {
    print("Last synced: \(lastSync)")
}

// 获取同步统计信息
let stats = calendarSync.syncStatistics
print("Total events: \(stats.totalEvents)")
print("Last sync duration: \(stats.lastSyncDuration)s")
```

## API Reference

### CalendarSync类

#### 初始化

- `init() throws` - 使用默认配置创建实例并自动开始同步
- `init(configuration: CalendarSyncConfiguration) throws` - 使用自定义配置创建实例

**注意**: 初始化方法现在是throwing的，如果配置无效或数据库初始化失败会抛出错误。

#### 属性

- `isActive: Bool { get }` - 同步是否处于活动状态
- `lastSyncTime: Date? { get }` - 最后同步时间
- `syncStatistics: SyncStatistics { get }` - 同步统计信息

#### 查询方法

- `getAllEvents() throws -> [CalendarEvent]` - 获取所有同步的事件
- `getEvents(from: Date, to: Date) throws -> [CalendarEvent]` - 获取指定日期范围的事件
- `getTodayEvents() throws -> [CalendarEvent]` - 获取今日事件
- `getUpcomingEvents(limit: Int) throws -> [CalendarEvent]` - 获取即将到来的事件
- `searchEvents(keyword: String) throws -> [CalendarEvent]` - 搜索包含关键词的事件
- `getEventsByCalendar(_ calendarIdentifier: String) throws -> [CalendarEvent]` - 获取特定日历的事件

#### 控制方法（高级用法）

- `pause()` - 暂停自动同步
- `resume()` - 恢复自动同步
- `forceSync()` - 强制立即同步一次

#### 回调

- `onSyncStatusChanged: ((SyncStatus) -> Void)?` - 同步状态变化回调
- `onEventUpdated: ((CalendarEvent, UpdateType) -> Void)?` - 事件更新回调

### CalendarSyncConfiguration

配置选项：

- `enableNotificationSync: Bool` - 是否启用基于通知的实时同步，默认true
- `enableBackgroundSync: Bool` - 是否启用后台同步，默认true
- `calendarIdentifiers: [String]?` - 指定要同步的日历ID，nil表示同步所有日历
- `databasePath: String?` - 自定义数据库路径
- `autoStart: Bool` - 是否在初始化后自动开始同步，默认true
- `maxRetryAttempts: Int` - 同步失败时的最大重试次数，默认3

### SyncStatus枚举

```swift
enum SyncStatus {
    case idle           // 空闲状态
    case syncing        // 正在同步
    case synced(Int)    // 同步完成，参数为事件数量
    case error(Error)   // 同步出错
}
```

### SyncStatistics结构

- `totalEvents: Int` - 总事件数
- `lastSyncDuration: TimeInterval` - 上次同步耗时
- `successfulSyncs: Int` - 成功同步次数
- `failedSyncs: Int` - 失败同步次数

## 最佳实践

### 1. 应用生命周期管理

```swift
class AppDelegate: UIApplicationDelegate {
    var calendarSync: CalendarSync?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 应用启动时自动开始同步
        do {
            calendarSync = try CalendarSync()
        } catch {
            print("Failed to initialize CalendarSync: \(error)")
            // 处理初始化失败的情况
        }
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // 进入后台时自动继续同步（如果配置允许）
    }
}
```

### 2. 内存管理

```swift
// CalendarSync会自动管理资源，但建议在不需要时置nil
deinit {
    calendarSync = nil
}
```

### 3. 错误处理

#### 初始化错误处理

```swift
do {
    let calendarSync = try CalendarSync()
    // 使用 calendarSync...
} catch CalendarSyncError.invalidConfiguration(let message) {
    print("配置错误: \(message)")
} catch CalendarSyncError.databaseError(let message) {
    print("数据库错误: \(message)")
} catch {
    print("未知错误: \(error)")
}
```

#### 运行时错误处理

```swift
calendarSync.onSyncStatusChanged = { status in
    switch status {
    case .error(let error):
        // 处理错误，比如权限被拒绝、磁盘空间不足等
        handleSyncError(error)
    default:
        break
    }
}
```

## FAQ

**Q: 如何确保数据是最新的？**
A: CalendarSync使用系统通知(.EKEventStoreChanged)监听日历变化，一旦系统日历有任何变化立即触发同步，确保数据始终是最新的。

**Q: 会影响性能吗？**
A: 基于通知的监听机制比定时轮询更高效，只在日历真正发生变化时才执行同步，结合增量同步和后台处理，对应用性能影响极小。

**Q: 支持多个CalendarSync实例吗？**
A: 支持，但建议使用单例模式以避免不必要的资源消耗。

## Contributing

欢迎贡献代码！请先阅读[贡献指南](CONTRIBUTING.md)。

## License

MIT License. 详见[LICENSE](LICENSE)文件。

## Changelog

### v1.0.0
- 初始版本发布
- 自动日历同步功能
- SQLite数据存储
- 后台同步支持
- 基于系统通知的实时监听日历变化（使用.EKEventStoreChanged通知）