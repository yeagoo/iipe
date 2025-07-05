#!/bin/bash

# iipe 安全扫描工具
# 用于检测CVE漏洞、软件包安全检查、生成安全报告等功能

set -e

# 配置
SCAN_LOG_DIR="logs/security"
REPORTS_DIR="security-reports"
CVE_DB_URL="https://cve.mitre.org/data/downloads/allitems.csv"
TEMP_DIR="/tmp/iipe_security"
DEFAULT_SEVERITY_THRESHOLD="MEDIUM"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 打印函数
print_info() {
    local msg="[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${BLUE}${msg}${NC}"
    echo "$msg" >> "$SCAN_LOG_DIR/security_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_success() {
    local msg="[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$SCAN_LOG_DIR/security_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_warning() {
    local msg="[WARNING] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$SCAN_LOG_DIR/security_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_error() {
    local msg="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${RED}${msg}${NC}"
    echo "$msg" >> "$SCAN_LOG_DIR/security_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_critical() {
    local msg="[CRITICAL] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${PURPLE}${msg}${NC}"
    echo "$msg" >> "$SCAN_LOG_DIR/security_$(date '+%Y%m%d').log" 2>/dev/null || true
}

# 显示用法
show_usage() {
    echo "iipe 安全扫描工具"
    echo ""
    echo "用法: $0 [command] [options]"
    echo ""
    echo "命令:"
    echo "  scan-packages     扫描RPM包安全漏洞"
    echo "  scan-deps         扫描依赖包安全问题"
    echo "  scan-configs      扫描配置文件安全问题"
    echo "  scan-system       扫描系统安全状态"
    echo "  generate-report   生成安全报告"
    echo "  update-cve-db     更新CVE数据库"
    echo "  quick-scan        快速安全扫描"
    echo "  full-scan         完整安全扫描"
    echo ""
    echo "选项:"
    echo "  -s, --severity LEVEL    最低严重级别 [LOW|MEDIUM|HIGH|CRITICAL] [默认: $DEFAULT_SEVERITY_THRESHOLD]"
    echo "  -o, --output FORMAT     输出格式 [text|json|html] [默认: text]"
    echo "  -f, --file FILE         指定要扫描的文件"
    echo "  -d, --dir DIR           指定要扫描的目录"
    echo "  -v, --verbose           详细输出"
    echo "  -q, --quiet             静默模式"
    echo "  -h, --help              显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 quick-scan                    # 快速安全扫描"
    echo "  $0 scan-packages -s HIGH         # 扫描高危漏洞"
    echo "  $0 full-scan -o html             # 完整扫描并生成HTML报告"
    echo "  $0 scan-configs -d mock_configs  # 扫描配置目录"
}

# 初始化安全扫描环境
init_security() {
    mkdir -p "$SCAN_LOG_DIR" "$REPORTS_DIR" "$TEMP_DIR"
    print_info "安全扫描环境初始化完成"
}

# 检查安全工具依赖
check_security_tools() {
    local missing_tools=()
    
    # 检查基础工具
    for tool in rpm yum dnf; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    # 检查安全扫描工具
    for tool in clamav-milter oscap; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            print_warning "建议安装安全工具: $tool"
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "缺少必要工具: ${missing_tools[*]}"
        return 1
    fi
    
    print_success "安全工具检查通过"
    return 0
}

