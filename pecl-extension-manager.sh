#!/bin/bash

# iipe PECL扩展管理工具
# 提供PHP扩展的安装、构建、打包和管理功能

set -e

# 配置
PECL_CONFIG_DIR="pecl-configs"
PECL_BUILD_DIR="pecl-builds" 
PECL_LOG_DIR="logs/pecl"
PECL_REPORTS_DIR="pecl-reports"
PECL_CACHE_DIR="pecl-cache"
PECL_SPEC_DIR="pecl-specs"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 打印函数
print_info() {
    local msg="[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${BLUE}${msg}${NC}"
    echo "$msg" >> "$PECL_LOG_DIR/pecl_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_success() {
    local msg="[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$PECL_LOG_DIR/pecl_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_warning() {
    local msg="[WARNING] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$PECL_LOG_DIR/pecl_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_error() {
    local msg="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${RED}${msg}${NC}"
    echo "$msg" >> "$PECL_LOG_DIR/pecl_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_build() {
    local msg="[BUILD] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${CYAN}${msg}${NC}"
    echo "$msg" >> "$PECL_LOG_DIR/pecl_$(date '+%Y%m%d').log" 2>/dev/null || true
}

# 显示用法
show_usage() {
    echo "iipe PECL扩展管理工具"
    echo ""
    echo "用法: $0 [command] [options]"
    echo ""
    echo "命令:"
    echo "  init                 初始化PECL扩展环境"
    echo "  list-extensions      列出可用扩展"
    echo "  list-installed       列出已安装扩展"
    echo "  install              安装PECL扩展"
    echo "  build                构建扩展RPM包"
    echo "  build-all            构建所有扩展"
    echo "  remove               移除PECL扩展"
    echo "  update               更新扩展到最新版本"
    echo "  check-deps           检查扩展依赖"
    echo "  test-extension       测试扩展功能"
    echo "  generate-spec        生成RPM规格文件"
    echo "  validate             验证扩展配置"
    echo "  status               显示扩展状态"
    echo "  cleanup              清理构建缓存"
    echo ""
    echo "选项:"
    echo "  -e, --extension NAME       扩展名称"
    echo "  -v, --version VERSION      扩展版本"
    echo "  -p, --php-version VERSION  PHP版本 [5.6|7.0|7.1|7.2|7.3|7.4|8.0|8.1|8.2|8.3]"
    echo "  -s, --system SYSTEM        目标系统"
    echo "  -a, --architecture ARCH    目标架构 [x86_64|aarch64] (默认: x86_64)"
    echo "  -c, --config FILE          扩展配置文件"
    echo "  -f, --force                强制执行"
    echo "  -d, --dev                  开发模式（包含调试信息）"
    echo "  -t, --test                 运行扩展测试"
    echo "  -o, --output DIR           输出目录"
    echo "  --with-deps                同时处理依赖"
    echo "  --parallel NUM             并行构建数量"
    echo "  -h, --help                 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 init                                             # 初始化环境"
    echo "  $0 list-extensions                                  # 列出可用扩展"
    echo "  $0 install -e redis -p 8.1 -s almalinux-9          # 安装Redis扩展(x86_64)"
    echo "  $0 build -e redis -p 8.1 -s almalinux-9 -a aarch64 # 构建Redis扩展ARM64版本"
    echo "  $0 build-all -p 8.1 --parallel 4                   # 并行构建所有扩展"
    echo "  $0 test-extension -e redis -p 8.1                  # 测试Redis扩展"
}

# 初始化PECL扩展环境
init_pecl_environment() {
    print_info "初始化PECL扩展环境..."
    
    # 创建目录结构
    mkdir -p "$PECL_CONFIG_DIR" "$PECL_BUILD_DIR" "$PECL_LOG_DIR" \
             "$PECL_REPORTS_DIR" "$PECL_CACHE_DIR" "$PECL_SPEC_DIR"
    
    # 创建扩展配置文件
    create_extension_configs
    
    # 创建构建模板
    create_build_templates
    
    # 检查构建环境
    check_build_environment
    
    print_success "PECL扩展环境初始化完成"
}

