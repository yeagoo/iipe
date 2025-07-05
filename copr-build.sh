#!/bin/bash
# Copr构建脚本 - iipe PHP Multi-Version Repository
# 支持自动化Copr项目创建、构建和管理

set -euo pipefail

# 脚本信息
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_VERSION="1.0.0"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 配置变量
COPR_USER="${COPR_USER:-}"
COPR_PROJECT="${COPR_PROJECT:-iipe-php}"
COPR_DESCRIPTION="iipe PHP Multi-Version Enterprise Repository"
GIT_URL="${GIT_URL:-https://github.com/yourusername/iipe.git}"
GIT_BRANCH="${GIT_BRANCH:-main}"

# PHP版本配置
PHP_VERSIONS=(7.4 8.0 8.1 8.2 8.3 8.4)
DEFAULT_PHP_VERSION="8.1"

# 支持的系统和架构
SUPPORTED_CHROOTS=(
    "epel-9-x86_64"
    "epel-9-aarch64"
    "epel-10-x86_64" 
    "epel-10-aarch64"
    "centos-stream-9-x86_64"
    "centos-stream-9-aarch64"
    "centos-stream-10-x86_64"
    "centos-stream-10-aarch64"
    "fedora-39-x86_64"
    "fedora-39-aarch64"
    "fedora-40-x86_64"
    "fedora-40-aarch64"
)

# 日志功能
log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $*"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
${WHITE}iipe PHP Multi-Version Copr构建脚本${NC}

${CYAN}用法:${NC}
    $SCRIPT_NAME [选项] <命令> [参数...]

${CYAN}命令:${NC}
    setup              - 设置Copr配置和认证
    create-project     - 创建Copr项目
    build              - 构建PHP包
    build-all          - 构建所有PHP版本
    list-builds        - 列出构建状态
    watch              - 监控构建进度
    download           - 下载构建结果
    clean              - 清理Copr项目
    status             - 显示项目状态
    help               - 显示此帮助信息

${CYAN}选项:${NC}
    -u, --user USER           Copr用户名
    -p, --project PROJECT     Copr项目名 (默认: $COPR_PROJECT)
    -v, --php-version VERSION PHP版本 (默认: $DEFAULT_PHP_VERSION)
    -c, --chroots CHROOTS     指定构建目标 (逗号分隔)
    -g, --git-url URL         Git仓库URL
    -b, --git-branch BRANCH   Git分支 (默认: $GIT_BRANCH)
    -f, --force               强制执行操作
    -d, --debug               启用调试模式
    -h, --help                显示帮助信息

${CYAN}示例:${NC}
    # 设置Copr配置
    $SCRIPT_NAME setup

    # 创建项目
    $SCRIPT_NAME -u myuser create-project

    # 构建PHP 8.1
    $SCRIPT_NAME -u myuser -v 8.1 build

    # 构建所有PHP版本
    $SCRIPT_NAME -u myuser build-all

    # 监控构建进度
    $SCRIPT_NAME -u myuser watch

    # 构建特定架构
    $SCRIPT_NAME -u myuser -v 8.2 -c "epel-9-x86_64,epel-9-aarch64" build

${CYAN}环境变量:${NC}
    COPR_USER          - Copr用户名
    COPR_PROJECT       - Copr项目名
    GIT_URL            - Git仓库URL
    GIT_BRANCH         - Git分支
    DEBUG              - 启用调试模式

${CYAN}依赖要求:${NC}
    - copr-cli         - Copr命令行工具
    - git              - Git版本控制
    - tar              - 打包工具
    - rpmbuild         - RPM构建工具

EOF
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖工具..."
    
    local missing_deps=()
    
    # 检查必要工具
    for cmd in copr-cli git tar rpmbuild; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少必要依赖: ${missing_deps[*]}"
        log_info "请安装缺少的依赖:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                copr-cli)
                    echo "  dnf install copr-cli"
                    ;;
                git)
                    echo "  dnf install git"
                    ;;
                tar)
                    echo "  dnf install tar"
                    ;;
                rpmbuild)
                    echo "  dnf install rpm-build rpmdevtools"
                    ;;
            esac
        done
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 设置Copr配置
setup_copr() {
    log_info "设置Copr配置..."
    
    # 检查Copr配置
    if [[ ! -f ~/.config/copr ]]; then
        log_warning "Copr配置文件不存在"
        log_info "请执行以下步骤设置Copr认证:"
        echo "1. 访问 https://copr.fedorainfracloud.org/api/"
        echo "2. 登录并获取API令牌"
        echo "3. 创建 ~/.config/copr 文件并添加配置"
        echo ""
        echo "配置文件示例:"
        echo "[copr-cli]"
        echo "login = your-username"
        echo "username = your-username"  
        echo "token = your-api-token"
        echo "copr_url = https://copr.fedorainfracloud.org"
        echo ""
        read -p "是否现在设置配置? (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_copr_config
        else
            exit 1
        fi
    fi
    
    # 验证配置
    if copr-cli whoami &> /dev/null; then
        local username
        username=$(copr-cli whoami)
        log_success "Copr配置有效，用户: $username"
        COPR_USER="${COPR_USER:-$username}"
    else
        log_error "Copr配置无效，请重新设置"
        exit 1
    fi
}

