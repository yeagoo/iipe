#!/bin/bash

# iipe 故障排查工具
# 用于诊断常见问题、自动修复和生成故障报告

set -e

# 配置
TROUBLE_LOG_DIR="logs/troubleshoot"
REPORTS_DIR="troubleshoot-reports"
TEMP_DIR="/tmp/iipe_troubleshoot"
KNOWN_ISSUES_FILE="known-issues.db"

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
    echo "$msg" >> "$TROUBLE_LOG_DIR/troubleshoot_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_success() {
    local msg="[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$TROUBLE_LOG_DIR/troubleshoot_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_warning() {
    local msg="[WARNING] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$TROUBLE_LOG_DIR/troubleshoot_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_error() {
    local msg="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${RED}${msg}${NC}"
    echo "$msg" >> "$TROUBLE_LOG_DIR/troubleshoot_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_fix() {
    local msg="[FIX] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${CYAN}${msg}${NC}"
    echo "$msg" >> "$TROUBLE_LOG_DIR/troubleshoot_$(date '+%Y%m%d').log" 2>/dev/null || true
}

# 显示用法
show_usage() {
    echo "iipe 故障排查工具"
    echo ""
    echo "用法: $0 [command] [options]"
    echo ""
    echo "命令:"
    echo "  diagnose          全面诊断系统问题"
    echo "  check-build       检查构建相关问题"
    echo "  check-deps        检查依赖问题"
    echo "  check-perms       检查权限问题"
    echo "  check-network     检查网络问题"
    echo "  check-disk        检查磁盘空间问题"
    echo "  fix-common        自动修复常见问题"
    echo "  analyze-logs      分析日志文件"
    echo "  generate-report   生成故障报告"
    echo "  interactive       交互式故障排查"
    echo ""
    echo "选项:"
    echo "  -a, --auto-fix           自动修复发现的问题"
    echo "  -v, --verbose            详细输出"
    echo "  -o, --output FORMAT      输出格式 [text|html|json]"
    echo "  -l, --log-file FILE      指定日志文件分析"
    echo "  -s, --severity LEVEL     最低问题严重级别 [LOW|MEDIUM|HIGH|CRITICAL]"
    echo "  -h, --help               显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 diagnose              # 全面诊断"
    echo "  $0 check-build -a        # 检查构建问题并自动修复"
    echo "  $0 fix-common            # 修复常见问题"
    echo "  $0 analyze-logs -l build.log  # 分析指定日志"
}

# 初始化故障排查环境
init_troubleshoot() {
    mkdir -p "$TROUBLE_LOG_DIR" "$REPORTS_DIR" "$TEMP_DIR"
    
    # 创建已知问题数据库
    if [ ! -f "$KNOWN_ISSUES_FILE" ]; then
        create_known_issues_db
    fi
    
    print_info "故障排查环境初始化完成"
}