# 创建扩展配置文件
create_extension_configs() {
    
    # Redis扩展配置
    cat > "$PECL_CONFIG_DIR/redis.conf" <<EOF
# Redis扩展配置
EXTENSION_NAME="redis"
EXTENSION_VERSION="6.0.2"
EXTENSION_URL="https://pecl.php.net/get/redis-6.0.2.tgz"
EXTENSION_DESCRIPTION="PHP extension for interfacing with Redis"
EXTENSION_LICENSE="PHP-3.01"
EXTENSION_MAINTAINER="iipe team"

# 系统依赖
SYSTEM_DEPS="hiredis-devel"

# PHP版本兼容性
PHP_MIN_VERSION="7.0"
PHP_MAX_VERSION="8.3"

# 构建选项
BUILD_OPTIONS="--enable-redis --enable-redis-igbinary --enable-redis-lzf --enable-redis-zstd"

# 测试命令
TEST_COMMAND="php -m | grep -i redis"

# RPM包信息
RPM_GROUP="Development/Languages"
RPM_SUMMARY="Redis extension for PHP"
EOF

    # MongoDB扩展配置
    cat > "$PECL_CONFIG_DIR/mongodb.conf" <<EOF
# MongoDB扩展配置
EXTENSION_NAME="mongodb"
EXTENSION_VERSION="1.17.2"
EXTENSION_URL="https://pecl.php.net/get/mongodb-1.17.2.tgz"
EXTENSION_DESCRIPTION="MongoDB driver for PHP"
EXTENSION_LICENSE="Apache-2.0"
EXTENSION_MAINTAINER="iipe team"

# 系统依赖
SYSTEM_DEPS="openssl-devel cyrus-sasl-devel"

# PHP版本兼容性
PHP_MIN_VERSION="7.0"
PHP_MAX_VERSION="8.3"

# 构建选项
BUILD_OPTIONS="--enable-mongodb"

# 测试命令
TEST_COMMAND="php -m | grep -i mongodb"

# RPM包信息
RPM_GROUP="Development/Languages"
RPM_SUMMARY="MongoDB extension for PHP"
EOF

    # Xdebug扩展配置
    cat > "$PECL_CONFIG_DIR/xdebug.conf" <<EOF
# Xdebug扩展配置
EXTENSION_NAME="xdebug"
EXTENSION_VERSION="3.3.1"
EXTENSION_URL="https://pecl.php.net/get/xdebug-3.3.1.tgz"
EXTENSION_DESCRIPTION="Xdebug is a debugger and profiler tool for PHP"
EXTENSION_LICENSE="Xdebug-1.03"
EXTENSION_MAINTAINER="iipe team"

# 系统依赖
SYSTEM_DEPS=""

# PHP版本兼容性
PHP_MIN_VERSION="8.0"
PHP_MAX_VERSION="8.3"

# 构建选项
BUILD_OPTIONS="--enable-xdebug"

# 测试命令
TEST_COMMAND="php -m | grep -i xdebug"

# RPM包信息
RPM_GROUP="Development/Languages"
RPM_SUMMARY="Xdebug extension for PHP"
EOF

    # Imagick扩展配置
    cat > "$PECL_CONFIG_DIR/imagick.conf" <<EOF
# ImageMagick扩展配置
EXTENSION_NAME="imagick"
EXTENSION_VERSION="3.7.0"
EXTENSION_URL="https://pecl.php.net/get/imagick-3.7.0.tgz"
EXTENSION_DESCRIPTION="ImageMagick extension for PHP"
EXTENSION_LICENSE="PHP-3.01"
EXTENSION_MAINTAINER="iipe team"

# 系统依赖
SYSTEM_DEPS="ImageMagick-devel"

# PHP版本兼容性
PHP_MIN_VERSION="7.1"
PHP_MAX_VERSION="8.3"

# 构建选项
BUILD_OPTIONS="--with-imagick"

# 测试命令
TEST_COMMAND="php -m | grep -i imagick"

# RPM包信息
RPM_GROUP="Development/Languages"
RPM_SUMMARY="ImageMagick extension for PHP"
EOF

    # YAML扩展配置
    cat > "$PECL_CONFIG_DIR/yaml.conf" <<EOF
# YAML扩展配置
EXTENSION_NAME="yaml"
EXTENSION_VERSION="2.2.3"
EXTENSION_URL="https://pecl.php.net/get/yaml-2.2.3.tgz"
EXTENSION_DESCRIPTION="YAML-1.1 parser and emitter"
EXTENSION_LICENSE="MIT"
EXTENSION_MAINTAINER="iipe team"

# 系统依赖
SYSTEM_DEPS="libyaml-devel"

# PHP版本兼容性
PHP_MIN_VERSION="7.0"
PHP_MAX_VERSION="8.3"

# 构建选项
BUILD_OPTIONS="--with-yaml"

# 测试命令
TEST_COMMAND="php -m | grep -i yaml"

# RPM包信息
RPM_GROUP="Development/Languages"
RPM_SUMMARY="YAML extension for PHP"
EOF

    # APCu扩展配置
    cat > "$PECL_CONFIG_DIR/apcu.conf" <<EOF
# APCu扩展配置
EXTENSION_NAME="apcu"
EXTENSION_VERSION="5.1.23"
EXTENSION_URL="https://pecl.php.net/get/apcu-5.1.23.tgz"
EXTENSION_DESCRIPTION="APC User Cache"
EXTENSION_LICENSE="PHP-3.01"
EXTENSION_MAINTAINER="iipe team"

# 系统依赖
SYSTEM_DEPS=""

# PHP版本兼容性
PHP_MIN_VERSION="7.0"
PHP_MAX_VERSION="8.3"

# 构建选项
BUILD_OPTIONS="--enable-apcu"

# 测试命令
TEST_COMMAND="php -m | grep -i apcu"

# RPM包信息
RPM_GROUP="Development/Languages"
RPM_SUMMARY="APCu extension for PHP"
EOF

    print_success "扩展配置文件创建完成"
}