# 设置Copr配置文件
setup_copr_config() {
    log_info "设置Copr配置文件..."
    
    mkdir -p ~/.config
    
    echo "请输入Copr配置信息:"
    read -p "用户名: " -r copr_username
    read -p "API令牌: " -r copr_token
    
    cat > ~/.config/copr << EOF
[copr-cli]
login = $copr_username
username = $copr_username
token = $copr_token
copr_url = https://copr.fedorainfracloud.org
EOF
    
    chmod 600 ~/.config/copr
    log_success "Copr配置文件创建完成"
}

# 创建Copr项目
create_copr_project() {
    log_info "创建Copr项目: $COPR_USER/$COPR_PROJECT"
    
    # 检查项目是否已存在
    if copr-cli list "$COPR_USER" | grep -q "$COPR_PROJECT"; then
        if [[ "${FORCE:-false}" == "true" ]]; then
            log_warning "项目已存在，强制删除并重新创建..."
            copr-cli delete "$COPR_USER/$COPR_PROJECT" || true
        else
            log_warning "项目已存在: $COPR_USER/$COPR_PROJECT"
            read -p "是否删除并重新创建? (y/n): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                copr-cli delete "$COPR_USER/$COPR_PROJECT" || true
            else
                log_info "使用现有项目"
                return 0
            fi
        fi
    fi
    
    # 创建项目
    local chroot_args=""
    for chroot in "${SUPPORTED_CHROOTS[@]}"; do
        chroot_args+=" --chroot $chroot"
    done
    
    log_info "创建新项目..."
    copr-cli create "$COPR_PROJECT" \
        --description "$COPR_DESCRIPTION" \
        --instructions "$(cat copr-configs/iipe-php.yml | grep -A 50 "instructions:" | tail -n +2)" \
        $chroot_args \
        --enable-net=on \
        --unlisted-on-hp=off
    
    log_success "Copr项目创建完成: $COPR_USER/$COPR_PROJECT"
}

# 构建PHP包
build_php_package() {
    local php_version="$1"
    local chroots="${2:-}"
    
    log_info "构建PHP $php_version 包..."
    
    # 验证PHP版本
    if [[ ! " ${PHP_VERSIONS[*]} " =~ " $php_version " ]]; then
        log_error "不支持的PHP版本: $php_version"
        log_info "支持的版本: ${PHP_VERSIONS[*]}"
        exit 1
    fi
    
    # 准备构建参数
    local build_args=""
    if [[ -n "$chroots" ]]; then
        IFS=',' read -ra CHROOT_ARRAY <<< "$chroots"
        for chroot in "${CHROOT_ARRAY[@]}"; do
            build_args+=" --chroot $chroot"
        done
    fi
    
    # 执行构建
    log_info "提交构建任务..."
    local build_id
    build_id=$(copr-cli build "$COPR_USER/$COPR_PROJECT" \
        --git-url "$GIT_URL" \
        --git-branch "$GIT_BRANCH" \
        --git-dir "." \
        $build_args \
        2>&1 | grep -o 'Build [0-9]*' | cut -d' ' -f2)
    
    if [[ -n "$build_id" ]]; then
        log_success "构建任务已提交: Build #$build_id"
        log_info "监控地址: https://copr.fedorainfracloud.org/coprs/$COPR_USER/$COPR_PROJECT/build/$build_id/"
        
        # 询问是否监控构建
        read -p "是否监控构建进度? (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            watch_build "$build_id"
        fi
    else
        log_error "构建提交失败"
        exit 1
    fi
}

