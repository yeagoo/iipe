#!/bin/bash
# Copr快速开始脚本 - iipe PHP Multi-Version Repository
# 一键设置和开始使用Copr构建

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
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 显示欢迎信息
show_welcome() {
    echo -e "${WHITE}"
    echo "========================================"
    echo "  iipe PHP Multi-Version Copr快速开始"
    echo "========================================"
    echo -e "${NC}"
    echo "这个脚本将帮助您："
    echo "  1. 安装必要的依赖工具"
    echo "  2. 设置Copr认证配置"
    echo "  3. 创建Copr项目"
    echo "  4. 执行首次构建测试"
    echo ""
}

# 日志函数
log_info() { echo -e "${CYAN}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
    else
        log_error "无法检测操作系统"
        exit 1
    fi
    
    log_info "检测到操作系统: $PRETTY_NAME"
}

# 安装依赖工具
install_dependencies() {
    log_info "安装Copr依赖工具..."
    
    case "$OS_ID" in
        "rhel"|"centos"|"almalinux"|"rocky")
            # RHEL系列
            sudo dnf install -y epel-release
            sudo dnf install -y copr-cli git rpm-build rpmdevtools tar gzip sed
            ;;
        "fedora")
            # Fedora
            sudo dnf install -y copr-cli git rpm-build rpmdevtools tar gzip sed
            ;;
        "ubuntu"|"debian")
            # Ubuntu/Debian
            sudo apt-get update
            sudo apt-get install -y python3-pip git rpm tar gzip sed
            pip3 install copr-cli
            ;;
        *)
            log_warning "未知操作系统，尝试通用安装方法..."
            if command -v dnf &> /dev/null; then
                sudo dnf install -y copr-cli git rpm-build rpmdevtools
            elif command -v apt-get &> /dev/null; then
                sudo apt-get update
                sudo apt-get install -y python3-pip git rpm
                pip3 install copr-cli
            else
                log_error "无法安装依赖，请手动安装copr-cli"
                exit 1
            fi
            ;;
    esac
    
    log_success "依赖工具安装完成"
}

# 设置Copr认证
setup_copr_auth() {
    log_info "设置Copr认证..."
    
    # 检查是否已有配置
    if [ -f ~/.config/copr ]; then
        log_warning "Copr配置文件已存在"
        read -p "是否重新配置? (y/n): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    echo ""
    log_info "请按照以下步骤获取Copr API配置:"
    echo "1. 打开浏览器访问: https://copr.fedorainfracloud.org/api/"
    echo "2. 使用GitHub、Google或FAS账号登录"
    echo "3. 复制显示的配置信息"
    echo ""
    
    read -p "按回车键继续..."
    
    echo ""
    echo "请输入Copr配置信息:"
    read -p "用户名 (username): " copr_username
    read -p "登录名 (login): " copr_login
    read -p "API令牌 (token): " copr_token
    
    # 创建配置文件
    mkdir -p ~/.config
    cat > ~/.config/copr << EOF
[copr-cli]
login = $copr_login
username = $copr_username
token = $copr_token
copr_url = https://copr.fedorainfracloud.org
EOF
    
    chmod 600 ~/.config/copr
    
    # 验证配置
    if copr-cli whoami &> /dev/null; then
        local username
        username=$(copr-cli whoami)
        log_success "Copr认证设置成功，用户: $username"
        COPR_USER="$username"
    else
        log_error "Copr认证配置失败，请检查配置信息"
        exit 1
    fi
}

# 验证项目环境
verify_project() {
    log_info "验证项目环境..."
    
    # 检查必要文件
    local required_files=(
        ".copr/Makefile"
        "copr-specs/iipe-php.spec.template"
        "copr-build.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "缺少必要文件: $file"
            exit 1
        fi
    done
    
    # 检查脚本权限
    if [ ! -x "copr-build.sh" ]; then
        chmod +x copr-build.sh
        log_info "已设置copr-build.sh可执行权限"
    fi
    
    # 验证Makefile语法
    if cd .copr && make -n help &> /dev/null; then
        log_success "Makefile语法验证通过"
        cd ..
    else
        log_error "Makefile语法错误"
        cd ..
        exit 1
    fi
    
    log_success "项目环境验证通过"
}

# 创建Copr项目
create_copr_project() {
    log_info "创建Copr项目..."
    
    local project_name="iipe-php"
    
    # 检查项目是否已存在
    if copr-cli list "$COPR_USER" | grep -q "$project_name"; then
        log_warning "Copr项目已存在: $COPR_USER/$project_name"
        read -p "是否继续使用现有项目? (y/n): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "脚本已终止"
            exit 0
        fi
    else
        # 创建新项目
        log_info "创建新的Copr项目: $project_name"
        ./copr-build.sh -u "$COPR_USER" create-project
        log_success "Copr项目创建成功"
    fi
    
    # 显示项目信息
    echo ""
    log_info "项目信息:"
    echo "  项目名称: $COPR_USER/$project_name"
    echo "  项目地址: https://copr.fedorainfracloud.org/coprs/$COPR_USER/$project_name/"
    echo "  仓库地址: https://download.copr.fedorainfracloud.org/results/$COPR_USER/$project_name/"
}

# 执行测试构建
test_build() {
    log_info "执行测试构建..."
    
    echo ""
    echo "选择测试构建选项:"
    echo "1. 构建单个PHP版本 (PHP 8.1)"
    echo "2. 构建多个PHP版本 (PHP 8.1, 8.2)"
    echo "3. 跳过测试构建"
    echo ""
    
    read -p "请选择 (1-3): " choice
    
    case $choice in
        1)
            log_info "构建PHP 8.1..."
            ./copr-build.sh -u "$COPR_USER" -v 8.1 -c "epel-9-x86_64" build
            ;;
        2)
            log_info "构建PHP 8.1和8.2..."
            ./copr-build.sh -u "$COPR_USER" -v 8.1 -c "epel-9-x86_64" build &
            ./copr-build.sh -u "$COPR_USER" -v 8.2 -c "epel-9-x86_64" build &
            wait
            ;;
        3)
            log_info "跳过测试构建"
            return 0
            ;;
        *)
            log_warning "无效选择，跳过测试构建"
            return 0
            ;;
    esac
    
    log_success "测试构建已提交"
}