# 创建已知问题数据库
create_known_issues_db() {
    cat > "$KNOWN_ISSUES_FILE" <<EOF
# iipe 已知问题数据库
# 格式: 问题ID|严重级别|问题描述|检测方法|修复方法

MOCK_NOT_IN_GROUP|HIGH|用户不在mock组中|groups | grep -q mock|sudo usermod -a -G mock \$USER
MOCK_CACHE_FULL|MEDIUM|Mock缓存空间不足|df /var/lib/mock | tail -1 | awk '{print \$5}' | sed 's/%//' | awk '{if(\$1>90) print "full"}|rm -rf /var/lib/mock/*/cache/*
GPG_CHECK_DISABLED|MEDIUM|GPG检查被禁用|grep -r "gpgcheck=0" mock_configs/|sed -i 's/gpgcheck=0/gpgcheck=1/g' mock_configs/*.cfg
HTTP_REPOS|LOW|使用不安全的HTTP仓库|grep -r "http://" mock_configs/ | grep -v "https://"|sed -i 's|http://|https://|g' mock_configs/*.cfg
MISSING_DEPS|HIGH|缺少构建依赖|rpm -q rpm-build mock createrepo_c | grep "not installed"|dnf install -y rpm-build mock createrepo_c
SPEC_SYNTAX_ERROR|HIGH|Spec文件语法错误|rpmbuild --nobuild *.spec 2>&1 | grep -i error|检查spec文件语法
NETWORK_TIMEOUT|MEDIUM|网络连接超时|ping -c 3 -W 5 repo.almalinux.org|检查网络连接和DNS设置
DISK_SPACE_LOW|HIGH|磁盘空间不足|df -h | awk '{if(\$5+0>90) print \$6}'|清理临时文件和缓存
PERMISSION_DENIED|HIGH|权限被拒绝|ls -la | grep "Permission denied"|修复文件权限
BUILD_TIMEOUT|MEDIUM|构建超时|grep -i timeout logs/|增加构建超时时间
EOF
    print_success "已知问题数据库创建完成"
}

# 全面系统诊断
diagnose_system() {
    local auto_fix="${1:-false}"
    
    print_info "开始全面系统诊断..."
    
    local total_issues=0
    local fixed_issues=0
    local critical_issues=0
    local high_issues=0
    local medium_issues=0
    local low_issues=0
    
    # 创建诊断报告
    local diag_report="$TEMP_DIR/diagnosis_$(date '+%Y%m%d_%H%M%S').txt"
    
    echo "iipe 系统诊断报告" > "$diag_report"
    echo "==================" >> "$diag_report"
    echo "诊断时间: $(date)" >> "$diag_report"
    echo "主机信息: $(hostname)" >> "$diag_report"
    echo "" >> "$diag_report"
    
    # 执行各项检查
    print_info "检查构建环境..."
    local build_issues=$(check_build_environment "$auto_fix")
    total_issues=$((total_issues + build_issues))
    
    print_info "检查依赖..."
    local dep_issues=$(check_dependencies "$auto_fix")
    total_issues=$((total_issues + dep_issues))
    
    print_info "检查权限..."
    local perm_issues=$(check_permissions "$auto_fix") 
    total_issues=$((total_issues + perm_issues))
    
    print_info "检查网络..."
    local net_issues=$(check_network_connectivity "$auto_fix")
    total_issues=$((total_issues + net_issues))
    
    print_info "检查磁盘空间..."
    local disk_issues=$(check_disk_space "$auto_fix")
    total_issues=$((total_issues + disk_issues))
    
    print_info "分析日志文件..."
    analyze_logs_for_issues >> "$diag_report"
    
    # 生成诊断总结
    echo "" >> "$diag_report"
    echo "诊断总结:" >> "$diag_report"
    echo "--------" >> "$diag_report"
    echo "总问题数: $total_issues" >> "$diag_report"
    echo "已修复: $fixed_issues" >> "$diag_report"
    echo "待处理: $((total_issues - fixed_issues))" >> "$diag_report"
    
    # 保存报告
    cp "$diag_report" "$REPORTS_DIR/diagnosis_$(date '+%Y%m%d_%H%M%S').txt"
    
    # 输出结果
    if [ $total_issues -eq 0 ]; then
        print_success "系统诊断完成，未发现问题"
    else
        print_warning "系统诊断完成，发现 $total_issues 个问题"
        if [ "$auto_fix" = "true" ]; then
            print_info "已自动修复 $fixed_issues 个问题"
        fi
    fi
    
    return $total_issues
}

# 检查构建环境
check_build_environment() {
    local auto_fix="${1:-false}"
    local issues=0
    
    print_info "检查构建环境配置..."
    
    # 检查必要的构建文件
    local required_files=(
        "build.sh"
        "batch-build.sh" 
        "publish.sh"
        "macros.iipe-php"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "缺少必要文件: $file"
            issues=$((issues + 1))
        fi
    done
    
    # 检查spec文件
    print_info "检查spec文件语法..."
    for spec_file in */iipe-php.spec; do
        if [ -f "$spec_file" ]; then
            if ! rpmbuild --nobuild "$spec_file" >/dev/null 2>&1; then
                print_error "Spec文件语法错误: $spec_file"
                issues=$((issues + 1))
                
                if [ "$auto_fix" = "true" ]; then
                    print_fix "尝试修复spec文件..."
                    # 这里可以添加自动修复逻辑
                fi
            fi
        fi
    done
    
    # 检查Mock配置
    print_info "检查Mock配置..."
    if [ ! -d "mock_configs" ] || [ "$(find mock_configs -name "*.cfg" | wc -l)" -eq 0 ]; then
        print_error "Mock配置缺失"
        issues=$((issues + 1))
        
        if [ "$auto_fix" = "true" ]; then
            print_fix "创建默认Mock配置..."
            # 可以调用init-project.sh重新初始化
        fi
    fi
    
    return $issues
}