# 创建构建模板
create_build_templates() {
    
    # 创建通用RPM规格文件模板
    cat > "$PECL_SPEC_DIR/pecl-extension.spec.template" <<'EOF'
%define php_version __PHP_VERSION__
%define php_series __PHP_SERIES__
%define extension_name __EXTENSION_NAME__
%define extension_version __EXTENSION_VERSION__

Name:           iipe-php%{php_series}-%{extension_name}
Version:        %{extension_version}
Release:        1%{?dist}
Summary:        __EXTENSION_SUMMARY__

License:        __EXTENSION_LICENSE__
URL:            https://pecl.php.net/package/%{extension_name}
Source0:        __EXTENSION_URL__

BuildRequires:  iipe-php%{php_series}-devel
BuildRequires:  iipe-php%{php_series}-pear
__SYSTEM_DEPS_BUILDREQUIRES__

Requires:       iipe-php%{php_series}
__SYSTEM_DEPS_REQUIRES__

%description
__EXTENSION_DESCRIPTION__

This package provides the %{extension_name} extension for PHP %{php_version}
as part of the iipe (Intelligent Infrastructure for PHP Ecosystem) project.

%prep
%setup -q -n %{extension_name}-%{extension_version}

%build
export PATH="/opt/iipe/php%{php_series}/bin:$PATH"
phpize
%configure __BUILD_OPTIONS__
make %{?_smp_mflags}

%install
export PATH="/opt/iipe/php%{php_series}/bin:$PATH"
make install INSTALL_ROOT=%{buildroot}

# Install config file
mkdir -p %{buildroot}/opt/iipe/php%{php_series}/etc/php.d
cat > %{buildroot}/opt/iipe/php%{php_series}/etc/php.d/40-%{extension_name}.ini <<EOL
; Enable %{extension_name} extension
extension=%{extension_name}.so
EOL

%files
/opt/iipe/php%{php_series}/lib/php/extensions/*/%{extension_name}.so
/opt/iipe/php%{php_series}/etc/php.d/40-%{extension_name}.ini

%changelog
* __BUILD_DATE__ iipe team <team@iipe.org> - %{extension_version}-1
- Initial package for %{extension_name} %{extension_version}
- Built for PHP %{php_version}
EOF

    print_success "构建模板创建完成"
}

# 检查构建环境
check_build_environment() {
    print_info "检查PECL扩展构建环境..."
    
    local missing_tools=()
    
    # 检查必要工具
    local required_tools=("gcc" "make" "autoconf" "pkg-config")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "缺少必要工具: ${missing_tools[*]}"
        print_info "请安装: sudo dnf install -y ${missing_tools[*]}"
        return 1
    fi
    
    print_success "构建环境检查通过"
}

# 列出可用扩展
list_available_extensions() {
    print_info "可用的PECL扩展:"
    echo ""
    
    printf "%-15s %-10s %-20s %-50s\n" "扩展名" "版本" "PHP兼容性" "描述"
    printf "%-15s %-10s %-20s %-50s\n" "-----" "----" "--------" "----"
    
    for config_file in "$PECL_CONFIG_DIR"/*.conf; do
        if [ -f "$config_file" ]; then
            source "$config_file"
            printf "%-15s %-10s %-20s %-50s\n" \
                "$EXTENSION_NAME" \
                "$EXTENSION_VERSION" \
                "${PHP_MIN_VERSION}-${PHP_MAX_VERSION}" \
                "$(echo "$EXTENSION_DESCRIPTION" | cut -c1-48)..."
        fi
    done
    echo ""
}

# 检查PHP版本兼容性
check_php_compatibility() {
    local target_version="$1"
    local min_version="$2"
    local max_version="$3"
    
    # 简单的版本比较 (可以改进为更精确的版本比较)
    if [[ "$target_version" < "$min_version" ]] || [[ "$target_version" > "$max_version" ]]; then
        return 1
    fi
    
    return 0
}

# 检查系统依赖
check_system_dependencies() {
    local deps="$1"
    local missing_deps=()
    
    for dep in $deps; do
        if ! rpm -q "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_warning "缺少系统依赖: ${missing_deps[*]}"
        print_info "请安装: sudo dnf install -y ${missing_deps[*]}"
    fi
}

# 安装PECL扩展
install_pecl_extension() {
    local extension_name="$1"
    local php_version="$2"
    local system="$3"
    local architecture="$4"
    local force="${5:-false}"
    
    if [ -z "$extension_name" ] || [ -z "$php_version" ] || [ -z "$system" ] || [ -z "$architecture" ]; then
        print_error "使用方法: install_pecl_extension <扩展名> <PHP版本> <系统> <架构> [force]"
        return 1
    fi
    
    local config_file="$PECL_CONFIG_DIR/${extension_name}.conf"
    if [ ! -f "$config_file" ]; then
        print_error "扩展配置不存在: $extension_name"
        return 1
    fi
    
    # 加载扩展配置
    source "$config_file"
    
    print_info "开始安装扩展: $extension_name $EXTENSION_VERSION for PHP $php_version"
    
    # 检查PHP版本兼容性
    if ! check_php_compatibility "$php_version" "$PHP_MIN_VERSION" "$PHP_MAX_VERSION"; then
        print_error "PHP版本 $php_version 不兼容 ($PHP_MIN_VERSION - $PHP_MAX_VERSION)"
        return 1
    fi
    
    # 检查系统依赖
    if [ -n "$SYSTEM_DEPS" ]; then
        check_system_dependencies "$SYSTEM_DEPS"
    fi
    
    # 构建扩展
    build_extension "$extension_name" "$php_version" "$system" "$architecture" "$force"
    
    print_success "扩展 $extension_name 安装完成"
}

# 构建扩展
build_extension() {
    local extension_name="$1"
    local php_version="$2"
    local system="$3"
    local architecture="$4"
    local force="$5"
    
    local php_series=$(echo "$php_version" | sed 's/\.//')
    local build_dir="$PECL_BUILD_DIR/${extension_name}-${php_version}-${system}-${architecture}"
    
    print_build "构建扩展: $extension_name for PHP $php_version on $system"
    
    # 准备构建目录
    if [ "$force" = "true" ] && [ -d "$build_dir" ]; then
        rm -rf "$build_dir"
    fi
    
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # 加载扩展配置
    source "$PECL_CONFIG_DIR/${extension_name}.conf"
    
    # 下载源码
    local source_file="${extension_name}-${EXTENSION_VERSION}.tgz"
    if [ ! -f "$PECL_CACHE_DIR/$source_file" ]; then
        print_info "下载扩展源码..."
        wget "$EXTENSION_URL" -O "$PECL_CACHE_DIR/$source_file" || {
            print_error "下载失败: $EXTENSION_URL"
            return 1
        }
    fi
    
    # 复制并解压源码
    cp "$PECL_CACHE_DIR/$source_file" .
    tar -xzf "$source_file"
    
    local source_dir="${extension_name}-${EXTENSION_VERSION}"
    cd "$source_dir"
    
    # 生成RPM规格文件
    generate_rpm_spec "$extension_name" "$php_version" "$system" "$architecture"
    
    # 使用Mock构建RPM包
    if command -v mock >/dev/null 2>&1; then
        build_rpm_with_mock "$extension_name" "$php_version" "$system" "$architecture"
    else
        print_warning "Mock未安装，跳过RPM构建"
    fi
    
    cd - >/dev/null
}

# 生成RPM规格文件
generate_rpm_spec() {
    local extension_name="$1"
    local php_version="$2"
    local system="$3"
    local architecture="$4"
    
    local php_series=$(echo "$php_version" | sed 's/\.//')
    local spec_file="${extension_name}.spec"
    
    print_info "生成RPM规格文件: $spec_file"
    
    # 复制模板
    cp "$PECL_SPEC_DIR/pecl-extension.spec.template" "$spec_file"
    
    # 加载扩展配置
    source "$PECL_CONFIG_DIR/${extension_name}.conf"
    
    # 替换模板变量
    sed -i "s|__PHP_VERSION__|$php_version|g" "$spec_file"
    sed -i "s|__PHP_SERIES__|$php_series|g" "$spec_file"
    sed -i "s|__EXTENSION_NAME__|$EXTENSION_NAME|g" "$spec_file"
    sed -i "s|__EXTENSION_VERSION__|$EXTENSION_VERSION|g" "$spec_file"
    sed -i "s|__EXTENSION_SUMMARY__|$RPM_SUMMARY|g" "$spec_file"
    sed -i "s|__EXTENSION_LICENSE__|$EXTENSION_LICENSE|g" "$spec_file"
    sed -i "s|__EXTENSION_URL__|$EXTENSION_URL|g" "$spec_file"
    sed -i "s|__EXTENSION_DESCRIPTION__|$EXTENSION_DESCRIPTION|g" "$spec_file"
    sed -i "s|__BUILD_OPTIONS__|$BUILD_OPTIONS|g" "$spec_file"
    sed -i "s|__BUILD_DATE__|$(date '+%a %b %d %Y')|g" "$spec_file"
    
    # 处理系统依赖
    if [ -n "$SYSTEM_DEPS" ]; then
        local buildrequires=""
        local requires=""
        for dep in $SYSTEM_DEPS; do
            buildrequires="${buildrequires}BuildRequires:  $dep\n"
            requires="${requires}Requires:       $dep\n"
        done
        sed -i "s|__SYSTEM_DEPS_BUILDREQUIRES__|$buildrequires|g" "$spec_file"
        sed -i "s|__SYSTEM_DEPS_REQUIRES__|$requires|g" "$spec_file"
    else
        sed -i "s|__SYSTEM_DEPS_BUILDREQUIRES__||g" "$spec_file"
        sed -i "s|__SYSTEM_DEPS_REQUIRES__||g" "$spec_file"
    fi
    
    print_success "RPM规格文件生成完成: $spec_file"
}

# 使用Mock构建RPM包
build_rpm_with_mock() {
    local extension_name="$1"
    local php_version="$2"
    local system="$3"
    local architecture="$4"
    
    local mock_config="../../../mock_configs/${system}-${architecture}.cfg"
    local spec_file="${extension_name}.spec"
    
    if [ ! -f "$mock_config" ]; then
        print_error "Mock配置不存在: $mock_config"
        return 1
    fi
    
    print_build "使用Mock构建RPM包 (架构: $architecture)..."
    
    # 复制源码包到Mock构建目录
    local source_file="${extension_name}-${EXTENSION_VERSION}.tgz"
    cp "../$source_file" .
    
    # 执行Mock构建
    if mock -r "$mock_config" --buildsrpm --spec "$spec_file" --sources . --resultdir "mock-results"; then
        print_success "SRPM构建成功"
        
        # 构建二进制RPM
        local srpm_file=$(find mock-results -name "*.src.rpm" | head -1)
        if [ -n "$srpm_file" ]; then
            if mock -r "$mock_config" --rebuild "$srpm_file" --resultdir "mock-results"; then
                print_success "RPM构建成功"
                
                # 复制构建结果到架构特定目录
                local output_dir="../../../${system}/${architecture}/RPMS"
                mkdir -p "$output_dir"
                cp mock-results/*.rpm "$output_dir/" 2>/dev/null || true
                
                print_success "RPM包已输出到: $output_dir"
            else
                print_error "RPM构建失败"
                return 1
            fi
        else
            print_error "未找到SRPM文件"
            return 1
        fi
    else
        print_error "SRPM构建失败"
        return 1
    fi
}

# 测试扩展功能
test_extension() {
    local extension_name="$1"
    local php_version="$2"
    local architecture="$3"
    
    if [ -z "$extension_name" ] || [ -z "$php_version" ] || [ -z "$architecture" ]; then
        print_error "使用方法: test_extension <扩展名> <PHP版本> <架构>"
        return 1
    fi
    
    local config_file="$PECL_CONFIG_DIR/${extension_name}.conf"
    if [ ! -f "$config_file" ]; then
        print_error "扩展配置不存在: $extension_name"
        return 1
    fi
    
    # 加载扩展配置
    source "$config_file"
    
    print_info "测试扩展: $extension_name for PHP $php_version"
    
    local php_series=$(echo "$php_version" | sed 's/\.//')
    local php_binary="/opt/iipe/php$php_series/bin/php"
    
    if [ ! -f "$php_binary" ]; then
        print_error "PHP $php_version 未安装"
        return 1
    fi
    
    # 执行测试命令
    if [ -n "$TEST_COMMAND" ]; then
        print_info "运行测试命令: $TEST_COMMAND"
        if eval "$TEST_COMMAND"; then
            print_success "扩展测试通过: $extension_name"
        else
            print_error "扩展测试失败: $extension_name"
            return 1
        fi
    else
        print_warning "未定义测试命令，跳过测试"
    fi
}

# 列出已安装扩展
list_installed_extensions() {
    local php_version="${1:-8.1}"
    local php_series=$(echo "$php_version" | sed 's/\.//')
    
    print_info "PHP $php_version 已安装的扩展:"
    echo ""
    
    if [ -d "/opt/iipe/php$php_series/lib/php/extensions" ]; then
        local extension_dir=$(find "/opt/iipe/php$php_series/lib/php/extensions" -type d -name "*" | head -1)
        if [ -n "$extension_dir" ]; then
            for ext_file in "$extension_dir"/*.so; do
                if [ -f "$ext_file" ]; then
                    local ext_name=$(basename "$ext_file" .so)
                    echo "  ✅ $ext_name"
                fi
            done
        else
            print_warning "未找到已安装的扩展"
        fi
    else
        print_warning "PHP $php_version 不存在或未安装"
    fi
    echo ""
}

# 显示扩展状态
show_extension_status() {
    local php_version="${1:-8.1}"
    local architecture="${2:-x86_64}"
    
    print_info "PHP $php_version 扩展状态:"
    echo ""
    
    printf "%-15s %-10s %-10s %-20s %-15s\n" "扩展名" "版本" "状态" "配置文件" "测试结果"
    printf "%-15s %-10s %-10s %-20s %-15s\n" "-----" "----" "----" "--------" "--------"
    
    for config_file in "$PECL_CONFIG_DIR"/*.conf; do
        if [ -f "$config_file" ]; then
            source "$config_file"
            
            local status="未安装"
            local test_result="未测试"
            
            # 检查是否已安装
            local php_series=$(echo "$php_version" | sed 's/\.//')
            local ext_dir="/opt/iipe/php$php_series/lib/php/extensions"
            
            if [ -d "$ext_dir" ]; then
                local extension_file=$(find "$ext_dir" -name "${EXTENSION_NAME}.so" 2>/dev/null | head -1)
                if [ -n "$extension_file" ]; then
                    status="已安装"
                    
                    # 运行测试
                    if [ -n "$TEST_COMMAND" ]; then
                        if eval "$TEST_COMMAND" >/dev/null 2>&1; then
                            test_result="通过"
                        else
                            test_result="失败"
                        fi
                    fi
                fi
            fi
            
            printf "%-15s %-10s %-10s %-20s %-15s\n" \
                "$EXTENSION_NAME" \
                "$EXTENSION_VERSION" \
                "$status" \
                "$(basename "$config_file")" \
                "$test_result"
        fi
    done
    echo ""
}

# 构建所有扩展
build_all_extensions() {
    local php_version="$1"
    local system="$2"
    local architecture="$3"
    local parallel="${4:-1}"
    
    if [ -z "$php_version" ] || [ -z "$system" ] || [ -z "$architecture" ]; then
        print_error "使用方法: build_all_extensions <PHP版本> <系统> <架构> [并行数]"
        return 1
    fi
    
    print_info "开始构建所有扩展 for PHP $php_version on $system (并行: $parallel)"
    
    local extensions=()
    for config_file in "$PECL_CONFIG_DIR"/*.conf; do
        if [ -f "$config_file" ]; then
            local ext_name=$(basename "$config_file" .conf)
            extensions+=("$ext_name")
        fi
    done
    
    if [ ${#extensions[@]} -eq 0 ]; then
        print_warning "没有找到扩展配置"
        return 0
    fi
    
    print_info "找到 ${#extensions[@]} 个扩展: ${extensions[*]}"
    
    # 并行构建
    local pids=()
    local count=0
    
    for extension in "${extensions[@]}"; do
        # 检查并行限制
        if [ ${#pids[@]} -ge "$parallel" ]; then
            # 等待一个进程完成
            wait "${pids[0]}"
            pids=("${pids[@]:1}")
        fi
        
        # 启动构建进程
        (
            build_extension "$extension" "$php_version" "$system" "$architecture" "false"
        ) &
        pids+=($!)
        
        count=$((count + 1))
        print_info "启动构建进程 ($count/${#extensions[@]}): $extension"
    done
    
    # 等待所有进程完成
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    print_success "所有扩展构建完成"
}

# 清理构建缓存
cleanup_build_cache() {
    local days="${1:-7}"
    
    print_info "清理 $days 天前的构建缓存..."
    
    # 清理构建目录
    if [ -d "$PECL_BUILD_DIR" ]; then
        find "$PECL_BUILD_DIR" -type d -mtime +$days -exec rm -rf {} + 2>/dev/null || true
    fi
    
    # 清理缓存目录中的旧文件
    if [ -d "$PECL_CACHE_DIR" ]; then
        find "$PECL_CACHE_DIR" -type f -mtime +$days -delete 2>/dev/null || true
    fi
    
    # 清理日志文件
    if [ -d "$PECL_LOG_DIR" ]; then
        find "$PECL_LOG_DIR" -name "*.log" -mtime +$days -delete 2>/dev/null || true
    fi
    
    print_success "构建缓存清理完成"
}

# 主函数
main() {
    local command=""
    local extension_name=""
    local extension_version=""
    local php_version="8.1"
    local system=""
    local config_file=""
    local force=false
    local dev_mode=false
    local run_test=false
    local output_dir=""
    local with_deps=false
    local parallel="1"
    local architecture="x86_64"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            init|list-extensions|list-installed|install|build|build-all|remove|update|check-deps|test-extension|generate-spec|validate|status|cleanup)
                command="$1"
                shift
                ;;
            -e|--extension)
                extension_name="$2"
                shift 2
                ;;
            -v|--version)
                extension_version="$2"
                shift 2
                ;;
            -p|--php-version)
                php_version="$2"
                shift 2
                ;;
            -s|--system)
                system="$2"
                shift 2
                ;;
            -a|--architecture)
                architecture="$2"
                shift 2
                ;;
            -c|--config)
                config_file="$2"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -d|--dev)
                dev_mode=true
                shift
                ;;
            -t|--test)
                run_test=true
                shift
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            --with-deps)
                with_deps=true
                shift
                ;;
            --parallel)
                parallel="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 执行命令
    case "$command" in
        "init")
            init_pecl_environment
            ;;
        "list-extensions")
            list_available_extensions
            ;;
        "list-installed")
            list_installed_extensions "$php_version"
            ;;
        "install")
            if [ -z "$extension_name" ] || [ -z "$system" ]; then
                print_error "安装扩展需要指定扩展名和系统"
                show_usage
                exit 1
            fi
            install_pecl_extension "$extension_name" "$php_version" "$system" "$architecture" "$force"
            ;;
        "build")
            if [ -z "$extension_name" ] || [ -z "$system" ]; then
                print_error "构建扩展需要指定扩展名和系统"
                show_usage
                exit 1
            fi
            build_extension "$extension_name" "$php_version" "$system" "$architecture" "$force"
            ;;
        "build-all")
            if [ -z "$system" ]; then
                print_error "批量构建需要指定系统"
                show_usage
                exit 1
            fi
            build_all_extensions "$php_version" "$system" "$architecture" "$parallel"
            ;;
        "test-extension")
            if [ -z "$extension_name" ]; then
                print_error "测试扩展需要指定扩展名"
                show_usage
                exit 1
            fi
            test_extension "$extension_name" "$php_version" "$architecture"
            ;;
        "check-deps")
            if [ -z "$extension_name" ]; then
                print_error "检查依赖需要指定扩展名"
                show_usage
                exit 1
            fi
            local config_file="$PECL_CONFIG_DIR/${extension_name}.conf"
            if [ -f "$config_file" ]; then
                source "$config_file"
                print_info "检查扩展 $extension_name 的依赖..."
                if [ -n "$SYSTEM_DEPS" ]; then
                    check_system_dependencies "$SYSTEM_DEPS"
                    print_info "系统依赖检查完成"
                else
                    print_info "该扩展无系统依赖"
                fi
            else
                print_error "扩展配置不存在: $extension_name"
                exit 1
            fi
            ;;
        "generate-spec")
            if [ -z "$extension_name" ] || [ -z "$system" ]; then
                print_error "生成RPM规格文件需要指定扩展名和系统"
                show_usage
                exit 1
            fi
            generate_rpm_spec "$extension_name" "$php_version" "$system" "$architecture"
            ;;
        "validate")
            print_info "验证PECL扩展配置..."
            local validation_errors=0
            for config_file in "$PECL_CONFIG_DIR"/*.conf; do
                if [ -f "$config_file" ]; then
                    local ext_name=$(basename "$config_file" .conf)
                    print_info "验证配置: $ext_name"
                    
                    # 检查必要变量
                    source "$config_file"
                    local required_vars=("EXTENSION_NAME" "EXTENSION_VERSION" "EXTENSION_URL" "EXTENSION_DESCRIPTION")
                    for var in "${required_vars[@]}"; do
                        if [ -z "${!var}" ]; then
                            print_error "配置文件 $config_file 缺少必要变量: $var"
                            ((validation_errors++))
                        fi
                    done
                fi
            done
            
            if [ $validation_errors -eq 0 ]; then
                print_success "所有配置验证通过"
            else
                print_error "发现 $validation_errors 个配置错误"
                exit 1
            fi
            ;;
        "status")
            show_extension_status "$php_version" "$architecture"
            ;;
        "cleanup")
            cleanup_build_cache 7
            ;;
        "")
            # 默认显示可用扩展
            list_available_extensions
            ;;
        *)
            print_error "未知命令: $command"
            show_usage
            exit 1
            ;;
    esac
}

# 脚本入口
main "$@"
