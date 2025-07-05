#!/bin/bash

# iipe PHP 多版本仓库快速启动脚本
# 用于快速设置项目环境并构建第一个 PHP 包

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 打印函数
print_header() {
    echo -e "${PURPLE}=== $1 ===${NC}"
}

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

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# 欢迎信息
show_welcome() {
    clear
    echo -e "${PURPLE}"
    echo "  ┌─────────────────────────────────────────────────────────────┐"
    echo "  │                                                             │"
    echo "  │    🐘 欢迎使用 iipe PHP 多版本仓库快速启动脚本               │"
    echo "  │                                                             │"
    echo "  │    此脚本将帮助您：                                          │"
    echo "  │    ✓ 检查并安装必要的构建依赖                                │"
    echo "  │    ✓ 初始化项目目录结构                                      │"
    echo "  │    ✓ 构建您的第一个 PHP 包                                   │"
    echo "  │    ✓ 创建并发布软件仓库                                      │"
    echo "  │                                                             │"
    echo "  └─────────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
    echo ""
}

# 检查系统兼容性
check_system() {
    print_header "系统兼容性检查"
    
    # 检查操作系统
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        print_info "检测到操作系统: $PRETTY_NAME"
        
        # 判断系统类型
        case "$ID" in
            almalinux|rocky|rhel|centos)
                if [[ "$VERSION_ID" =~ ^(9|10) ]]; then
                    RECOMMENDED_TARGET="${ID}-${VERSION_ID}"
                    print_success "系统兼容 ✓"
                else
                    print_warning "不推荐的系统版本，建议使用 RHEL 9/10 系列"
                    RECOMMENDED_TARGET="almalinux-9"
                fi
                ;;
            openEuler|openeuler)
                RECOMMENDED_TARGET="openeuler-24.03"
                print_success "系统兼容 ✓"
                ;;
            anolis)
                RECOMMENDED_TARGET="openanolis-23"
                print_success "系统兼容 ✓"
                ;;
            opencloudos)
                RECOMMENDED_TARGET="opencloudos-9"
                print_success "系统兼容 ✓"
                ;;
            *)
                print_warning "未明确支持的系统，将使用默认配置"
                RECOMMENDED_TARGET="almalinux-9"
                ;;
        esac
    else
        print_error "无法检测操作系统类型"
        RECOMMENDED_TARGET="almalinux-9"
    fi
    
    print_info "推荐的构建目标: $RECOMMENDED_TARGET"
    echo ""
}

# 检查和安装依赖
check_dependencies() {
    print_header "依赖检查与安装"
    
    local missing_deps=()
    
    # 检查必要的命令
    for cmd in rpm rpmbuild mock createrepo_c; do
        if ! command -v $cmd > /dev/null 2>&1; then
            missing_deps+=($cmd)
        else
            print_success "$cmd 已安装"
        fi
    done
    
    # 检查开发工具
    if ! rpm -q rpm-build > /dev/null 2>&1; then
        missing_deps+=(rpm-build)
    fi
    
    if ! rpm -q mock > /dev/null 2>&1; then
        missing_deps+=(mock)
    fi
    
    if ! rpm -q createrepo_c > /dev/null 2>&1; then
        missing_deps+=(createrepo_c)
    fi
    
    # 安装缺失的依赖
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_warning "发现缺失的依赖: ${missing_deps[*]}"
        print_info "正在安装缺失的依赖..."
        
        if sudo dnf install -y "${missing_deps[@]}"; then
            print_success "依赖安装完成"
        else
            print_error "依赖安装失败，请手动安装: ${missing_deps[*]}"
            exit 1
        fi
    else
        print_success "所有依赖都已满足"
    fi
    
    # 检查 mock 权限
    if ! groups | grep -q mock; then
        print_warning "当前用户不在 mock 组中"
        print_info "正在添加用户到 mock 组..."
        if sudo usermod -a -G mock "$USER"; then
            print_success "用户已添加到 mock 组"
            print_warning "请重新登录或运行: newgrp mock"
        else
            print_error "添加用户到 mock 组失败"
        fi
    else
        print_success "mock 权限检查通过"
    fi
    
    echo ""
}

# 初始化项目
initialize_project() {
    print_header "项目初始化"
    
    # 检查初始化脚本
    if [ ! -f "init-project.sh" ]; then
        print_error "init-project.sh 脚本不存在"
        exit 1
    fi
    
    # 执行初始化
    print_step "执行项目初始化..."
    if chmod +x init-project.sh && ./init-project.sh; then
        print_success "项目初始化完成"
    else
        print_error "项目初始化失败"
        exit 1
    fi
    
    echo ""
}

