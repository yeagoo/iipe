#!/bin/bash

# iipe PHP Multi-Version Build Script
# 智能构建脚本，支持 PHP 全生命周期版本的自动化构建
# 用法: ./build.sh <php_version> <target_system>
# 示例: ./build.sh 8.3.12 almalinux-9

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
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

# 显示用法
show_usage() {
    echo "用法: $0 <php_version> <target_system> [architecture]"
    echo ""
    echo "参数说明:"
    echo "  php_version   - 完整的 PHP 版本号 (例如: 7.4.33, 8.0.30, 8.3.12, 8.4.0, 8.5.0)"
    echo "  target_system - 目标系统目录名 (例如: almalinux-9, rockylinux-10, openeuler-24.03)"
    echo "  architecture  - 目标架构 (可选，默认: x86_64)"
    echo ""
    echo "支持的目标系统:"
    echo "  RHEL 9 系列: almalinux-9, oraclelinux-9, rockylinux-9, rhel-9, centos-stream-9"
    echo "  RHEL 10 系列: almalinux-10, oraclelinux-10, rockylinux-10, rhel-10, centos-stream-10"
    echo "  其他发行版: openeuler-24.03, openanolis-23, opencloudos-9"
    echo ""
    echo "支持的架构:"
    echo "  x86_64  - Intel/AMD 64位架构 (默认)"
    echo "  aarch64 - ARM 64位架构"
    echo ""
    echo "示例:"
    echo "  $0 7.4.33 almalinux-9             # 为 AlmaLinux 9 x86_64 构建 PHP 7.4.33"
    echo "  $0 8.3.12 rockylinux-10 x86_64    # 为 Rocky Linux 10 x86_64 构建 PHP 8.3.12"
    echo "  $0 8.4.0 openeuler-24.03 aarch64  # 为 openEuler 24.03 ARM64 构建 PHP 8.4.0"
}

# 检查参数
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    print_error "参数数量不正确"
    show_usage
    exit 1
fi

PHP_VERSION="$1"
TARGET_SYSTEM="$2"
ARCHITECTURE="${3:-x86_64}"  # 默认使用 x86_64

# 验证架构
case "$ARCHITECTURE" in
    x86_64|aarch64)
        ;;
    *)
        print_error "不支持的架构: $ARCHITECTURE"
        print_error "支持的架构: x86_64, aarch64"
        exit 1
        ;;
esac

# 验证 PHP 版本格式
if ! echo "$PHP_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+.*$'; then
    print_error "PHP 版本格式不正确: $PHP_VERSION"
    print_error "期望格式: X.Y.Z (例如: 8.3.12)"
    exit 1
fi

# 验证目标系统目录是否存在
if [ ! -d "$TARGET_SYSTEM" ]; then
    print_error "目标系统目录不存在: $TARGET_SYSTEM"
    print_error "请先运行 ./init-project.sh 创建项目结构"
    exit 1
fi

# 解析版本信息
PHP_VERSION_MAJOR=$(echo "$PHP_VERSION" | cut -d. -f1)
PHP_VERSION_MINOR=$(echo "$PHP_VERSION" | cut -d. -f2)
PHP_VERSION_PATCH=$(echo "$PHP_VERSION" | cut -d. -f3)
PHP_VERSION_SHORT="${PHP_VERSION_MAJOR}.${PHP_VERSION_MINOR}"

print_info "构建配置:"
print_info "  PHP 版本: $PHP_VERSION"
print_info "  主版本号: $PHP_VERSION_MAJOR"
print_info "  次版本号: $PHP_VERSION_MINOR"
print_info "  补丁版本: $PHP_VERSION_PATCH"
print_info "  短版本号: $PHP_VERSION_SHORT"
print_info "  目标系统: $TARGET_SYSTEM"
print_info "  目标架构: $ARCHITECTURE"

# 创建 sources 目录
mkdir -p sources
cd sources

