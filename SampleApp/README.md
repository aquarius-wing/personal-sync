# CalendarSync Dashboard iOS App

这是一个使用CalendarSync库的完整iOS示例应用，展示了如何创建一个现代化的日历同步dashboard。

## 文件结构

```
SampleApp/
├── CalendarSyncDashboardApp.swift  # 主应用文件和状态管理
├── ContentView.swift              # Dashboard主界面
├── EventsListView.swift           # 完整事件列表界面
├── EventDetailView.swift          # 事件详情界面
├── Info.plist                     # 应用配置和权限
├── 如何创建iOS示例App.md           # 详细创建指南
└── README.md                      # 本文件
```

## 主要功能

### 🎯 Dashboard主界面 (ContentView.swift)
- **同步状态监控**: 实时显示同步状态和最后同步时间
- **统计数据展示**: 总事件数、今日事件、成功率、同步耗时
- **即将到来的事件**: 显示接下来3个事件预览
- **下拉刷新**: 手动触发数据重新加载
- **错误处理**: 优雅的错误状态显示

### 📋 事件列表 (EventsListView.swift)
- **智能搜索**: 支持标题、描述、地点、日历名称搜索
- **时间过滤**: 全部/今天/本周/本月/即将到来
- **分组展示**: 按日期智能分组显示事件
- **交互式界面**: 点击事件查看详情

### 📱 事件详情 (EventDetailView.swift)
- **完整信息**: 显示所有事件属性
- **智能格式化**: 时间、持续时长、状态等
- **链接支持**: 可点击的URL链接
- **元数据展示**: 创建时间、修改时间、同步时间等

### 🔧 状态管理 (CalendarSyncManager)
- **响应式数据**: 使用@Published属性自动更新UI
- **错误处理**: 完整的错误捕获和处理机制
- **回调管理**: 处理同步状态变化和事件更新
- **线程安全**: 主线程UI更新保证

## 设计特色

### 🎨 UI设计
- **shadcn风格**: 现代简洁的卡片式设计
- **Material设计**: 使用.regularMaterial背景材质
- **一致性**: 统一的颜色方案和图标系统
- **响应式**: 适配不同屏幕尺寸

### 🚀 用户体验
- **流畅交互**: SwiftUI原生动画和转场
- **即时反馈**: 实时状态更新和进度指示
- **直观导航**: 清晰的信息层次和导航结构
- **无障碍**: 支持VoiceOver和Dynamic Type

### ⚡ 性能优化
- **异步加载**: 数据加载不阻塞UI
- **LazyLoading**: 列表使用LazyVStack优化性能
- **批量处理**: 事件数据批量更新
- **内存管理**: 正确的内存生命周期管理

## 技术栈

- **SwiftUI**: 现代UI框架
- **Combine**: 响应式编程
- **EventKit**: 系统日历访问
- **GRDB**: SQLite数据库
- **CalendarSync**: 自动同步库

## 快速开始

1. 按照 `如何创建iOS示例App.md` 创建Xcode项目
2. 复制所有源代码文件到项目中
3. 配置Info.plist权限
4. 在真机上运行和测试

## 自定义建议

### 颜色主题
```swift
// 在ContentView中自定义颜色
.foregroundColor(.blue) // 改为你的品牌色
```

### 配置选项
```swift
// 在CalendarSyncDashboardApp中调整
let config = CalendarSyncConfiguration(
    enableLogging: true,        // 开发时启用
    syncInterval: 60,          // 更频繁的同步
    batchSize: 50             // 较小的批次大小
)
```

### 功能扩展
- 添加事件创建功能
- 集成推送通知
- 实现数据导出
- 添加主题切换
- 支持多日历管理

## 最佳实践

1. **权限处理**: 始终检查和处理日历权限
2. **错误处理**: 为所有异步操作提供错误处理
3. **性能**: 使用LazyLoading和合适的数据结构
4. **用户体验**: 提供加载状态和错误反馈
5. **测试**: 在真机上测试所有功能

## 故障排除

常见问题解决方案请参考 `如何创建iOS示例App.md` 中的故障排除部分。

---

这个示例app展示了CalendarSync库的完整功能，提供了一个生产就绪的起始点供你进一步开发和定制。 