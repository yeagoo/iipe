#!/bin/bash

# =============================================================================
# iipe PHP Docker 构建脚本
# 
# 功能：
# - 简化Docker环境使用
# - 容器化构建流程
# - 多环境支持
# =============================================================================

set -euo pipefail

SCRIPT_NAME="iipe PHP Docker Build"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 默认配置
DEFAULT_PHP_VERSIONS="8.2,8.3"
DEFAULT_SYSTEMS="almalinux-9,rocky-linux-9"
DEFAULT_IMAGE_NAME="iipe-php-builder"
DEFAULT_CONTAINER_NAME="iipe-php-builder"

# 颜色定义
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_NC='\033[0m'

# 日志函数
log_info() { echo -e "[$(date '+%H:%M:%S')] ${COLOR_BLUE}[INFO]${COLOR_NC} $*"; }
log_warn() { echo -e "[$(date '+%H:%M:%S')] ${COLOR_YELLOW}[WARN]${COLOR_NC} $*"; }
log_error() { echo -e "[$(date '+%H:%M:%S')] ${COLOR_RED}[ERROR]${COLOR_NC} $*"; }
log_success() { echo -e "[$(date '+%H:%M:%S')] ${COLOR_GREEN}[SUCCESS]${COLOR_NC} $*"; }

show_usage() {
    cat << EOF
${COLOR_BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${COLOR_NC}

用法: $0 [命令] [选项]

命令:
    build-image           构建Docker镜像
    start                 启动构建环境
    stop                  停止构建环境
    restart               重启构建环境
    shell                 进入构建环境Shell
    build-php             在容器中构建PHP
    test-php              在容器中测试PHP
    clean                 清理Docker资源
    logs                  查看容器日志
    status                查看服务状态

选项:
    -v, --versions VER1,VER2,...    指定PHP版本 (默认: $DEFAULT_PHP_VERSIONS)
    -s, --systems SYS1,SYS2,...     指定系统 (默认: $DEFAULT_SYSTEMS)
    -j, --jobs NUMBER                并行任务数 (默认: 4)
    -f, --force                      强制操作，不询问确认
    -d, --detach                     后台运行
    --no-cache                       构建时不使用缓存
    -h, --help                       显示此帮助信息

示例:
    # 构建Docker镜像
    $0 build-image

    # 启动环境并构建PHP 8.3
    $0 start
    $0 build-php -v 8.3 -s almalinux-9

    # 进入容器Shell
    $0 shell

    # 清理所有资源
    $0 clean -f

EOF
}

# 检查Docker是否可用
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装或不在PATH中"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker守护进程未运行或无权限访问"
        exit 1
    fi
}

# 检查docker-compose是否可用
check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        log_error "docker-compose未安装"
        exit 1
    fi
}

# 构建Docker镜像
build_image() {
    local no_cache=""
    
    if [[ "${NO_CACHE:-}" == "true" ]]; then
        no_cache="--no-cache"
    fi
    
    log_info "构建Docker镜像: $DEFAULT_IMAGE_NAME"
    
    docker build $no_cache \
        -f docker/Dockerfile.builder \
        -t "$DEFAULT_IMAGE_NAME:latest" \
        --build-arg BUILD_UID="$(id -u)" \
        --build-arg BUILD_GID="$(id -g)" \
        .
    
    log_success "Docker镜像构建完成"
}

# 启动构建环境
start_environment() {
    log_info "启动构建环境..."
    
    check_docker_compose
    
    # 确保镜像存在
    if ! docker image inspect "$DEFAULT_IMAGE_NAME:latest" &> /dev/null; then
        log_warn "Docker镜像不存在，开始构建..."
        build_image
    fi
    
    if [[ "${DETACH:-}" == "true" ]]; then
        $COMPOSE_CMD up -d builder
    else
        $COMPOSE_CMD up builder
    fi
    
    log_success "构建环境已启动"
}

# 停止构建环境
stop_environment() {
    log_info "停止构建环境..."
    
    check_docker_compose
    $COMPOSE_CMD down
    
    log_success "构建环境已停止"
}

# 重启构建环境
restart_environment() {
    log_info "重启构建环境..."
    
    stop_environment
    start_environment
}

# 进入容器Shell
enter_shell() {
    log_info "进入构建环境Shell..."
    
    if ! docker ps --format '{{.Names}}' | grep -q "^$DEFAULT_CONTAINER_NAME$"; then
        log_error "构建容器未运行，请先启动环境"
        exit 1
    fi
    
    docker exec -it "$DEFAULT_CONTAINER_NAME" /bin/bash
}

