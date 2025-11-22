#!/bin/bash

# MacAfk 发布脚本
# 用于创建版本标签并触发自动构建和发布

set -e

# 配置
APP_NAME="MacAfk"
PUBLIC_REPO="jiayuqi7813/macAFK"  # 请修改为实际的仓库地址

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}$1${NC}"
}

# 显示帮助
show_help() {
    cat << EOF
MacAfk 发布脚本

用法: $0 <版本号> [选项]

参数:
  版本号               版本号，格式如 1.0.0

选项:
  -h, --help          显示此帮助信息
  -p, --preview       预览模式，不实际推送标签
  -f, --force         强制创建标签（覆盖已存在的标签）
  --pre-release       标记为预发布版本
  --no-changelog      跳过更新日志检查
  --skip-checks       跳过所有检查（危险）

示例:
  $0 1.0.0            # 发布版本 1.0.0
  $0 1.1.0-beta       # 发布预览版本 1.1.0-beta
  $0 1.0.1 --preview  # 预览发布 1.0.1
  $0 1.0.0 --force    # 强制重新发布 1.0.0

发布流程:
  1. 验证版本号格式
  2. 检查 Git 仓库状态
  3. 检查 CHANGELOG.md 更新
  4. 生成更新日志预览
  5. 创建并推送标签
  6. 触发 GitHub Actions 自动构建

注意:
  - 推荐在 main 分支上发布
  - 确保所有更改已提交
  - 标签推送后将自动触发构建和发布
EOF
}

# 验证版本号格式
validate_version() {
    local version="$1"
    
    # 基本格式检查：数字.数字.数字[可选后缀]
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+([a-zA-Z0-9.-]*)?$ ]]; then
        print_error "版本号格式无效: $version"
        print_info "正确格式示例: 1.0.0, 1.2.3, 1.0.0-beta, 1.0.0-rc.1"
        exit 1
    fi
    
    print_success "版本号格式验证通过: $version"
}

# 检查 Git 状态
check_git_status() {
    print_info "检查 Git 仓库状态..."
    
    # 检查是否在 Git 仓库中
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "当前目录不是 Git 仓库"
        exit 1
    fi
    
    # 检查是否有未提交的更改
    if ! git diff-index --quiet HEAD --; then
        print_warning "检测到未提交的更改:"
        git status --porcelain
        echo ""
        read -p "是否继续发布？(y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "发布已取消"
            exit 0
        fi
    fi
    
    # 获取当前分支
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    print_info "当前分支: $CURRENT_BRANCH"
    
    # 确保在主分支
    if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
        print_warning "当前不在主分支 (当前: $CURRENT_BRANCH)"
        read -p "是否继续发布？(y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "发布已取消"
            exit 0
        fi
    fi
    
    # 同步远程状态
    print_info "同步远程仓库状态..."
    git fetch --tags
    
    print_success "Git 状态检查完成"
}

# 检查标签是否存在
check_tag_exists() {
    local version="$1"
    local tag_name="v$version"
    
    if git rev-parse "$tag_name" >/dev/null 2>&1; then
        print_warning "标签 $tag_name 已存在"
        
        if [ "$FORCE_TAG" = true ]; then
            print_info "强制模式：将删除并重新创建标签"
            git tag -d "$tag_name" 2>/dev/null || true
            git push origin --delete "$tag_name" 2>/dev/null || true
            print_success "旧标签已删除"
        else
            print_error "标签已存在，请使用 --force 选项强制覆盖"
            exit 1
        fi
    fi
}

# 检查 CHANGELOG.md
check_changelog() {
    local version="$1"
    
    if [ "$SKIP_CHANGELOG" = true ]; then
        print_warning "跳过 CHANGELOG.md 检查"
        return
    fi
    
    print_info "检查 CHANGELOG.md..."
    
    if [ ! -f "CHANGELOG.md" ]; then
        print_warning "未找到 CHANGELOG.md 文件"
        read -p "是否继续发布？(y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "发布已取消"
            exit 0
        fi
        return
    fi
    
    # 检查版本号是否在 CHANGELOG 中
    if ! grep -q "\[$version\]" CHANGELOG.md && ! grep -q "## $version" CHANGELOG.md; then
        print_warning "CHANGELOG.md 中未找到版本 $version"
        print_info "请在 CHANGELOG.md 中添加该版本的更新日志"
        read -p "是否继续发布？(y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "发布已取消"
            exit 0
        fi
    else
        print_success "CHANGELOG.md 检查通过"
    fi
}

