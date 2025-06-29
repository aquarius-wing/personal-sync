# CalendarSync Examples

这个目录包含了CalendarSync库的完整示例项目。

## CalendarSyncDashboard.xcodeproj

一个完整的iOS示例app，展示了CalendarSync库的所有功能：

### 🎯 主要功能
- **现代化Dashboard**: shadcn风格的界面设计
- **实时同步状态**: 显示同步状态和统计信息
- **事件列表**: 完整的事件浏览、搜索和过滤
- **事件详情**: 详细的事件信息展示

### 🚀 如何运行

1. **双击打开项目**:
   ```
   Examples/CalendarSyncDashboard.xcodeproj
   ```

2. **修复依赖（如果需要）**: 如果遇到"Missing package product 'CalendarSync'"错误：
   ```bash
   cd /Users/wing/Develop/swift-sync-system-data/Examples/
   ./修复依赖.sh
   ```

3. **等待依赖解析**: Xcode会自动解析CalendarSync依赖

4. **选择真机设备**: 模拟器无法访问日历，必须使用真机

5. **运行项目**: 按 Cmd+R 或点击运行按钮

6. **授权日历权限**: 首次运行时选择"允许"访问日历

### 📁 项目结构
```
CalendarSyncDashboard.xcodeproj/
├── CalendarSyncDashboard/
│   ├── CalendarSyncDashboardApp.swift    # 主App文件
│   ├── ContentView.swift                 # Dashboard界面
│   ├── EventsListView.swift             # 事件列表
│   ├── EventDetailView.swift            # 事件详情
│   ├── Info.plist                       # 权限配置
│   ├── Assets.xcassets/                 # 资源文件
│   └── Preview Content/                 # 预览资源
└── project.pbxproj                      # 项目配置
```

### 🔧 自定义配置

你可以在 `CalendarSyncDashboardApp.swift` 中修改配置：

```swift
let config = CalendarSyncConfiguration(
    enableNotificationSync: true,     // 实时同步
    enableBackgroundSync: true,       // 后台同步
    enableLogging: true,             // 调试日志
    autoStart: true                  // 自动启动
)
```

### 🎨 界面特色

- **卡片式设计**: 现代简洁的shadcn风格
- **实时更新**: 响应式数据绑定
- **智能搜索**: 多字段搜索支持
- **时间过滤**: 灵活的时间范围过滤
- **详情展示**: 完整的事件信息

### 🐛 故障排除

**依赖问题**（最常见）:
- 运行修复脚本: `./修复依赖.sh`
- 或在Xcode中: File → Swift Packages → Reset Package Caches

**权限问题**:
- 检查设置 → 隐私与安全性 → 日历
- 删除app重新安装以重置权限

**编译错误**:
- 确保Deployment Target设置为iOS 15.0+
- 清理构建缓存: Product → Clean Build Folder

**运行时错误**:
- 查看Xcode控制台日志
- 确保在真机上测试
- 添加一些测试日历事件

📖 **详细故障排除**: 查看 [`故障排除指南.md`](故障排除指南.md)

### 📝 注意事项

- **必须使用真机**: 模拟器无法访问系统日历
- **需要日历权限**: 首次运行会请求权限
- **测试数据**: 建议先添加一些日历事件用于测试
- **iOS版本**: 最低支持iOS 15.0

---

这个示例项目完全展示了CalendarSync库的强大功能，提供了一个生产就绪的起始点供你进一步开发和定制！ 