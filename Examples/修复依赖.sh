#!/bin/bash

echo "🔧 修复CalendarSync Dashboard的包依赖问题..."
echo ""

# 关闭Xcode（如果正在运行）
echo "📱 关闭Xcode..."
osascript -e 'quit app "Xcode"' 2>/dev/null || true
sleep 2

# 清理Xcode缓存
echo "🧹 清理Xcode缓存..."
rm -rf ~/Library/Developer/Xcode/DerivedData/CalendarSyncDashboard-*
rm -rf CalendarSyncDashboard.xcodeproj/project.xcworkspace/xcuserdata
rm -rf CalendarSyncDashboard.xcodeproj/xcuserdata

# 验证CalendarSync包
echo "✅ 验证CalendarSync包..."
cd ..
swift package resolve
if [ $? -eq 0 ]; then
    echo "✅ CalendarSync包依赖解析成功"
else
    echo "❌ CalendarSync包依赖解析失败"
    exit 1
fi

# 返回Examples目录
cd Examples

# 重新打开Xcode项目
echo "📱 重新打开Xcode项目..."
open CalendarSyncDashboard.xcodeproj

echo ""
echo "✅ 修复完成！"
echo ""
echo "📋 接下来的步骤："
echo "1. 等待Xcode完全加载"
echo "2. 等待包依赖自动解析（可能需要几分钟）"
echo "3. 如果仍有问题，在Xcode中："
echo "   - File → Swift Packages → Reset Package Caches"
echo "   - File → Swift Packages → Resolve Package Versions"
echo "4. 选择真机设备运行"
echo ""
echo "🎉 现在应该可以正常运行了！" 