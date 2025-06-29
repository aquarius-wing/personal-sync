# CalendarSync Dashboard iOS App 创建指南

本指南将帮助你创建一个iOS示例app来测试CalendarSync库，展示一个现代化的dashboard界面。

## 前置要求

- macOS 12.0+ 
- Xcode 14.0+
- iOS 15.0+ 设备（用于实机测试）
- Swift 5.5+

## 步骤 1: 创建新的iOS项目

1. 打开Xcode
2. 选择 "Create a new Xcode project"
3. 选择 "iOS" → "App"
4. 填写项目信息：
   - **Product Name**: CalendarSyncDashboard
   - **Bundle Identifier**: com.yourname.calendarsync.dashboard
   - **Language**: Swift
   - **Interface**: SwiftUI
   - **Use Core Data**: 不勾选
   - **Include Tests**: 可选

## 步骤 2: 添加CalendarSync依赖

### 方法 1: 使用Swift Package Manager (推荐)

1. 在Xcode中选择项目文件
2. 选择你的target
3. 点击 "Package Dependencies" 标签
4. 点击 "+" 按钮
5. 输入CalendarSync包的URL (本地路径或GitHub URL)
6. 选择版本并添加

### 方法 2: 直接复制源代码

1. 将 `Sources/CalendarSync/` 下的所有文件复制到你的项目中
2. 在Xcode中右键项目，选择 "Add Files to [ProjectName]"
3. 选择复制的CalendarSync文件

## 步骤 3: 配置权限

将以下内容添加到 `Info.plist` 文件中：

```xml
<key>NSCalendarsUsageDescription</key>
<string>This app needs access to your calendar to sync and display your events in a beautiful dashboard interface.</string>
<key>NSCalendarsFullAccessUsageDescription</key>
<string>This app requires full calendar access to read your events and provide real-time synchronization with the CalendarSync library.</string>
```

或者直接替换整个Info.plist文件为本目录下的 `Info.plist`。

## 步骤 4: 添加源代码文件

将以下文件复制到你的Xcode项目中：

### 1. CalendarSyncDashboardApp.swift
替换原有的 `App.swift` 文件内容

### 2. ContentView.swift
替换原有的 `ContentView.swift` 文件内容

### 3. EventsListView.swift
添加新文件

### 4. EventDetailView.swift
添加新文件

## 步骤 5: 添加依赖

确保在项目设置中添加以下依赖：

1. EventKit.framework
2. GRDB (如果使用SPM安装CalendarSync会自动包含)

### 手动添加EventKit：
1. 选择项目 → target → "Build Phases"
2. 展开 "Link Binary With Libraries"
3. 点击 "+" → 搜索 "EventKit" → 添加

## 步骤 6: 构建和运行

1. 选择真机设备（模拟器可能无法访问日历）
2. 按 Cmd+R 运行项目
3. 首次运行时会请求日历访问权限，请选择"允许"

## 功能特性

### Dashboard主页面
- **同步状态卡片**: 显示当前同步状态和上次同步时间
- **统计卡片**: 显示总事件数、今日事件数、成功率和同步耗时
- **即将到来的事件**: 显示接下来3个事件的预览
- **下拉刷新**: 支持下拉刷新重新加载数据

### 事件列表页面
- **搜索功能**: 可搜索事件标题、描述、地点和日历名称
- **时间过滤**: 支持全部、今天、本周、本月、即将到来的过滤
- **分组显示**: 按日期分组显示事件
- **实时同步**: 支持手动刷新同步

### 事件详情页面
- **完整信息**: 显示事件的所有详细信息
- **时间格式化**: 智能格式化显示时间和持续时长
- **链接支持**: 支持点击事件URL
- **状态指示**: 显示事件状态（确认、暂定、取消等）

## 自定义配置

你可以在 `CalendarSyncDashboardApp.swift` 中修改配置：

```swift
let config = CalendarSyncConfiguration(
    enableNotificationSync: true,      // 启用实时同步
    enableBackgroundSync: true,        // 启用后台同步
    autoStart: true,                   // 自动开始同步
    enableLogging: true,               // 启用日志记录
    maxRetryAttempts: 3,              // 最大重试次数
    syncInterval: 300                  // 同步间隔（秒）
)
```

## 故障排除

### 权限问题
- 确保Info.plist中已添加日历访问权限描述
- 在设置 → 隐私与安全性 → 日历中检查app权限
- 尝试删除app重新安装

### 编译错误
- 确保所有依赖正确添加
- 检查Deployment Target设置为iOS 15.0+
- 清理构建缓存：Product → Clean Build Folder

### 运行时错误
- 检查控制台日志获取详细错误信息
- 确保设备上有日历事件进行测试
- 验证数据库文件权限和路径

## 测试建议

1. **添加测试事件**: 在系统日历中添加一些测试事件
2. **测试权限**: 确保app正确请求和获取日历权限
3. **测试同步**: 在系统日历中修改事件，观察app中的变化
4. **测试搜索**: 使用搜索功能查找特定事件
5. **测试过滤**: 尝试不同的时间过滤选项

## 下一步

- 根据需要自定义UI设计和颜色方案
- 添加更多功能，如事件编辑、日历管理等
- 集成推送通知功能
- 添加数据导出功能
- 实现离线模式支持

## 技术支持

如果遇到问题，请检查：
1. 控制台日志输出
2. CalendarSync库的错误回调
3. 系统日历权限设置
4. 网络连接状况（如果使用远程同步）

---

**注意**: 这个示例app使用了现代的SwiftUI设计模式和shadcn风格的UI组件，提供了流畅的用户体验和完整的日历同步功能展示。 