# 智能源码管理函数
download_php_source() {
    local version="$1"
    local major=$(echo "$version" | cut -d. -f1)
    local minor=$(echo "$version" | cut -d. -f2)
    local short_version="${major}.${minor}"
    local source_file="php-${version}.tar.xz"
    local source_url=""
    
    print_info "开始智能源码管理..."
    
    # 检查源码是否已存在
    if [ -f "$source_file" ]; then
        print_success "源码文件已存在: $source_file"
        return 0
    fi
    
    # 根据版本选择下载策略
    if [ "$short_version" = "7.4" ]; then
        # PHP 7.4 是 EOL 版本，从 museum 下载
        source_url="https://museum.php.net/php7/php-${version}.tar.xz"
        print_info "检测到 EOL 版本 PHP $short_version，从 museum.php.net 下载"
        
    elif [ "$short_version" = "8.5" ] || [ "$short_version" = "8.6" ] || [ "$short_version" = "8.7" ]; then
        # 未来版本从 GitHub 下载
        source_url="https://github.com/php/php-src/archive/PHP-${version}.tar.gz"
        source_file="php-${version}.tar.gz"
        print_info "检测到开发版本 PHP $short_version，从 GitHub 下载"
        
    elif [ "$major" = "8" ] && [ "$minor" -ge 0 ] && [ "$minor" -le 4 ]; then
        # PHP 8.0-8.4 稳定版本
        source_url="https://www.php.net/distributions/php-${version}.tar.xz"
        print_info "检测到稳定版本 PHP $short_version，从官方站点下载"
        
    else
        print_error "不支持的 PHP 版本: $version"
        exit 1
    fi
    
    print_info "下载 URL: $source_url"
    print_info "目标文件: $source_file"
    
    # 下载源码
    if command -v wget > /dev/null 2>&1; then
        print_info "使用 wget 下载..."
        if ! wget -O "$source_file" "$source_url"; then
            print_error "wget 下载失败"
            exit 1
        fi
    elif command -v curl > /dev/null 2>&1; then
        print_info "使用 curl 下载..."
        if ! curl -L -o "$source_file" "$source_url"; then
            print_error "curl 下载失败"
            exit 1
        fi
    else
        print_error "系统中未找到 wget 或 curl"
        exit 1
    fi
    
    # 验证下载的文件
    if [ ! -f "$source_file" ] || [ ! -s "$source_file" ]; then
        print_error "下载的源码文件无效: $source_file"
        exit 1
    fi
    
    print_success "源码下载完成: $source_file"
}

# 检查并下载源码
print_info "=== 阶段 1: 源码获取 ==="
download_php_source "$PHP_VERSION"

# 返回项目根目录
cd ..

# 确定 Mock 配置
get_mock_config() {
    local system="$1"
    local arch="$2"
    
    case "$system" in
        almalinux-9)
            echo "almalinux-9-${arch}"
            ;;
        almalinux-10)
            echo "almalinux-10-${arch}"
            ;;
        oraclelinux-9)
            echo "oraclelinux-9-${arch}"
            ;;
        oraclelinux-10)
            echo "oraclelinux-10-${arch}"
            ;;
        rockylinux-9)
            echo "rocky-linux-9-${arch}"
            ;;
        rockylinux-10)
            echo "rocky-linux-10-${arch}"
            ;;
        rhel-9)
            echo "rhel-9-${arch}"
            ;;
        rhel-10)
            echo "rhel-10-${arch}"
            ;;
        centos-stream-9)
            echo "centos-stream-9-${arch}"
            ;;
        centos-stream-10)
            echo "centos-stream-10-${arch}"
            ;;
        openeuler-24.03)
            echo "mock_configs/openeuler-24.03-${arch}"
            ;;
        openanolis-23)
            echo "mock_configs/openanolis-23-${arch}"
            ;;
        opencloudos-9)
            echo "mock_configs/opencloudos-9-${arch}"
            ;;
        *)
            print_error "不支持的目标系统: $system"
            exit 1
            ;;
    esac
}

MOCK_CONFIG=$(get_mock_config "$TARGET_SYSTEM" "$ARCHITECTURE")
print_info "Mock 配置: $MOCK_CONFIG"

# 构建 SRPM
print_info "=== 阶段 2: SRPM 构建 ==="

# 切换到目标系统目录
cd "$TARGET_SYSTEM"

# 检查 spec 文件是否存在
if [ ! -f "iipe-php.spec" ]; then
    print_error "在 $TARGET_SYSTEM 目录中未找到 iipe-php.spec 文件"
    exit 1
fi

print_info "正在构建 SRPM..."

# 构建 SRPM，传递丰富的版本变量
SRPM_BUILD_CMD="rpmbuild -bs iipe-php.spec \
    --define \"_topdir \$(pwd)/rpmbuild\" \
    --define \"_sourcedir \$(pwd)/../sources\" \
    --define \"php_version $PHP_VERSION\" \
    --define \"php_version_major $PHP_VERSION_MAJOR\" \
    --define \"php_version_minor $PHP_VERSION_MINOR\" \
    --define \"php_version_patch $PHP_VERSION_PATCH\" \
    --define \"php_version_short $PHP_VERSION_SHORT\" \
    --define \"dist .$(echo $TARGET_SYSTEM | tr '-' '.')\""