# 显示完成信息
show_completion() {
    echo ""
    echo -e "${GREEN}========================================"
    echo "  Copr快速开始设置完成!"
    echo -e "========================================${NC}"
    echo ""
    echo "现在您可以:"
    echo ""
    echo -e "${CYAN}1. 查看项目状态:${NC}"
    echo "   ./copr-build.sh -u $COPR_USER status"
    echo ""
    echo -e "${CYAN}2. 构建PHP包:${NC}"
    echo "   ./copr-build.sh -u $COPR_USER -v 8.1 build"
    echo ""
    echo -e "${CYAN}3. 批量构建:${NC}"
    echo "   ./copr-build.sh -u $COPR_USER build-all"
    echo ""
    echo -e "${CYAN}4. 监控构建:${NC}"
    echo "   ./copr-build.sh -u $COPR_USER list-builds"
    echo ""
    echo -e "${CYAN}5. 查看帮助:${NC}"
    echo "   ./copr-build.sh --help"
    echo ""
    echo -e "${CYAN}项目地址:${NC}"
    echo "   https://copr.fedorainfracloud.org/coprs/$COPR_USER/iipe-php/"
    echo ""
    echo -e "${CYAN}详细文档:${NC}"
    echo "   docs/Copr使用指南.md"
    echo ""
}

# 错误处理
handle_error() {
    local exit_code=$?
    log_error "脚本执行失败 (退出码: $exit_code)"
    echo ""
    echo "可能的解决方案:"
    echo "1. 检查网络连接"
    echo "2. 验证Copr认证信息"
    echo "3. 查看详细错误信息"
    echo "4. 参考文档: docs/Copr使用指南.md"
    echo ""
    exit $exit_code
}

# 主函数
main() {
    # 设置错误处理
    trap handle_error ERR
    
    # 显示欢迎信息
    show_welcome
    
    # 检查是否在项目根目录
    if [ ! -f "copr-build.sh" ]; then
        log_error "请在iipe项目根目录中运行此脚本"
        exit 1
    fi
    
    # 询问是否继续
    read -p "是否继续设置Copr集成? (y/n): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "设置已取消"
        exit 0
    fi
    
    echo ""
    
    # 执行设置步骤
    detect_os
    install_dependencies
    setup_copr_auth
    verify_project
    create_copr_project
    test_build
    show_completion
}

# 显示帮助信息
show_help() {
    cat << EOF
${WHITE}iipe PHP Multi-Version Copr快速开始脚本${NC}

${CYAN}用法:${NC}
    $SCRIPT_NAME [选项]

${CYAN}选项:${NC}
    -h, --help    显示帮助信息
    --version     显示版本信息

${CYAN}功能:${NC}
    1. 自动检测操作系统并安装依赖
    2. 引导设置Copr认证配置
    3. 验证项目环境和配置
    4. 创建Copr项目
    5. 执行测试构建

${CYAN}要求:${NC}
    - 在iipe项目根目录运行
    - 具有sudo权限（用于安装依赖）
    - 有效的Copr账号

${CYAN}示例:${NC}
    # 基本使用
    $SCRIPT_NAME

${CYAN}更多信息:${NC}
    - 详细文档: docs/Copr使用指南.md
    - 项目主页: https://github.com/yourusername/iipe
    - Copr官网: https://copr.fedorainfracloud.org/

EOF
}

# 解析命令行参数
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    --version)
        echo "iipe Copr快速开始脚本 v$SCRIPT_VERSION"
        exit 0
        ;;
    "")
        # 无参数，执行主流程
        main
        ;;
    *)
        log_error "未知选项: $1"
        show_help
        exit 1
        ;;
esac 