# 生成更新日志
generate_changelog() {
    local version="$1"
    local tag_name="v$version"
    
    print_header ""
    print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_header "📝 更新日志预览"
    print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 获取上一个标签
    LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    
    if [ -n "$LAST_TAG" ]; then
        print_info "从 $LAST_TAG 到 HEAD 的更改:"
        echo ""
        
        # 统计提交数
        COMMIT_COUNT=$(git rev-list --count "${LAST_TAG}..HEAD")
        print_info "总计 $COMMIT_COUNT 个提交"
        echo ""
        
        # 显示提交记录（分类）
        echo "功能更新:"
        git log --oneline --no-merges "${LAST_TAG}..HEAD" | grep -i "^[a-f0-9]\+ feat" || echo "  无"
        echo ""
        
        echo "Bug 修复:"
        git log --oneline --no-merges "${LAST_TAG}..HEAD" | grep -i "^[a-f0-9]\+ fix" || echo "  无"
        echo ""
        
        echo "其他更改:"
        git log --oneline --no-merges "${LAST_TAG}..HEAD" | grep -iv "^[a-f0-9]\+ \(feat\|fix\)" | head -10 || echo "  无"
    else
        print_info "这是第一个版本标签"
        echo ""
        print_info "最近的提交:"
        git log --oneline --no-merges -10
    fi
    
    echo ""
    print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 创建发布标签
create_release_tag() {
    local version="$1"
    local tag_name="v$version"
    local is_prerelease="$2"
    
    print_info "创建发布标签: $tag_name"
    
    # 创建标签消息
    local tag_message="Release $APP_NAME v$version"
    if [ "$is_prerelease" = true ]; then
        tag_message="Pre-release $APP_NAME v$version"
    fi
    
    # 添加构建信息
    tag_message="$tag_message

构建信息:
- 时间: $(date '+%Y-%m-%d %H:%M:%S')
- 分支: $(git rev-parse --abbrev-ref HEAD)
- 提交: $(git rev-parse --short HEAD)
- 构建者: $(git config user.name)

版本特性:
- Pro 版本 (ARM64, x86_64, Universal)
- 真实硬件亮度控制
- 多语言支持 (中文/英文)
- 自动构建和发布"
    
    # 创建带注释的标签
    git tag -a "$tag_name" -m "$tag_message"
    
    print_success "标签 $tag_name 创建成功"
    
    if [ "$PREVIEW_MODE" = true ]; then
        print_warning "预览模式：不会推送标签到远程仓库"
        print_info "标签内容:"
        git show "$tag_name"
        echo ""
        print_info "要推送标签，请运行: git push origin $tag_name"
        print_info "要删除标签，请运行: git tag -d $tag_name"
        return
    fi
    
    # 推送标签到远程仓库
    print_info "推送标签到远程仓库..."
    git push origin "$tag_name"
    
    print_success "标签已推送到远程仓库"
}

# 显示发布信息
show_release_info() {
    local version="$1"
    local is_prerelease="$2"
    
    # 获取仓库 URL
    REPO_URL=$(git remote get-url origin | sed 's/.*://' | sed 's/\.git$//')
    if [[ $REPO_URL =~ ^https:// ]]; then
        REPO_PATH=$(echo "$REPO_URL" | sed 's|https://github.com/||')
    else
        REPO_PATH="$REPO_URL"
    fi
    
    echo ""
    print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "🎉 发布流程完成！"
    print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    print_info "📦 版本信息:"
    echo "   版本号: v$version"
    echo "   类型: $([ "$is_prerelease" = true ] && echo "预发布 (Pre-release)" || echo "正式发布 (Release)")"
    echo "   时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    print_info "🔗 相关链接:"
    echo "   构建状态: https://github.com/$REPO_PATH/actions"
    echo "   发布页面: https://github.com/$REPO_PATH/releases/tag/v$version"
    echo "   所有发布: https://github.com/$REPO_PATH/releases"
    echo ""
    
    print_info "📦 预期构建产物:"
    echo "   ✓ MacAfk-Pro-Universal-v$version.dmg"
    echo "   ✓ MacAfk-Pro-arm64-v$version.dmg"
    echo "   ✓ MacAfk-Pro-x86_64-v$version.dmg"
    echo "   ✓ checksums.txt"
    echo ""
    
    print_info "⏳ 后续步骤:"
    echo "   1. GitHub Actions 正在自动构建 Pro 版本"
    echo "   2. 构建完成后将自动创建 Release"
    echo "   3. 所有 DMG 文件将自动上传"
    echo "   4. 预计等待时间: 8-10 分钟"
    echo ""
    
    print_warning "💡 提示:"
    echo "   - 可在 Actions 页面实时查看构建进度"
    echo "   - 构建失败时可在 Actions 页面查看日志"
    echo "   - Release 创建后会收到 GitHub 通知"
    echo ""
    print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 主函数
main() {
    local version=""
    local is_prerelease=false
    
    # 显示 banner
    print_header ""
    print_header "╔════════════════════════════════════════╗"
    print_header "║     MacAfk Release Script v1.0         ║"
    print_header "╚════════════════════════════════════════╝"
    print_header ""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -p|--preview)
                PREVIEW_MODE=true
                shift
                ;;
            -f|--force)
                FORCE_TAG=true
                shift
                ;;
            --pre-release)
                is_prerelease=true
                shift
                ;;
            --no-changelog)
                SKIP_CHANGELOG=true
                shift
                ;;
            --skip-checks)
                SKIP_CHECKS=true
                shift
                ;;
            -*)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$version" ]; then
                    version="$1"
                else
                    print_error "多余的参数: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # 检查版本号参数
    if [ -z "$version" ]; then
        print_error "请提供版本号"
        echo ""
        show_help
        exit 1
    fi
    
    # 去掉版本号前的 'v'（如果有）
    version="${version#v}"
    
    print_info "开始 $APP_NAME v$version 发布流程..."
    echo ""
    
    # 执行发布步骤
    if [ "$SKIP_CHECKS" != true ]; then
        validate_version "$version"
        check_git_status
        check_tag_exists "$version"
        check_changelog "$version"
    else
        print_warning "跳过所有检查（--skip-checks）"
    fi
    
    generate_changelog "$version"
    
    # 确认发布
    if [ "$PREVIEW_MODE" != true ]; then
        echo ""
        print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_warning "⚠️  即将创建并推送标签 v$version"
        print_warning "⚠️  这将触发自动构建和发布流程"
        print_header "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        read -p "确认继续？(y/N) " -n 1 -r
        echo
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "发布已取消"
            exit 0
        fi
    fi
    
    create_release_tag "$version" "$is_prerelease"
    
    if [ "$PREVIEW_MODE" != true ]; then
        show_release_info "$version" "$is_prerelease"
    fi
}

# 设置默认值
PREVIEW_MODE=false
FORCE_TAG=false
SKIP_CHANGELOG=false
SKIP_CHECKS=false

# 运行主函数
main "$@"