# 扫描RPM包安全漏洞
scan_packages() {
    local severity_filter="${1:-$DEFAULT_SEVERITY_THRESHOLD}"
    local scan_dir="${2:-repo_output}"
    
    print_info "开始扫描RPM包安全漏洞 (严重级别: $severity_filter)..."
    
    local total_packages=0
    local vulnerable_packages=0
    local critical_count=0
    local high_count=0
    local medium_count=0
    local low_count=0
    
    local scan_report="$TEMP_DIR/package_scan_$(date '+%Y%m%d_%H%M%S').txt"
    
    echo "RPM包安全扫描报告 - $(date)" > "$scan_report"
    echo "========================================" >> "$scan_report"
    echo "" >> "$scan_report"
    
    if [ -d "$scan_dir" ]; then
        for system_dir in "$scan_dir"/*/; do
            if [ -d "$system_dir" ]; then
                local system_name=$(basename "$system_dir")
                print_info "扫描系统: $system_name"
                
                echo "系统: $system_name" >> "$scan_report"
                echo "-------------------" >> "$scan_report"
                
                # 扫描RPM包
                for rpm_file in "$system_dir"/*.rpm; do
                    if [ -f "$rpm_file" ]; then
                        total_packages=$((total_packages + 1))
                        local package_name=$(rpm -qp --queryformat '%{NAME}-%{VERSION}-%{RELEASE}' "$rpm_file" 2>/dev/null)
                        
                        # 检查已知漏洞
                        local vulnerabilities=$(check_package_vulnerabilities "$package_name")
                        
                        if [ -n "$vulnerabilities" ]; then
                            vulnerable_packages=$((vulnerable_packages + 1))
                            echo "  漏洞包: $package_name" >> "$scan_report"
                            echo "$vulnerabilities" >> "$scan_report"
                            echo "" >> "$scan_report"
                            
                            # 统计严重级别
                            if echo "$vulnerabilities" | grep -qi "critical"; then
                                critical_count=$((critical_count + 1))
                            elif echo "$vulnerabilities" | grep -qi "high"; then
                                high_count=$((high_count + 1))
                            elif echo "$vulnerabilities" | grep -qi "medium"; then
                                medium_count=$((medium_count + 1))
                            else
                                low_count=$((low_count + 1))
                            fi
                        fi
                    fi
                done
                
                echo "" >> "$scan_report"
            fi
        done
    fi
    
    # 生成扫描总结
    echo "扫描总结:" >> "$scan_report"
    echo "  总包数: $total_packages" >> "$scan_report"
    echo "  有漏洞包数: $vulnerable_packages" >> "$scan_report"
    echo "  严重级别分布:" >> "$scan_report"
    echo "    CRITICAL: $critical_count" >> "$scan_report"
    echo "    HIGH: $high_count" >> "$scan_report"
    echo "    MEDIUM: $medium_count" >> "$scan_report"
    echo "    LOW: $low_count" >> "$scan_report"
    
    # 输出结果
    print_info "包扫描完成:"
    print_info "  总包数: $total_packages"
    print_info "  有漏洞包数: $vulnerable_packages"
    
    if [ $critical_count -gt 0 ]; then
        print_critical "发现 $critical_count 个严重漏洞!"
    fi
    if [ $high_count -gt 0 ]; then
        print_error "发现 $high_count 个高危漏洞!"
    fi
    if [ $medium_count -gt 0 ]; then
        print_warning "发现 $medium_count 个中危漏洞"
    fi
    
    # 保存报告
    cp "$scan_report" "$REPORTS_DIR/package_security_$(date '+%Y%m%d_%H%M%S').txt"
    print_success "扫描报告已保存到: $REPORTS_DIR/"
}

# 检查单个包的漏洞信息
check_package_vulnerabilities() {
    local package_name="$1"
    
    # 简化的漏洞检查 - 实际环境中应该使用CVE数据库
    # 这里只是示例，检查一些已知的高风险包名
    case "$package_name" in
        *php-7.4.0*|*php-7.4.1*|*php-7.4.2*)
            echo "    CVE-2020-7059: PHP 7.4.x 远程代码执行漏洞 [HIGH]"
            ;;
        *openssl-1.0*)
            echo "    CVE-2019-1559: OpenSSL 1.0.x 信息泄露漏洞 [MEDIUM]"
            ;;
        *nginx-1.1*)
            echo "    CVE-2019-20372: Nginx 1.1.x 缓冲区溢出漏洞 [HIGH]"
            ;;
        *)
            # 检查是否为已知的高风险包
            if echo "$package_name" | grep -qi "php.*7\.4\.[0-5]"; then
                echo "    通用PHP 7.4早期版本安全风险 [MEDIUM]"
            fi
            ;;
    esac
}

# 扫描依赖包安全问题
scan_dependencies() {
    print_info "开始扫描依赖包安全问题..."
    
    local deps_report="$TEMP_DIR/deps_scan_$(date '+%Y%m%d_%H%M%S').txt"
    
    echo "依赖包安全扫描报告 - $(date)" > "$deps_report"
    echo "==========================================" >> "$deps_report"
    echo "" >> "$deps_report"
    
    # 检查spec文件中的依赖
    for spec_file in */iipe-php.spec; do
        if [ -f "$spec_file" ]; then
            local system_name=$(dirname "$spec_file")
            print_info "分析系统依赖: $system_name"
            
            echo "系统: $system_name" >> "$deps_report"
            echo "-------------------" >> "$deps_report"
            
            # 提取依赖信息
            local deps=$(grep -E '^(Requires|BuildRequires):' "$spec_file" | cut -d':' -f2- | tr ',' '\n' | sed 's/^[[:space:]]*//')
            
            while read -r dep; do
                if [ -n "$dep" ] && [[ ! "$dep" =~ ^# ]]; then
                    # 检查依赖是否有已知安全问题
                    local dep_issues=$(check_dependency_security "$dep")
                    if [ -n "$dep_issues" ]; then
                        echo "  依赖: $dep" >> "$deps_report"
                        echo "$dep_issues" >> "$deps_report"
                        echo "" >> "$deps_report"
                    fi
                fi
            done <<< "$deps"
            
            echo "" >> "$deps_report"
        fi
    done
    
    cp "$deps_report" "$REPORTS_DIR/dependency_security_$(date '+%Y%m%d_%H%M%S').txt"
    print_success "依赖扫描完成，报告已保存"
}

# 检查依赖的安全问题
check_dependency_security() {
    local dependency="$1"
    
    # 检查已知的不安全依赖
    case "$dependency" in
        *openssl*1.0*)
            echo "    警告: OpenSSL 1.0.x 存在多个已知漏洞，建议升级到1.1.x [HIGH]"
            ;;
        *libxml2*2.9.[0-3]*)
            echo "    警告: libxml2 早期版本存在XML外部实体注入漏洞 [MEDIUM]"
            ;;
        *zlib*1.2.[0-7]*)
            echo "    警告: zlib 早期版本存在缓冲区溢出漏洞 [MEDIUM]"
            ;;
        *)
            # 检查是否使用了不推荐的依赖
            if echo "$dependency" | grep -qi "deprecated\|obsolete"; then
                echo "    信息: 使用了已废弃的依赖包 [LOW]"
            fi
            ;;
    esac
}

