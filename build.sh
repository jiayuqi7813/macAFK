#!/bin/bash

# MacAfk Pro 构建脚本
# 用于构建 Pro 版的 ARM64 和 x86_64 版本

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="MacAfk"
PRODUCT_NAME="MacAfk Pro"  # Release 配置中的实际产品名称

BUILD_DIR="$PROJECT_DIR/Build"
ARCHIVE_DIR="$PROJECT_DIR/Archives"
DIST_DIR="$PROJECT_DIR/Dist"

# 获取版本号（从 git tag 或默认值）
VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")}"
# 移除版本号前的 v（如果有）
VERSION="${VERSION#v}"

echo "🏗️  MacAfk Pro 构建脚本"
echo "================================"
echo "版本: $VERSION"
echo ""

# 清理旧的构建产物
echo "🧹 清理旧的构建产物..."
rm -rf "$BUILD_DIR"
rm -rf "$ARCHIVE_DIR"
rm -rf "$DIST_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$DIST_DIR"

# 构建函数
build_variant() {
    local arch=$1     # arm64 或 x86_64
    
    echo ""
    echo "🚀 构建 MacAfk Pro ($arch)..."
    
    local archive_name="MacAfk-Pro-${arch}"
    local export_path="$BUILD_DIR/Pro-${arch}"
    
    # 构建 archive
    xcodebuild -scheme "$PROJECT_NAME" \
        -configuration Release \
        -arch "$arch" \
        -archivePath "$ARCHIVE_DIR/${archive_name}.xcarchive" \
        archive \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO
    
    # 导出 app（直接复制，不使用 exportArchive 以避免签名问题）
    echo "📤 导出应用..."
    mkdir -p "$export_path"
    cp -R "$ARCHIVE_DIR/${archive_name}.xcarchive/Products/Applications/${PRODUCT_NAME}.app" "$export_path/"
    
    echo "✅ MacAfk Pro ($arch) 构建完成！"
}

# 创建 DMG 函数
create_dmg() {
    local arch=$1
    local app_path="$BUILD_DIR/Pro-${arch}/${PRODUCT_NAME}.app"
    local dmg_name="MacAfk-Pro-${arch}-v${VERSION}.dmg"
    local volume_name="MacAfk Pro"
    
    echo ""
    echo "📦 创建 MacAfk Pro ($arch) DMG..."
    
    # 创建临时目录
    local staging_dir="$(mktemp -d)"
    
    # 复制应用
    cp -R "$app_path" "$staging_dir/"
    
    # 创建 Applications 快捷方式
    ln -s /Applications "$staging_dir/Applications"
    
    # 创建安装说明
    cat > "$staging_dir/.install-instructions.txt" << 'EOFINSTALL'
MacAfk Pro - 安装说明

1. 将 MacAfk Pro.app 拖拽到 Applications 文件夹
2. 打开 Applications 文件夹，找到 MacAfk Pro
3. 右键点击 MacAfk Pro，选择"打开"
4. 享受使用！

---

MacAfk Pro - Installation Instructions

1. Drag MacAfk Pro.app to the Applications folder
2. Open Applications folder and find MacAfk Pro
3. Right-click MacAfk Pro and select "Open"
4. Enjoy!
EOFINSTALL
    
    # 创建临时 DMG
    local temp_dmg="$DIST_DIR/temp-${arch}.dmg"
    hdiutil create -srcfolder "$staging_dir" \
        -volname "$volume_name" \
        -fs HFS+ \
        -format UDRW \
        -size 200m \
        "$temp_dmg" > /dev/null
    
    # 挂载 DMG
    local mount_dir="/Volumes/$volume_name"
    hdiutil detach "$mount_dir" 2>/dev/null || true
    hdiutil attach -readwrite -noverify -noautoopen "$temp_dmg" > /dev/null
    sleep 2
    
    # 使用 AppleScript 设置窗口布局
    osascript > /dev/null 2>&1 <<EOFSCRIPT
tell application "Finder"
    tell disk "$volume_name"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 920, 500}
        
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set text size of viewOptions to 12
        
        set position of item "$PRODUCT_NAME.app" of container window to {120, 180}
        set position of item "Applications" of container window to {380, 180}
        
        update without registering applications
        delay 2
        close
    end tell
end tell
EOFSCRIPT
    
    # 卸载并压缩
    sync
    hdiutil detach "$mount_dir" > /dev/null
    hdiutil convert "$temp_dmg" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -o "$DIST_DIR/$dmg_name" > /dev/null
    
    # 清理
    rm -f "$temp_dmg"
    rm -rf "$staging_dir"
    
    echo "✅ DMG 创建完成：$dmg_name"
}