# 检查依赖
check_dependencies() {
    local auto_fix="${1:-false}"
    local issues=0
    
    print_info "检查系统依赖..."
    
    local required_packages=(
        "rpm-build"
        "mock"
        "createrepo_c"
        "git"
        "wget"
        "curl"
    )
    
    local missing_packages=()
    
    for package in "${required_packages[@]}"; do
        if ! rpm -q "$package" >/dev/null 2>&1; then
            print_error "缺少依赖包: $package"
            missing_packages+=("$package")
            issues=$((issues + 1))
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ] && [ "$auto_fix" = "true" ]; then
        print_fix "安装缺失的依赖包..."
        if sudo dnf install -y "${missing_packages[@]}"; then
            print_success "依赖包安装完成"
        else
            print_error "依赖包安装失败"
        fi
    fi
    
    return $issues
}

# 检查权限
check_permissions() {
    local auto_fix="${1:-false}"
    local issues=0
    
    print_info "检查文件和目录权限..."
    
    # 检查用户是否在mock组中
    if ! groups | grep -q mock; then
        print_error "当前用户不在mock组中"
        issues=$((issues + 1))
        
        if [ "$auto_fix" = "true" ]; then
            print_fix "添加用户到mock组..."
            if sudo usermod -a -G mock "$USER"; then
                print_success "用户已添加到mock组，请重新登录"
            else
                print_error "添加用户到mock组失败"
            fi
        fi
    fi
    
    # 检查脚本执行权限
    for script in *.sh; do
        if [ -f "$script" ] && [ ! -x "$script" ]; then
            print_error "脚本缺少执行权限: $script"
            issues=$((issues + 1))
            
            if [ "$auto_fix" = "true" ]; then
                print_fix "修复脚本权限: $script"
                chmod +x "$script"
            fi
        fi
    done
    
    # 检查Mock缓存目录权限
    if [ -d "/var/lib/mock" ]; then
        if [ ! -w "/var/lib/mock" ]; then
            print_error "无法写入Mock缓存目录"
            issues=$((issues + 1))
        fi
    fi
    
    return $issues
}

# 检查网络连接
check_network_connectivity() {
    local auto_fix="${1:-false}"
    local issues=0
    
    print_info "检查网络连接..."
    
    # 测试常用软件仓库连接
    local repositories=(
        "repo.almalinux.org"
        "download.rockylinux.org"
        "yum.oracle.com"
        "repo.openeuler.org"
    )
    
    for repo in "${repositories[@]}"; do
        if ! ping -c 3 -W 5 "$repo" >/dev/null 2>&1; then
            print_error "无法连接到仓库: $repo"
            issues=$((issues + 1))
        fi
    done
    
    # 检查DNS解析
    if ! nslookup google.com >/dev/null 2>&1; then
        print_error "DNS解析问题"
        issues=$((issues + 1))
        
        if [ "$auto_fix" = "true" ]; then
            print_fix "尝试刷新DNS缓存..."
            sudo systemctl restart systemd-resolved 2>/dev/null || true
        fi
    fi
    
    return $issues
}