# 在容器中构建PHP
build_php_in_container() {
    local php_versions="${PHP_VERSIONS:-$DEFAULT_PHP_VERSIONS}"
    local systems="${SYSTEMS:-$DEFAULT_SYSTEMS}"
    local jobs="${PARALLEL_JOBS:-4}"
    
    log_info "在容器中构建PHP..."
    log_info "PHP版本: $php_versions"
    log_info "目标系统: $systems"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^$DEFAULT_CONTAINER_NAME$"; then
        log_error "构建容器未运行，请先启动环境"
        exit 1
    fi
    
    docker exec "$DEFAULT_CONTAINER_NAME" \
        ./batch-build.sh -v "$php_versions" -s "$systems" -j "$jobs"
    
    log_success "PHP构建完成"
}

# 在容器中测试PHP
test_php_in_container() {
    local php_versions="${PHP_VERSIONS:-$DEFAULT_PHP_VERSIONS}"
    local systems="${SYSTEMS:-$DEFAULT_SYSTEMS}"
    
    log_info "在容器中测试PHP..."
    
    if ! docker ps --format '{{.Names}}' | grep -q "^$DEFAULT_CONTAINER_NAME$"; then
        log_error "构建容器未运行，请先启动环境"
        exit 1
    fi
    
    # 分别测试每个版本和系统组合
    IFS=',' read -ra version_array <<< "$php_versions"
    IFS=',' read -ra system_array <<< "$systems"
    
    for version in "${version_array[@]}"; do
        for system in "${system_array[@]}"; do
            log_info "测试 PHP $version on $system"
            docker exec "$DEFAULT_CONTAINER_NAME" \
                ./test-builds.sh -v "$version" -s "$system" -t basic
        done
    done
    
    log_success "PHP测试完成"
}

# 查看容器日志
show_logs() {
    local service="${1:-builder}"
    
    check_docker_compose
    $COMPOSE_CMD logs -f "$service"
}

# 查看服务状态
show_status() {
    log_info "Docker服务状态:"
    echo
    
    check_docker_compose
    $COMPOSE_CMD ps
    
    echo
    log_info "Docker镜像:"
    docker images | grep -E "(iipe|php)" || echo "未找到相关镜像"
    
    echo
    log_info "Docker卷:"
    docker volume ls | grep -E "(iipe|builder)" || echo "未找到相关卷"
}

# 清理Docker资源
clean_resources() {
    if [[ "${FORCE:-}" != "true" ]]; then
        echo -n "确定要清理所有Docker资源吗? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "取消清理操作"
            return 0
        fi
    fi
    
    log_info "清理Docker资源..."
    
    check_docker_compose
    
    # 停止并删除容器
    $COMPOSE_CMD down -v --remove-orphans 2>/dev/null || true
    
    # 删除镜像
    docker rmi "$DEFAULT_IMAGE_NAME:latest" 2>/dev/null || true
    
    # 清理未使用的资源
    docker system prune -f
    
    log_success "Docker资源清理完成"
}

# 主函数
main() {
    local command=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            build-image|start|stop|restart|shell|build-php|test-php|clean|logs|status)
                command="$1"
                shift
                ;;
            -v|--versions)
                PHP_VERSIONS="$2"
                shift 2
                ;;
            -s|--systems)
                SYSTEMS="$2"
                shift 2
                ;;
            -j|--jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            -f|--force)
                FORCE="true"
                shift
                ;;
            -d|--detach)
                DETACH="true"
                shift
                ;;
            --no-cache)
                NO_CACHE="true"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 检查Docker环境
    check_docker
    
    # 执行命令
    case "$command" in
        build-image)
            build_image
            ;;
        start)
            start_environment
            ;;
        stop)
            stop_environment
            ;;
        restart)
            restart_environment
            ;;
        shell)
            enter_shell
            ;;
        build-php)
            build_php_in_container
            ;;
        test-php)
            test_php_in_container
            ;;
        clean)
            clean_resources
            ;;
        logs)
            show_logs "${2:-builder}"
            ;;
        status)
            show_status
            ;;
        "")
            log_error "请指定一个命令"
            show_usage
            exit 1
            ;;
        *)
            log_error "未知命令: $command"
            show_usage
            exit 1
            ;;
    esac
}

main "$@" 