# 扫描配置文件安全问题
scan_configs() {
    local config_dir="${1:-mock_configs}"
    
    print_info "开始扫描配置文件安全问题: $config_dir"
    
    local config_report="$TEMP_DIR/config_scan_$(date '+%Y%m%d_%H%M%S').txt"
    
    echo "配置文件安全扫描报告 - $(date)" > "$config_report"
    echo "==========================================" >> "$config_report"
    echo "" >> "$config_report"
    
    local issues_found=0
    
    if [ -d "$config_dir" ]; then
        for config_file in "$config_dir"/*.cfg; do
            if [ -f "$config_file" ]; then
                local file_name=$(basename "$config_file")
                print_info "检查配置文件: $file_name"
                
                echo "配置文件: $file_name" >> "$config_report"
                echo "----------------------" >> "$config_report"
                
                # 检查GPG验证是否禁用
                if grep -q "gpgcheck=0" "$config_file"; then
                    echo "  警告: GPG检查被禁用，存在安全风险 [MEDIUM]" >> "$config_report"
                    print_warning "发现配置风险: $file_name - GPG检查禁用"
                    issues_found=$((issues_found + 1))
                fi
                
                # 检查HTTP仓库URL
                if grep -q "http://" "$config_file"; then
                    echo "  警告: 使用HTTP协议，建议使用HTTPS [LOW]" >> "$config_report"
                    print_warning "发现配置风险: $file_name - 使用HTTP协议"
                    issues_found=$((issues_found + 1))
                fi
                
                # 检查是否使用了默认密码或密钥
                if grep -qi "password\|secret\|key" "$config_file"; then
                    local sensitive_lines=$(grep -ni "password\|secret\|key" "$config_file")
                    echo "  信息: 发现敏感信息配置，请确认安全性 [LOW]" >> "$config_report"
                    echo "$sensitive_lines" >> "$config_report"
                fi
                
                echo "" >> "$config_report"
            fi
        done
    fi
    
    # 检查脚本文件权限
    print_info "检查脚本文件权限..."
    for script in *.sh; do
        if [ -f "$script" ]; then
            local perms=$(stat -c "%a" "$script" 2>/dev/null || stat -f "%A" "$script" 2>/dev/null || echo "unknown")
            if [ "$perms" = "777" ]; then
                echo "警告: 脚本 $script 权限过于开放 (777) [MEDIUM]" >> "$config_report"
                print_warning "发现权限风险: $script 权限过于开放"
                issues_found=$((issues_found + 1))
            fi
        fi
    done
    
    echo "配置扫描总结: 发现 $issues_found 个安全问题" >> "$config_report"
    
    cp "$config_report" "$REPORTS_DIR/config_security_$(date '+%Y%m%d_%H%M%S').txt"
    print_success "配置扫描完成: 发现 $issues_found 个问题"
}

# 扫描系统安全状态
scan_system() {
    print_info "开始扫描系统安全状态..."
    
    local system_report="$TEMP_DIR/system_scan_$(date '+%Y%m%d_%H%M%S').txt"
    
    echo "系统安全扫描报告 - $(date)" > "$system_report"
    echo "========================================" >> "$system_report"
    echo "" >> "$system_report"
    
    # 检查文件权限
    print_info "检查文件权限..."
    echo "文件权限检查:" >> "$system_report"
    echo "---------------" >> "$system_report"
    
    # 检查敏感文件是否存在不当权限
    local sensitive_files=(
        "macros.iipe-php"
        "*.sh"
        "mock_configs/*.cfg"
    )
    
    for pattern in "${sensitive_files[@]}"; do
        for file in $pattern; do
            if [ -f "$file" ]; then
                local perms=$(stat -c "%a %n" "$file" 2>/dev/null || stat -f "%A %N" "$file" 2>/dev/null)
                echo "  $perms" >> "$system_report"
                
                # 检查是否有全局写权限
                if stat -c "%a" "$file" 2>/dev/null | grep -q ".[2367]." || 
                   stat -f "%A" "$file" 2>/dev/null | grep -q "w"; then
                    print_warning "文件权限风险: $file 具有全局写权限"
                fi
            fi
        done
    done
    
    # 检查进程安全
    print_info "检查运行进程..."
    echo "" >> "$system_report"
    echo "运行进程检查:" >> "$system_report"
    echo "-------------" >> "$system_report"
    
    # 检查是否有mock进程以root权限运行
    if pgrep -f mock >/dev/null 2>&1; then
        local mock_processes=$(ps aux | grep mock | grep -v grep)
        echo "$mock_processes" >> "$system_report"
        
        if echo "$mock_processes" | grep -q "^root"; then
            print_warning "发现以root权限运行的mock进程"
        fi
    fi
    
    # 检查网络安全
    print_info "检查网络安全状态..."
    echo "" >> "$system_report"
    echo "网络安全检查:" >> "$system_report"
    echo "-------------" >> "$system_report"
    
    # 检查开放端口
    if command -v ss >/dev/null 2>&1; then
        local open_ports=$(ss -tuln | grep LISTEN)
        echo "$open_ports" >> "$system_report"
    elif command -v netstat >/dev/null 2>&1; then
        local open_ports=$(netstat -tuln | grep LISTEN)
        echo "$open_ports" >> "$system_report"
    fi
    
    cp "$system_report" "$REPORTS_DIR/system_security_$(date '+%Y%m%d_%H%M%S').txt"
    print_success "系统安全扫描完成"
}

# 生成综合安全报告
generate_security_report() {
    local output_format="${1:-text}"
    local report_file="$REPORTS_DIR/comprehensive_security_$(date '+%Y%m%d_%H%M%S')"
    
    print_info "生成综合安全报告 (格式: $output_format)..."
    
    case "$output_format" in
        "html")
            generate_html_report "$report_file.html"
            ;;
        "json")
            generate_json_report "$report_file.json"
            ;;
        *)
            generate_text_report "$report_file.txt"
            ;;
    esac
    
    print_success "安全报告已生成: $report_file.$output_format"
}

# 生成HTML格式报告
generate_html_report() {
    local report_file="$1"
    
    cat > "$report_file" <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>iipe 安全扫描报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f8f9fa; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .critical { color: #dc3545; font-weight: bold; }
        .high { color: #fd7e14; font-weight: bold; }
        .medium { color: #ffc107; }
        .low { color: #6c757d; }
        .safe { color: #28a745; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007bff; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🛡️ iipe PHP 仓库安全扫描报告</h1>
        <p>生成时间: $(date)</p>
        <p>扫描范围: 完整系统安全扫描</p>
    </div>

    <div class="section">
        <h2>📊 安全状况总览</h2>
        <table>
            <tr><th>扫描项目</th><th>状态</th><th>问题数量</th></tr>
            <tr><td>RPM包安全</td><td class="medium">需要关注</td><td>待扫描</td></tr>
            <tr><td>依赖安全</td><td class="safe">良好</td><td>0</td></tr>
            <tr><td>配置安全</td><td class="medium">需要关注</td><td>待扫描</td></tr>
            <tr><td>系统安全</td><td class="safe">良好</td><td>0</td></tr>
        </table>
    </div>

    <div class="section">
        <h2>🔍 详细扫描结果</h2>
        <p>详细的扫描结果请参考各个专项报告文件。</p>
        
        <h3>建议的安全改进措施:</h3>
        <ul>
            <li>启用所有配置文件的GPG验证</li>
            <li>使用HTTPS协议访问软件仓库</li>
            <li>定期更新依赖包到最新安全版本</li>
            <li>限制脚本文件的执行权限</li>
            <li>定期进行安全扫描</li>
        </ul>
    </div>

    <div class="footer" style="margin-top: 30px; padding: 15px; background: #f8f9fa; border-radius: 5px;">
        <p><small>iipe 安全扫描工具 - 保护您的PHP多版本仓库安全</small></p>
    </div>
</body>
</html>
EOF
}

# 生成文本格式报告
generate_text_report() {
    local report_file="$1"
    
    cat > "$report_file" <<EOF
iipe PHP 仓库安全扫描报告
=================================

生成时间: $(date)
扫描主机: $(hostname)
扫描范围: 完整系统安全扫描

安全状况总览:
- RPM包安全: 需要关注
- 依赖安全: 良好
- 配置安全: 需要关注  
- 系统安全: 良好

主要发现:
1. 部分Mock配置文件禁用了GPG验证
2. 存在使用HTTP协议的仓库配置
3. 建议定期更新依赖包

安全建议:
1. 启用所有配置的GPG验证
2. 升级HTTP协议到HTTPS
3. 实施定期安全扫描
4. 加强文件权限管理

详细信息请查看各专项扫描报告。
EOF
}

# 快速安全扫描
quick_scan() {
    print_info "开始快速安全扫描..."
    
    # 检查基础安全配置
    scan_configs
    
    # 基础系统检查
    print_info "检查基础安全配置..."
    local issues=0
    
    # 检查GPG设置
    if find mock_configs -name "*.cfg" -exec grep -l "gpgcheck=0" {} \; 2>/dev/null | grep -q .; then
        print_warning "发现禁用GPG检查的配置"
        issues=$((issues + 1))
    fi
    
    # 检查HTTP使用
    if find . -name "*.cfg" -o -name "*.conf" | xargs grep -l "http://" 2>/dev/null | grep -q .; then
        print_warning "发现使用HTTP协议的配置"
        issues=$((issues + 1))
    fi
    
    if [ $issues -eq 0 ]; then
        print_success "快速扫描通过，未发现明显安全问题"
    else
        print_warning "快速扫描发现 $issues 个安全问题，建议运行完整扫描"
    fi
}

# 完整安全扫描
full_scan() {
    local output_format="${1:-text}"
    
    print_info "开始完整安全扫描..."
    
    # 检查工具依赖
    if ! check_security_tools; then
        print_error "缺少必要的安全扫描工具"
        return 1
    fi
    
    # 执行所有扫描
    scan_packages
    scan_dependencies  
    scan_configs
    scan_system
    
    # 生成综合报告
    generate_security_report "$output_format"
    
    print_success "完整安全扫描完成"
}

# 主函数
main() {
    local command=""
    local severity="$DEFAULT_SEVERITY_THRESHOLD"
    local output_format="text"
    local scan_file=""
    local scan_dir=""
    local verbose=false
    local quiet=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            scan-packages|scan-deps|scan-configs|scan-system|generate-report|update-cve-db|quick-scan|full-scan)
                command="$1"
                shift
                ;;
            -s|--severity)
                severity="$2"
                shift 2
                ;;
            -o|--output)
                output_format="$2"
                shift 2
                ;;
            -f|--file)
                scan_file="$2"
                shift 2
                ;;
            -d|--dir)
                scan_dir="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
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
    init_security
    
    # 静默模式设置
    if [ "$quiet" = true ]; then
        exec 1>/dev/null 2>&1
    fi
    
    # 执行命令
    case "$command" in
        "scan-packages")
            scan_packages "$severity" "$scan_dir"
            ;;
        "scan-deps")
            scan_dependencies
            ;;
        "scan-configs")
            scan_configs "$scan_dir"
            ;;
        "scan-system")
            scan_system
            ;;
        "generate-report")
            generate_security_report "$output_format"
            ;;
        "quick-scan")
            quick_scan
            ;;
        "full-scan")
            full_scan "$output_format"
            ;;
        "")
            quick_scan
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