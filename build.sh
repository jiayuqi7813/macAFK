#!/bin/bash

# MacAfk Pro 构建脚本
# 用于构建 Pro 版的 ARM64 和 x86_64 版本

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="MacAfk"

BUILD_DIR="$PROJECT_DIR/Build"
ARCHIVE_DIR="$PROJECT_DIR/Archives"
DIST_DIR="$PROJECT_DIR/Dist"

# 获取版本号（从 git tag 或默认值）
VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")}"

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
    cp -R "$ARCHIVE_DIR/${archive_name}.xcarchive/Products/Applications/MacAfk Pro.app" "$export_path/"
    
    echo "✅ MacAfk Pro ($arch) 构建完成！"
}

# 创建 DMG 函数
create_dmg() {
    local arch=$1
    
    echo ""
    echo "📦 创建 MacAfk Pro ($arch) DMG..."
    
    local source_dir="$BUILD_DIR/Pro-${arch}"
    local dmg_name="MacAfk-Pro-${arch}-v${VERSION}.dmg"
    
    hdiutil create -volname "MacAfk Pro" \
        -srcfolder "$source_dir" \
        -ov -format UDZO \
        "$DIST_DIR/$dmg_name"
    
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
    
    local arm_app="$BUILD_DIR/Pro-arm64/MacAfk Pro.app"
    local x86_app="$BUILD_DIR/Pro-x86_64/MacAfk Pro.app"
    local universal_dir="$BUILD_DIR/Pro-Universal"
    local universal_app="$universal_dir/MacAfk Pro.app"
    
    mkdir -p "$universal_dir"
    cp -R "$arm_app" "$universal_app"
    
    # 合并二进制文件
    lipo -create \
        "$arm_app/Contents/MacOS/$PROJECT_NAME" \
        "$x86_app/Contents/MacOS/$PROJECT_NAME" \
        -output "$universal_app/Contents/MacOS/$PROJECT_NAME"
    
    # 创建 Universal DMG
    local dmg_name="MacAfk-Pro-Universal-v${VERSION}.dmg"
    
    hdiutil create -volname "MacAfk Pro" \
        -srcfolder "$universal_dir" \
        -ov -format UDZO \
        "$DIST_DIR/$dmg_name"
    
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