print_info "执行命令: $SRPM_BUILD_CMD"

# 创建 rpmbuild 目录结构
mkdir -p rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

# 执行 SRPM 构建
if ! eval "$SRPM_BUILD_CMD"; then
    print_error "SRPM 构建失败"
    exit 1
fi

# 查找生成的 SRPM 文件
SRPM_FILE=$(find rpmbuild/SRPMS -name "*.src.rpm" | head -1)
if [ -z "$SRPM_FILE" ] || [ ! -f "$SRPM_FILE" ]; then
    print_error "未找到生成的 SRPM 文件"
    exit 1
fi

print_success "SRPM 构建完成: $SRPM_FILE"

# Mock 构建
print_info "=== 阶段 3: Mock 构建 ==="

print_info "使用 Mock 配置: $MOCK_CONFIG"
print_info "构建 SRPM: $SRPM_FILE"

# 检查 Mock 配置是否存在
if [[ "$MOCK_CONFIG" == mock_configs/* ]]; then
    # 自定义配置文件
    if [ ! -f "../$MOCK_CONFIG.cfg" ]; then
        print_error "Mock 配置文件不存在: ../$MOCK_CONFIG.cfg"
        exit 1
    fi
    MOCK_CMD="mock -r ../$MOCK_CONFIG.cfg"
else
    # 系统内置配置
    MOCK_CMD="mock -r $MOCK_CONFIG"
fi

# 清理 Mock 环境
print_info "清理 Mock 构建环境..."
if ! $MOCK_CMD --clean; then
    print_warning "Mock 清理失败，继续构建..."
fi

# 初始化 Mock 环境
print_info "初始化 Mock 构建环境..."
if ! $MOCK_CMD --init; then
    print_error "Mock 初始化失败"
    exit 1
fi

# 执行 Mock 构建
print_info "开始 Mock 构建..."
if ! $MOCK_CMD --rebuild "$SRPM_FILE"; then
    print_error "Mock 构建失败"
    exit 1
fi

print_success "Mock 构建完成"

# 输出产物管理
print_info "=== 阶段 4: 产物输出 ==="

# 创建输出目录
OUTPUT_DIR="../repo_output/$TARGET_SYSTEM/$ARCHITECTURE"
mkdir -p "$OUTPUT_DIR"

# 查找构建结果
MOCK_RESULT_DIR="/var/lib/mock/$MOCK_CONFIG/result"
if [[ "$MOCK_CONFIG" == mock_configs/* ]]; then
    # 自定义配置的结果目录
    CONFIG_NAME=$(basename "$MOCK_CONFIG")
    MOCK_RESULT_DIR="/var/lib/mock/$CONFIG_NAME/result"
fi

if [ ! -d "$MOCK_RESULT_DIR" ]; then
    print_error "Mock 结果目录不存在: $MOCK_RESULT_DIR"
    exit 1
fi

# 复制 RPM 包到输出目录
print_info "复制构建产物到输出目录: $OUTPUT_DIR"

if ! cp "$MOCK_RESULT_DIR"/*.rpm "$OUTPUT_DIR/" 2>/dev/null; then
    print_error "复制 RPM 包失败"
    exit 1
fi

# 显示构建结果
print_success "构建产物已输出到: $OUTPUT_DIR"
print_info "构建的 RPM 包:"
ls -la "$OUTPUT_DIR"/*.rpm

# 返回项目根目录
cd ..

# 构建总结
print_success "=== 构建完成 ==="
print_success "PHP 版本: $PHP_VERSION"
print_success "目标系统: $TARGET_SYSTEM"
print_success "目标架构: $ARCHITECTURE"
print_success "输出目录: repo_output/$TARGET_SYSTEM/$ARCHITECTURE"
print_info ""
print_info "下一步操作:"
print_info "1. 检查构建的 RPM 包质量"
print_info "2. 运行 ./publish.sh 创建 YUM/DNF 仓库"
print_info "3. 配置 Web 服务器发布仓库"

# 提供便捷的后续操作建议
echo ""
echo "快速命令参考:"
echo "  查看构建产物: ls -la repo_output/$TARGET_SYSTEM/$ARCHITECTURE/"
echo "  测试安装: sudo dnf install repo_output/$TARGET_SYSTEM/$ARCHITECTURE/iipe-php${PHP_VERSION_MAJOR}${PHP_VERSION_MINOR}-*.rpm"
echo "  创建仓库: ./publish.sh $TARGET_SYSTEM $ARCHITECTURE" 