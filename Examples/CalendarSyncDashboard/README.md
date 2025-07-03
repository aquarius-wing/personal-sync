# Calendar Sync Dashboard

这是一个使用 CalendarSync 框架的示例 iOS 应用程序，展示了如何同步和管理日历事件与提醒事项。

## 功能特性

- 📅 **日历同步**：自动同步系统日历事件
- ✅ **提醒管理**：同步和显示系统提醒事项
- 📊 **统计面板**：显示同步状态和数据统计
- 🎯 **优先级管理**：突出显示高优先级提醒
- 📱 **现代 UI**：使用 SwiftUI 构建的现代化界面

## 项目结构

```
CalendarSyncDashboard/
├── CalendarSyncDashboard.xcodeproj/    # Xcode 项目文件
├── Sources/CalendarSyncDashboard/      # 源代码
│   ├── CalendarSyncDashboardApp.swift  # 应用入口和管理器
│   ├── ContentView.swift               # 日历视图 (重命名为 CalendarView)
│   ├── RemindersView.swift             # 提醒事项视图
│   ├── EventsListView.swift            # 事件列表视图
│   ├── EventDetailView.swift           # 事件详情视图
│   ├── Assets.xcassets/                # 应用资源
│   └── Preview Content/                # 预览内容
├── Info.plist                          # 应用配置
├── Package.swift                       # Swift Package 配置
└── project.yml                         # XcodeGen 配置

```

## 开发环境要求

- **Xcode**: 15.0+
- **iOS**: 16.0+
- **Swift**: 5.9+
- **macOS**: 13.0+ (用于 Xcode)

## 如何运行

### 方法 1: 使用 Xcode 项目
1. 双击 `CalendarSyncDashboard.xcodeproj` 在 Xcode 中打开
2. 选择目标设备或模拟器
3. 点击运行按钮 (⌘+R)

### 方法 2: 使用 Swift Package Manager
```bash
# 在终端中运行
swift build
```

### 方法 3: 使用命令行构建
```bash
# 使用 xcodebuild
xcodebuild -project CalendarSyncDashboard.xcodeproj -scheme CalendarSyncDashboard -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 权限要求

应用需要以下系统权限：
- **日历访问权限**: 用于读取和同步日历事件
- **提醒事项访问权限**: 用于读取和同步提醒事项

首次运行时，系统会自动请求这些权限。

## 主要功能

### 日历管理
- 查看今日事件
- 浏览即将到来的事件
- 查看事件详情和位置信息
- 手动触发同步

### 提醒管理
- 查看高优先级提醒
- 管理今日提醒事项
- 查看逾期和已完成的提醒
- 显示提醒的详细信息

### 同步状态
- 实时显示同步状态
- 查看同步统计信息
- 错误处理和重试机制

## 项目重新生成

如果需要重新生成 Xcode 项目文件：

```bash
# 确保安装了 xcodegen
brew install xcodegen

# 重新生成项目
xcodegen generate
```

## 依赖关系

- **CalendarSync**: 主要的日历和提醒同步框架
- **GRDB**: 数据库持久化
- **SwiftUI**: 用户界面框架
- **EventKit**: 系统日历和提醒访问

## 故障排除

### 构建错误
1. 确保 Xcode 版本满足要求
2. 清理构建缓存: Product → Clean Build Folder
3. 重新解析依赖: File → Packages → Reset Package Caches

### 权限问题
1. 检查 Info.plist 中的权限描述
2. 在设置中手动授予权限
3. 重启应用

### 同步问题
1. 检查网络连接
2. 验证日历和提醒数据的可用性
3. 查看 Xcode 控制台的错误日志

## 贡献

欢迎提交问题和改进建议！ 