# 构建所有PHP版本
build_all_php_versions() {
    local chroots="${1:-}"
    
    log_info "构建所有PHP版本: ${PHP_VERSIONS[*]}"
    
    local build_ids=()
    
    for version in "${PHP_VERSIONS[@]}"; do
        log_info "提交PHP $version 构建..."
        
        local build_id
        build_id=$(copr-cli build "$COPR_USER/$COPR_PROJECT" \
            --git-url "$GIT_URL" \
            --git-branch "$GIT_BRANCH" \
            --git-dir "." \
            ${chroots:+$(echo "$chroots" | sed 's/,/ --chroot /g' | sed 's/^/--chroot /')} \
            2>&1 | grep -o 'Build [0-9]*' | cut -d' ' -f2) || true
            
        if [[ -n "$build_id" ]]; then
            build_ids+=("$build_id")
            log_success "PHP $version 构建已提交: Build #$build_id"
        else
            log_error "PHP $version 构建提交失败"
        fi
        
        # 避免过于频繁的请求
        sleep 2
    done
    
    if [[ ${#build_ids[@]} -gt 0 ]]; then
        log_success "所有构建任务已提交: ${build_ids[*]}"
        log_info "项目页面: https://copr.fedorainfracloud.org/coprs/$COPR_USER/$COPR_PROJECT/"
        
        # 询问是否监控所有构建
        read -p "是否监控所有构建进度? (y/n): " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for build_id in "${build_ids[@]}"; do
                echo "监控 Build #$build_id..."
                watch_build "$build_id" &
            done
            wait
        fi
    else
        log_error "没有成功提交的构建任务"
        exit 1
    fi
}

# 监控构建进度
watch_build() {
    local build_id="${1:-}"
    
    if [[ -z "$build_id" ]]; then
        # 获取最新的构建ID
        log_info "获取最新构建信息..."
        build_id=$(copr-cli list-builds "$COPR_USER/$COPR_PROJECT" | head -n 2 | tail -n 1 | awk '{print $1}')
    fi
    
    if [[ -z "$build_id" ]]; then
        log_error "未找到构建ID"
        exit 1
    fi
    
    log_info "监控构建进度: Build #$build_id"
    
    local status="unknown"
    local start_time=$(date +%s)
    
    while true; do
        # 获取构建状态
        local build_info
        build_info=$(copr-cli get-build "$build_id" 2>/dev/null || echo "")
        
        if [[ -n "$build_info" ]]; then
            status=$(echo "$build_info" | grep "state" | awk '{print $2}')
            
            case $status in
                "succeeded")
                    log_success "构建成功完成: Build #$build_id"
                    break
                    ;;
                "failed")
                    log_error "构建失败: Build #$build_id"
                    break
                    ;;
                "cancelled")
                    log_warning "构建已取消: Build #$build_id"
                    break
                    ;;
                "running"|"pending")
                    local elapsed=$(($(date +%s) - start_time))
                    local elapsed_str=$(date -u -d @$elapsed +'%H:%M:%S')
                    echo -ne "\r${YELLOW}[BUILDING]${NC} Build #$build_id 状态: $status (已用时: $elapsed_str)"
                    ;;
                *)
                    echo -ne "\r${BLUE}[UNKNOWN]${NC} Build #$build_id 状态: $status"
                    ;;
            esac
        else
            log_error "无法获取构建信息: Build #$build_id"
            break
        fi
        
        sleep 10
    done
    
    echo # 换行
    
    # 显示构建结果详情
    if [[ "$status" == "succeeded" ]]; then
        log_info "构建结果："
        copr-cli get-build "$build_id" | grep -E "(state|submitted_on|ended_on)"
    fi
}

# 列出构建状态
list_builds() {
    log_info "获取构建列表: $COPR_USER/$COPR_PROJECT"
    
    copr-cli list-builds "$COPR_USER/$COPR_PROJECT" | head -20
}

# 下载构建结果
download_builds() {
    local build_id="${1:-}"
    local output_dir="${2:-./copr-downloads}"
    
    log_info "下载构建结果..."
    
    if [[ -z "$build_id" ]]; then
        # 获取最新成功的构建
        build_id=$(copr-cli list-builds "$COPR_USER/$COPR_PROJECT" | grep "succeeded" | head -1 | awk '{print $1}')
    fi
    
    if [[ -z "$build_id" ]]; then
        log_error "未找到可下载的构建"
        exit 1
    fi
    
    mkdir -p "$output_dir"
    
    log_info "下载Build #$build_id 到 $output_dir"
    
    # 这里需要使用copr-cli的下载功能（如果可用）
    # 或者手动构建下载URL
    local project_url="https://download.copr.fedorainfracloud.org/results/$COPR_USER/$COPR_PROJECT"
    
    log_info "构建结果可在以下地址下载:"
    echo "$project_url"
    
    # 可以添加具体的下载逻辑
}

# 清理Copr项目
clean_copr_project() {
    log_warning "清理Copr项目: $COPR_USER/$COPR_PROJECT"
    
    if [[ "${FORCE:-false}" != "true" ]]; then
        read -p "确定要删除项目及所有构建吗? (y/n): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "操作已取消"
            return 0
        fi
    fi
    
    log_info "删除项目..."
    copr-cli delete "$COPR_USER/$COPR_PROJECT"
    
    log_success "项目已删除"
}