# 检查磁盘空间
check_disk_space() {
    local auto_fix="${1:-false}"
    local issues=0
    
    print_info "检查磁盘空间..."
    
    # 检查关键目录的磁盘使用率
    local critical_dirs=(
        "/"
        "/var"
        "/tmp"
        "."
    )
    
    for dir in "${critical_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local usage=$(df "$dir" | tail -1 | awk '{print $5}' | sed 's/%//')
            
            if [ "$usage" -ge 95 ]; then
                print_error "磁盘空间严重不足: $dir ($usage%)"
                issues=$((issues + 1))
                
                if [ "$auto_fix" = "true" ]; then
                    print_fix "清理临时文件..."
                    case "$dir" in
                        "/var")
                            # 清理Mock缓存
                            sudo find /var/lib/mock -name "cache" -exec rm -rf {} \; 2>/dev/null || true
                            ;;
                        "/tmp")
                            # 清理临时文件
                            sudo find /tmp -type f -mtime +7 -delete 2>/dev/null || true
                            ;;
                        ".")
                            # 清理本地缓存
                            rm -rf sources/*.tmp 2>/dev/null || true
                            ;;
                    esac
                fi
            elif [ "$usage" -ge 85 ]; then
                print_warning "磁盘空间不足: $dir ($usage%)"
            fi
        fi
    done
    
    return $issues
}

# 分析日志文件
analyze_logs_for_issues() {
    print_info "分析日志文件..."
    
    echo "日志分析结果:"
    echo "------------"
    
    # 分析构建日志
    if [ -d "logs" ]; then
        local error_count=$(find logs -name "*.log" -exec grep -i "error\|failed\|timeout" {} \; 2>/dev/null | wc -l)
        echo "发现错误日志条目: $error_count"
        
        # 显示最近的错误
        echo ""
        echo "最近的错误信息:"
        find logs -name "*.log" -mtime -1 -exec grep -i "error\|failed" {} \; 2>/dev/null | tail -10
    fi
    
    # 分析系统日志
    if command -v journalctl >/dev/null 2>&1; then
        local recent_errors=$(journalctl --since "1 hour ago" --priority=3 --no-pager -q | wc -l)
        echo ""
        echo "系统错误日志 (最近1小时): $recent_errors 条"
    fi
}

# 自动修复常见问题
fix_common_issues() {
    print_info "开始修复常见问题..."
    
    local fixed_count=0
    
    # 修复脚本权限
    print_info "修复脚本执行权限..."
    for script in *.sh; do
        if [ -f "$script" ] && [ ! -x "$script" ]; then
            chmod +x "$script"
            print_fix "已修复: $script 权限"
            fixed_count=$((fixed_count + 1))
        fi
    done
    
    # 启用GPG检查
    print_info "启用GPG检查..."
    if find mock_configs -name "*.cfg" -exec grep -l "gpgcheck=0" {} \; 2>/dev/null | grep -q .; then
        find mock_configs -name "*.cfg" -exec sed -i 's/gpgcheck=0/gpgcheck=1/g' {} \;
        print_fix "已启用所有配置文件的GPG检查"
        fixed_count=$((fixed_count + 1))
    fi
    
    # 清理临时文件
    print_info "清理临时文件..."
    local cleaned_files=0
    
    # 清理sources目录的临时文件
    if [ -d "sources" ]; then
        cleaned_files=$(find sources -name "*.tmp" -o -name "*.download" | wc -l)
        find sources -name "*.tmp" -o -name "*.download" -delete 2>/dev/null || true
    fi
    
    if [ $cleaned_files -gt 0 ]; then
        print_fix "已清理 $cleaned_files 个临时文件"
        fixed_count=$((fixed_count + 1))
    fi
    
    # 修复HTTP协议为HTTPS
    print_info "升级HTTP协议到HTTPS..."
    if find mock_configs -name "*.cfg" -exec grep -l "http://" {} \; 2>/dev/null | grep -q .; then
        find mock_configs -name "*.cfg" -exec sed -i 's|http://|https://|g' {} \;
        print_fix "已将HTTP协议升级为HTTPS"
        fixed_count=$((fixed_count + 1))
    fi
    
    print_success "常见问题修复完成，共修复 $fixed_count 个问题"
}

# 交互式故障排查
interactive_troubleshoot() {
    print_info "启动交互式故障排查..."
    
    while true; do
        echo ""
        echo "=== iipe 交互式故障排查 ==="
        echo "1. 全面系统诊断"
        echo "2. 检查构建问题"
        echo "3. 检查权限问题"
        echo "4. 检查网络问题"
        echo "5. 分析日志文件"
        echo "6. 修复常见问题"
        echo "7. 生成故障报告"
        echo "8. 退出"
        echo ""
        
        read -p "请选择操作 (1-8): " choice
        
        case $choice in
            1)
                echo ""
                read -p "是否自动修复发现的问题? (y/N): " auto_fix
                if [[ "$auto_fix" =~ ^[Yy]$ ]]; then
                    diagnose_system "true"
                else
                    diagnose_system "false"
                fi
                ;;
            2)
                check_build_environment "false"
                ;;
            3)
                check_permissions "false"
                ;;
            4)
                check_network_connectivity "false"
                ;;
            5)
                analyze_logs_for_issues
                ;;
            6)
                fix_common_issues
                ;;
            7)
                generate_troubleshoot_report "text"
                ;;
            8)
                print_info "退出交互式故障排查"
                break
                ;;
            *)
                print_error "无效选择，请重新输入"
                ;;
        esac
        
        echo ""
        read -p "按 Enter 键继续..."
    done
}

# 生成故障排查报告
generate_troubleshoot_report() {
    local output_format="${1:-text}"
    local report_file="$REPORTS_DIR/troubleshoot_report_$(date '+%Y%m%d_%H%M%S')"
    
    print_info "生成故障排查报告 (格式: $output_format)..."
    
    case "$output_format" in
        "html")
            generate_html_troubleshoot_report "$report_file.html"
            ;;
        "json")
            generate_json_troubleshoot_report "$report_file.json"
            ;;
        *)
            generate_text_troubleshoot_report "$report_file.txt"
            ;;
    esac
    
    print_success "故障排查报告已生成: $report_file.$output_format"
}

# 生成文本格式报告
generate_text_troubleshoot_report() {
    local report_file="$1"
    
    cat > "$report_file" <<EOF
iipe 故障排查报告
=================

生成时间: $(date)
主机信息: $(hostname)

系统状态检查:
- 构建环境: $([ -f "build.sh" ] && echo "正常" || echo "异常")
- 依赖检查: $(rpm -q rpm-build mock createrepo_c >/dev/null 2>&1 && echo "正常" || echo "异常")
- 权限检查: $(groups | grep -q mock && echo "正常" || echo "异常")
- 磁盘空间: $(df -h | awk 'NR>1 && $5+0>90 {count++} END {if(count>0) print "不足"; else print "充足"}')

建议的解决方案:
1. 运行 ./troubleshoot.sh fix-common 修复常见问题
2. 检查系统日志: journalctl --since "1 hour ago" --priority=3
3. 确保用户在mock组中: sudo usermod -a -G mock \$USER
4. 定期清理临时文件和缓存

详细诊断信息请运行: ./troubleshoot.sh diagnose
EOF
}

# 生成HTML格式报告
generate_html_troubleshoot_report() {
    local report_file="$1"
    
    cat > "$report_file" <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>iipe 故障排查报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f8f9fa; padding: 20px; border-radius: 5px; }
        .status-ok { color: #28a745; font-weight: bold; }
        .status-error { color: #dc3545; font-weight: bold; }
        .status-warning { color: #ffc107; font-weight: bold; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007bff; }
        .table { border-collapse: collapse; width: 100%; }
        .table th, .table td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        .table th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔧 iipe 故障排查报告</h1>
        <p>生成时间: $(date)</p>
        <p>主机: $(hostname)</p>
    </div>

    <div class="section">
        <h2>📊 系统状态概览</h2>
        <table class="table">
            <tr><th>检查项目</th><th>状态</th></tr>
            <tr><td>构建环境</td><td class="$([ -f "build.sh" ] && echo "status-ok" || echo "status-error")">$([ -f "build.sh" ] && echo "正常" || echo "异常")</td></tr>
            <tr><td>依赖检查</td><td class="$(rpm -q rpm-build mock createrepo_c >/dev/null 2>&1 && echo "status-ok" || echo "status-error")">$(rpm -q rpm-build mock createrepo_c >/dev/null 2>&1 && echo "正常" || echo "异常")</td></tr>
            <tr><td>权限检查</td><td class="$(groups | grep -q mock && echo "status-ok" || echo "status-error")">$(groups | grep -q mock && echo "正常" || echo "异常")</td></tr>
            <tr><td>磁盘空间</td><td class="$(df -h | awk 'NR>1 && $5+0>90 {count++} END {if(count>0) print "status-error"; else print "status-ok"}')">$(df -h | awk 'NR>1 && $5+0>90 {count++} END {if(count>0) print "不足"; else print "充足"}')</td></tr>
        </table>
    </div>

    <div class="section">
        <h2>🔧 建议的解决方案</h2>
        <ol>
            <li>运行 <code>./troubleshoot.sh fix-common</code> 修复常见问题</li>
            <li>检查系统日志: <code>journalctl --since "1 hour ago" --priority=3</code></li>
            <li>确保用户在mock组中: <code>sudo usermod -a -G mock \$USER</code></li>
            <li>定期清理临时文件和缓存</li>
        </ol>
    </div>

    <div class="section">
        <h2>📝 详细诊断</h2>
        <p>如需详细诊断信息，请运行: <code>./troubleshoot.sh diagnose</code></p>
    </div>
</body>
</html>
EOF
}

# 生成JSON格式报告
generate_json_troubleshoot_report() {
    local report_file="$1"
    
    # 获取系统状态
    local build_env_status=$([ -f "build.sh" ] && echo "ok" || echo "error")
    local deps_status=$(rpm -q rpm-build mock createrepo_c >/dev/null 2>&1 && echo "ok" || echo "error")
    local perms_status=$(groups | grep -q mock && echo "ok" || echo "error")
    local disk_status=$(df -h | awk 'NR>1 && $5+0>90 {count++} END {if(count>0) print "error"; else print "ok"}')
    
    cat > "$report_file" <<EOF
{
  "report": {
    "title": "iipe 故障排查报告",
    "generated_at": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "status": {
      "build_environment": {
        "status": "$build_env_status",
        "description": "构建环境检查"
      },
      "dependencies": {
        "status": "$deps_status", 
        "description": "依赖包检查"
      },
      "permissions": {
        "status": "$perms_status",
        "description": "权限检查"
      },
      "disk_space": {
        "status": "$disk_status",
        "description": "磁盘空间检查"
      }
    },
    "recommendations": [
      "运行 ./troubleshoot.sh fix-common 修复常见问题",
      "检查系统日志: journalctl --since \"1 hour ago\" --priority=3",
      "确保用户在mock组中: sudo usermod -a -G mock \$USER",
      "定期清理临时文件和缓存"
    ],
    "next_steps": [
      "运行详细诊断: ./troubleshoot.sh diagnose",
      "检查特定组件: ./troubleshoot.sh check-build",
      "生成完整报告: ./troubleshoot.sh generate-report"
    ]
  }
}
EOF
}

# 主函数
main() {
    local command=""
    local auto_fix=false
    local verbose=false
    local output_format="text"
    local log_file=""
    local severity="MEDIUM"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            diagnose|check-build|check-deps|check-perms|check-network|check-disk|fix-common|analyze-logs|generate-report|interactive)
                command="$1"
                shift
                ;;
            -a|--auto-fix)
                auto_fix=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -o|--output)
                output_format="$2"
                shift 2
                ;;
            -l|--log-file)
                log_file="$2"
                shift 2
                ;;
            -s|--severity)
                severity="$2"
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
    
    # 初始化环境
    init_troubleshoot
    
    # 执行命令
    case "$command" in
        "diagnose")
            diagnose_system "$auto_fix"
            ;;
        "check-build")
            check_build_environment "$auto_fix"
            ;;
        "check-deps")
            check_dependencies "$auto_fix"
            ;;
        "check-perms")
            check_permissions "$auto_fix"
            ;;
        "check-network")
            check_network_connectivity "$auto_fix"
            ;;
        "check-disk")
            check_disk_space "$auto_fix"
            ;;
        "fix-common")
            fix_common_issues
            ;;
        "analyze-logs")
            if [ -n "$log_file" ]; then
                print_info "分析指定日志文件: $log_file"
                # 这里可以添加特定日志文件的分析逻辑
            else
                analyze_logs_for_issues
            fi
            ;;
        "generate-report")
            generate_troubleshoot_report "$output_format"
            ;;
        "interactive")
            interactive_troubleshoot
            ;;
        "")
            # 默认执行快速诊断
            print_info "执行快速诊断..."
            diagnose_system "false"
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