# 选择构建参数
choose_build_params() {
    print_header "构建参数选择"
    
    # PHP 版本选择
    echo "请选择要构建的 PHP 版本:"
    echo "1) PHP 7.4.33 (EOL 版本，用于遗留应用)"
    echo "2) PHP 8.0.30 (LTS 版本，生产环境)"
    echo "3) PHP 8.1.29 (LTS 版本，生产环境)"
    echo "4) PHP 8.2.25 (稳定版本)"
    echo "5) PHP 8.3.12 (当前稳定版，推荐新项目)"
    echo "6) PHP 8.4.0 (最新稳定版)"
    echo "7) 自定义版本"
    echo ""
    
    while true; do
        read -p "请输入选择 (1-7): " php_choice
        case $php_choice in
            1) PHP_VERSION="7.4.33"; break ;;
            2) PHP_VERSION="8.0.30"; break ;;
            3) PHP_VERSION="8.1.29"; break ;;
            4) PHP_VERSION="8.2.25"; break ;;
            5) PHP_VERSION="8.3.12"; break ;;
            6) PHP_VERSION="8.4.0"; break ;;
            7) 
                read -p "请输入自定义 PHP 版本 (如 8.3.10): " PHP_VERSION
                if [[ ! "$PHP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    print_error "版本格式不正确，请使用 X.Y.Z 格式"
                    continue
                fi
                break
                ;;
            *) print_error "无效选择，请重新输入" ;;
        esac
    done
    
    print_success "已选择 PHP 版本: $PHP_VERSION"
    
    # 目标系统选择
    echo ""
    echo "请选择目标系统:"
    echo "1) 使用推荐系统 ($RECOMMENDED_TARGET)"
    echo "2) AlmaLinux 9"
    echo "3) Rocky Linux 9"
    echo "4) AlmaLinux 10"
    echo "5) Rocky Linux 10"
    echo "6) openEuler 24.03"
    echo "7) openAnolis 23"
    echo "8) OpencloudOS 9"
    echo "9) 自定义"
    echo ""
    
    while true; do
        read -p "请输入选择 (1-9): " system_choice
        case $system_choice in
            1) TARGET_SYSTEM="$RECOMMENDED_TARGET"; break ;;
            2) TARGET_SYSTEM="almalinux-9"; break ;;
            3) TARGET_SYSTEM="rockylinux-9"; break ;;
            4) TARGET_SYSTEM="almalinux-10"; break ;;
            5) TARGET_SYSTEM="rockylinux-10"; break ;;
            6) TARGET_SYSTEM="openeuler-24.03"; break ;;
            7) TARGET_SYSTEM="openanolis-23"; break ;;
            8) TARGET_SYSTEM="opencloudos-9"; break ;;
            9) 
                read -p "请输入自定义目标系统: " TARGET_SYSTEM
                break
                ;;
            *) print_error "无效选择，请重新输入" ;;
        esac
    done
    
    print_success "已选择目标系统: $TARGET_SYSTEM"
    echo ""
}

# 执行构建
perform_build() {
    print_header "开始构建 PHP $PHP_VERSION for $TARGET_SYSTEM"
    
    # 检查构建脚本
    if [ ! -f "build.sh" ]; then
        print_error "build.sh 脚本不存在"
        exit 1
    fi
    
    # 设置权限并执行构建
    print_step "执行构建命令: ./build.sh $PHP_VERSION $TARGET_SYSTEM"
    if chmod +x build.sh && ./build.sh "$PHP_VERSION" "$TARGET_SYSTEM"; then
        print_success "PHP $PHP_VERSION 构建完成"
    else
        print_error "构建失败"
        print_info "常见问题解决方案:"
        print_info "1. 检查网络连接是否正常"
        print_info "2. 确认 mock 权限配置正确"
        print_info "3. 查看构建日志获取详细错误信息"
        exit 1
    fi
    
    echo ""
}

# 发布仓库
publish_repository() {
    print_header "发布软件仓库"
    
    # 检查发布脚本
    if [ ! -f "publish.sh" ]; then
        print_error "publish.sh 脚本不存在"
        exit 1
    fi
    
    # 发布仓库
    print_step "发布仓库: $TARGET_SYSTEM"
    if chmod +x publish.sh && ./publish.sh "$TARGET_SYSTEM"; then
        print_success "仓库发布完成"
    else
        print_error "仓库发布失败"
        exit 1
    fi
    
    echo ""
}

# 显示完成信息
show_completion() {
    print_header "🎉 快速启动完成！"
    
    echo -e "${GREEN}"
    echo "恭喜！您已成功构建并发布了第一个 iipe PHP 仓库。"
    echo -e "${NC}"
    echo ""
    echo "📦 构建结果:"
    echo "  PHP 版本: $PHP_VERSION"
    echo "  目标系统: $TARGET_SYSTEM"
    echo "  构建产物: repo_output/$TARGET_SYSTEM/"
    echo ""
    echo "🚀 下一步操作:"
    echo ""
    echo "1. 查看构建的 RPM 包:"
    echo "   ls -la repo_output/$TARGET_SYSTEM/"
    echo ""
    echo "2. 部署到 Web 服务器:"
    echo "   sudo cp -r repo_output/$TARGET_SYSTEM /var/www/html/"
    echo "   sudo cp docs/iipe.repo /var/www/html/"
    echo ""
    echo "3. 测试安装 (在客户端机器上):"
    echo "   sudo dnf config-manager --add-repo https://your-domain/iipe.repo"
    echo "   sudo dnf install iipe-php$(echo $PHP_VERSION | tr -d '.')"
    echo ""
    echo "4. 启用 SCL 环境:"
    echo "   scl enable iipe-php$(echo $PHP_VERSION | sed 's/\.[0-9]*$//' | tr -d '.') -- php -v"
    echo ""
    echo "📚 更多信息:"
    echo "  详细文档: docs/用户指南.md"
    echo "  Nginx 配置: docs/nginx.conf"
    echo "  项目主页: https://ii.pe/"
    echo ""
    echo -e "${CYAN}感谢使用 iipe PHP 多版本仓库项目！${NC}"
}

# 主函数
main() {
    show_welcome
    
    # 等待用户确认
    read -p "按 Enter 键开始快速启动流程，或 Ctrl+C 退出..."
    echo ""
    
    # 执行启动流程
    check_system
    check_dependencies
    initialize_project
    choose_build_params
    perform_build
    publish_repository
    show_completion
}

# 脚本入口
main "$@" 