# 显示项目状态
show_status() {
    log_info "项目状态: $COPR_USER/$COPR_PROJECT"
    
    # 项目信息
    echo -e "\n${CYAN}项目信息:${NC}"
    copr-cli get-project "$COPR_USER/$COPR_PROJECT" 2>/dev/null || {
        log_error "项目不存在: $COPR_USER/$COPR_PROJECT"
        return 1
    }
    
    # 最近的构建
    echo -e "\n${CYAN}最近构建:${NC}"
    copr-cli list-builds "$COPR_USER/$COPR_PROJECT" | head -10
    
    # 仓库信息
    echo -e "\n${CYAN}仓库地址:${NC}"
    echo "https://download.copr.fedorainfracloud.org/results/$COPR_USER/$COPR_PROJECT"
    
    echo -e "\n${CYAN}项目页面:${NC}"
    echo "https://copr.fedorainfracloud.org/coprs/$COPR_USER/$COPR_PROJECT/"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--user)
                COPR_USER="$2"
                shift 2
                ;;
            -p|--project)
                COPR_PROJECT="$2"
                shift 2
                ;;
            -v|--php-version)
                PHP_VERSION="$2"
                shift 2
                ;;
            -c|--chroots)
                CHROOTS="$2"
                shift 2
                ;;
            -g|--git-url)
                GIT_URL="$2"
                shift 2
                ;;
            -b|--git-branch)
                GIT_BRANCH="$2"
                shift 2
                ;;
            -f|--force)
                FORCE="true"
                shift
                ;;
            -d|--debug)
                DEBUG="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                COMMAND="$1"
                shift
                ARGS=("$@")
                break
                ;;
        esac
    done
}

# 主函数
main() {
    log_info "iipe PHP Multi-Version Copr构建脚本 v$SCRIPT_VERSION"
    
    # 解析命令行参数
    parse_args "$@"
    
    # 检查命令
    if [[ -z "${COMMAND:-}" ]]; then
        log_error "缺少命令"
        show_help
        exit 1
    fi
    
    # 检查依赖（除了help和setup命令）
    if [[ "$COMMAND" != "help" && "$COMMAND" != "setup" ]]; then
        check_dependencies
    fi
    
    # 执行命令
    case "$COMMAND" in
        setup)
            setup_copr
            ;;
        create-project)
            if [[ -z "$COPR_USER" ]]; then
                log_error "缺少用户名，请使用 -u 选项或设置 COPR_USER 环境变量"
                exit 1
            fi
            setup_copr
            create_copr_project
            ;;
        build)
            if [[ -z "$COPR_USER" ]]; then
                log_error "缺少用户名，请使用 -u 选项或设置 COPR_USER 环境变量"
                exit 1
            fi
            PHP_VERSION="${PHP_VERSION:-$DEFAULT_PHP_VERSION}"
            setup_copr
            build_php_package "$PHP_VERSION" "${CHROOTS:-}"
            ;;
        build-all)
            if [[ -z "$COPR_USER" ]]; then
                log_error "缺少用户名，请使用 -u 选项或设置 COPR_USER 环境变量"
                exit 1
            fi
            setup_copr
            build_all_php_versions "${CHROOTS:-}"
            ;;
        list-builds)
            if [[ -z "$COPR_USER" ]]; then
                log_error "缺少用户名，请使用 -u 选项或设置 COPR_USER 环境变量"
                exit 1
            fi
            setup_copr
            list_builds
            ;;
        watch)
            if [[ -z "$COPR_USER" ]]; then
                log_error "缺少用户名，请使用 -u 选项或设置 COPR_USER 环境变量"
                exit 1
            fi
            setup_copr
            watch_build "${ARGS[0]:-}"
            ;;
        download)
            if [[ -z "$COPR_USER" ]]; then
                log_error "缺少用户名，请使用 -u 选项或设置 COPR_USER 环境变量"
                exit 1
            fi
            setup_copr
            download_builds "${ARGS[0]:-}" "${ARGS[1]:-}"
            ;;
        clean)
            if [[ -z "$COPR_USER" ]]; then
                log_error "缺少用户名，请使用 -u 选项或设置 COPR_USER 环境变量"
                exit 1
            fi
            setup_copr
            clean_copr_project
            ;;
        status)
            if [[ -z "$COPR_USER" ]]; then
                log_error "缺少用户名，请使用 -u 选项或设置 COPR_USER 环境变量"
                exit 1
            fi
            setup_copr
            show_status
            ;;
        help)
            show_help
            ;;
        *)
            log_error "未知命令: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@" 