# 构建 Pro 版本
echo ""
echo "═══════════════════════════════"
echo "📦 构建 Pro 版本（真实硬件亮度）"
echo "═══════════════════════════════"
echo "   - 沙盒：禁用"
echo "   - 亮度控制：DisplayServices API"
echo "   - Bundle ID: com.snowywar.MacAfk"

build_variant "arm64"
build_variant "x86_64"

create_dmg "arm64"
create_dmg "x86_64"

# 创建通用二进制（Universal Binary）
echo ""
echo "═══════════════════════════════"
echo "🔗 创建通用二进制版本"
echo "═══════════════════════════════"

create_universal() {
    echo ""
    echo "📦 合并 Pro 版本 (arm64 + x86_64)..."
    
    local arm_app="$BUILD_DIR/Pro-arm64/${PRODUCT_NAME}.app"
    local x86_app="$BUILD_DIR/Pro-x86_64/${PRODUCT_NAME}.app"
    local universal_dir="$BUILD_DIR/Pro-Universal"
    local universal_app="$universal_dir/${PRODUCT_NAME}.app"
    
    mkdir -p "$universal_dir"
    cp -R "$arm_app" "$universal_app"
    
    # 合并二进制文件（可执行文件名称可能是"MacAfk Pro"或"MacAfk"）
    local executable_name=$(basename "$arm_app/Contents/MacOS/"*)
    echo "🔍 检测到可执行文件: $executable_name"
    
    lipo -create \
        "$arm_app/Contents/MacOS/$executable_name" \
        "$x86_app/Contents/MacOS/$executable_name" \
        -output "$universal_app/Contents/MacOS/$executable_name"
    
    # 创建 Universal DMG
    local dmg_name="MacAfk-Pro-Universal-v${VERSION}.dmg"
    local volume_name="MacAfk Pro"
    
    echo ""
    echo "📦 创建 Universal DMG..."
    
    # 创建临时目录
    local staging_dir="$(mktemp -d)"
    
    # 复制应用
    cp -R "$universal_app" "$staging_dir/"
    
    # 创建 Applications 快捷方式
    ln -s /Applications "$staging_dir/Applications"
    
    # 创建安装说明
    cat > "$staging_dir/.install-instructions.txt" << 'EOFINSTALL'
MacAfk Pro - 安装说明

1. 将 MacAfk Pro.app 拖拽到 Applications 文件夹
2. 打开 Applications 文件夹，找到 MacAfk Pro
3. 右键点击 MacAfk Pro，选择"打开"
4. 享受使用！

---

MacAfk Pro - Installation Instructions

1. Drag MacAfk Pro.app to the Applications folder
2. Open Applications folder and find MacAfk Pro
3. Right-click MacAfk Pro and select "Open"
4. Enjoy!
EOFINSTALL
    
    # 创建临时 DMG
    local temp_dmg="$DIST_DIR/temp-universal.dmg"
    hdiutil create -srcfolder "$staging_dir" \
        -volname "$volume_name" \
        -fs HFS+ \
        -format UDRW \
        -size 200m \
        "$temp_dmg" > /dev/null
    
    # 挂载 DMG
    local mount_dir="/Volumes/$volume_name"
    hdiutil detach "$mount_dir" 2>/dev/null || true
    hdiutil attach -readwrite -noverify -noautoopen "$temp_dmg" > /dev/null
    sleep 2
    
    # 使用 AppleScript 设置窗口布局
    osascript > /dev/null 2>&1 <<EOFSCRIPT
tell application "Finder"
    tell disk "$volume_name"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 920, 500}
        
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set text size of viewOptions to 12
        
        set position of item "$PRODUCT_NAME.app" of container window to {120, 180}
        set position of item "Applications" of container window to {380, 180}
        
        update without registering applications
        delay 2
        close
    end tell
end tell
EOFSCRIPT
    
    # 卸载并压缩
    sync
    hdiutil detach "$mount_dir" > /dev/null
    hdiutil convert "$temp_dmg" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -o "$DIST_DIR/$dmg_name" > /dev/null
    
    # 清理
    rm -f "$temp_dmg"
    rm -rf "$staging_dir"
    
    echo "✅ Universal DMG 创建完成：$dmg_name"
}

create_universal

# 生成校验和
echo ""
echo "🔐 生成校验和..."
cd "$DIST_DIR"
shasum -a 256 *.dmg > checksums.txt
echo "✅ 校验和已保存到 checksums.txt"

# 显示结果
echo ""
echo "================================"
echo "🎉 构建完成！"
echo ""
echo "📁 构建产物位置："
echo "   $DIST_DIR/"
echo ""
echo "📦 生成的文件："
ls -lh "$DIST_DIR"
echo ""
echo "📋 版本信息："
echo "   版本号: $VERSION"
echo "   构建时间: $(date)"
echo ""
echo "📋 下一步："
echo "   发布到 GitHub Release"
echo "   验证所有架构的 DMG 文件"
echo ""
