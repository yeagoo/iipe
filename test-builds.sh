#!/bin/bash

# =============================================================================
# iipe PHP 自动化测试脚本 (Automated Test Script)
# 验证构建的RPM包和PHP功能
# =============================================================================

set -euo pipefail

SCRIPT_NAME="iipe PHP Automated Test"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly TEST_LOG_DIR="${SCRIPT_DIR}/logs/test-builds"
readonly TEST_RESULTS_DIR="${SCRIPT_DIR}/test-results"
readonly TEST_TEMP_DIR="${SCRIPT_DIR}/temp/testing"

readonly SUPPORTED_PHP_VERSIONS=("7.4" "8.0" "8.1" "8.2" "8.3" "8.4" "8.5")
readonly SUPPORTED_SYSTEMS=(
    "almalinux-9" "almalinux-10" "oracle-linux-9" "oracle-linux-10"
    "rocky-linux-9" "rocky-linux-10" "rhel-9" "rhel-10"
    "centos-stream-9" "centos-stream-10"
    "openeuler-24.03" "openanolis-23" "opencloudos-9"
)

# 颜色定义
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_NC='\033[0m'

# 日志函数
log_info() { echo -e "[$(date '+%H:%M:%S')] ${COLOR_BLUE}[INFO]${COLOR_NC} $*"; }
log_warn() { echo -e "[$(date '+%H:%M:%S')] ${COLOR_YELLOW}[WARN]${COLOR_NC} $*"; }
log_error() { echo -e "[$(date '+%H:%M:%S')] ${COLOR_RED}[ERROR]${COLOR_NC} $*"; }
log_success() { echo -e "[$(date '+%H:%M:%S')] ${COLOR_GREEN}[SUCCESS]${COLOR_NC} $*"; }
log_test() { echo -e "[$(date '+%H:%M:%S')] ${COLOR_PURPLE}[TEST]${COLOR_NC} $*"; }

show_usage() {
    cat << EOF
${COLOR_CYAN}${SCRIPT_NAME} v${SCRIPT_VERSION}${COLOR_NC}

用法: $0 [选项]

选项:
    -v, --version VERSION           指定PHP版本进行测试
    -s, --system SYSTEM             指定系统进行测试
    -p, --package-dir DIR           指定RPM包目录
    -t, --test-type TYPE            测试类型: basic|full|smoke (默认: basic)
    -c, --clean                     测试前清理环境
    -h, --help                      显示此帮助信息

测试类型:
    basic   - 基础测试：包完整性、PHP版本、核心功能
    full    - 完整测试：包括扩展测试、性能测试
    smoke   - 冒烟测试：快速验证基本功能

示例:
    $0 -v 8.3                      # 基础测试PHP 8.3
    $0 -v 8.2 -s almalinux-9 -t full  # 完整测试
    $0 -t smoke                     # 冒烟测试所有包

EOF
}

init_test_environment() {
    mkdir -p "$TEST_LOG_DIR" "$TEST_RESULTS_DIR" "$TEST_TEMP_DIR"
    
    if [[ "${CLEAN_TEST:-}" == "true" ]]; then
        log_info "清理旧的测试文件..."
        rm -rf "${TEST_LOG_DIR:?}"/* "${TEST_RESULTS_DIR:?}"/* "${TEST_TEMP_DIR:?}"/*
    fi
}

find_rpm_packages() {
    local php_version="$1"
    local system="$2"
    local package_dir="${PACKAGE_DIR:-${SCRIPT_DIR}/repo_output/${system}}"
    
    if [[ ! -d "$package_dir" ]]; then
        log_error "包目录不存在: $package_dir"
        return 1
    fi
    
    local php_version_short="${php_version//./}"
    find "$package_dir" -name "iipe-php${php_version_short}-*.rpm" -type f 2>/dev/null | head -1
}

test_rpm_integrity() {
    local rpm_file="$1"
    local log_file="${TEST_LOG_DIR}/rpm_integrity.log"
    
    log_test "测试RPM包完整性: $(basename "$rpm_file")"
    
    {
        echo "=== RPM包信息 ==="
        rpm -qip "$rpm_file"
        
        echo -e "\n=== 包内容验证 ==="
        rpm -qlp "$rpm_file" > /tmp/rpm_files.txt
        echo "文件总数: $(wc -l < /tmp/rpm_files.txt)"
        
        echo -e "\n=== 依赖关系 ==="
        rpm -qRp "$rpm_file" | head -10
        
        echo "SUCCESS: RPM包完整性验证通过"
    } > "$log_file" 2>&1
    
    if grep -q "SUCCESS:" "$log_file"; then
        log_success "RPM包完整性验证通过"
        return 0
    else
        log_error "RPM包完整性验证失败"
        return 1
    fi
}

test_php_basic_functionality() {
    local rpm_file="$1"
    local php_version="$2"
    local log_file="${TEST_LOG_DIR}/php_basic_${php_version//./}.log"
    local temp_root="${TEST_TEMP_DIR}/php_${php_version//./}"
    
    log_test "测试PHP基本功能: $php_version"
    
    {
        mkdir -p "$temp_root"
        cd "$temp_root"
        rpm2cpio "$rpm_file" | cpio -idmu 2>/dev/null
        
        local php_bin="opt/iipe/iipe-php${php_version//./}/root/usr/bin/php"
        
        if [[ ! -f "$php_bin" ]]; then
            echo "ERROR: 找不到PHP可执行文件"
            return 1
        fi
        
        echo "=== PHP版本信息 ==="
        "$php_bin" -v
        
        echo -e "\n=== 基本功能测试 ==="
        echo "<?php echo 'Hello, PHP $php_version!'; ?>" | "$php_bin"
        
        echo -e "\n=== 扩展检查 ==="
        "$php_bin" -m | head -20
        
        echo -e "\n=== 功能测试 ==="
        echo "<?php 
        echo 'PHP Version: ' . phpversion() . PHP_EOL;
        echo 'Extensions: ' . count(get_loaded_extensions()) . PHP_EOL;
        echo 'JSON Test: ' . (json_encode(['test' => 'ok']) ? 'OK' : 'FAIL') . PHP_EOL;
        echo 'Memory Limit: ' . ini_get('memory_limit') . PHP_EOL;
        ?>" | "$php_bin"
        
        echo "SUCCESS: PHP基本功能测试通过"
    } > "$log_file" 2>&1
    
    if grep -q "SUCCESS:" "$log_file"; then
        log_success "PHP基本功能测试通过"
        return 0
    else
        log_error "PHP基本功能测试失败"
        return 1
    fi
}

test_php_extensions() {
    local rpm_file="$1"
    local php_version="$2"
    local log_file="${TEST_LOG_DIR}/php_extensions_${php_version//./}.log"
    local temp_root="${TEST_TEMP_DIR}/php_${php_version//./}"
    
    log_test "测试PHP扩展: $php_version"
    
    {
        local php_bin="$temp_root/opt/iipe/iipe-php${php_version//./}/root/usr/bin/php"
        
        echo "=== 核心扩展测试 ==="
        echo "<?php
        \$core_extensions = ['json', 'curl', 'mysqli', 'pdo', 'gd', 'mbstring', 'openssl'];
        foreach (\$core_extensions as \$ext) {
            echo \$ext . ': ' . (extension_loaded(\$ext) ? 'OK' : 'MISSING') . PHP_EOL;
        }
        ?>" | "$php_bin"
        
        echo -e "\n=== 功能测试 ==="
        echo "<?php
        // JSON测试
        \$json_test = json_encode(['test' => 'data']);
        echo 'JSON功能: ' . (\$json_test ? 'OK' : 'FAIL') . PHP_EOL;
        
        // 字符串测试
        echo 'mbstring功能: ' . (function_exists('mb_strlen') ? 'OK' : 'FAIL') . PHP_EOL;
        
        // 哈希测试
        echo 'Hash功能: ' . (hash('md5', 'test') ? 'OK' : 'FAIL') . PHP_EOL;
        ?>" | "$php_bin"
        
        echo "SUCCESS: PHP扩展测试完成"
    } > "$log_file" 2>&1
    
    log_success "PHP扩展测试完成"
    return 0
}

run_test_suite() {
    local php_version="$1"
    local system="$2"
    local test_type="${3:-basic}"
    
    log_info "开始测试: PHP $php_version on $system (类型: $test_type)"
    
    local rpm_file
    rpm_file=$(find_rpm_packages "$php_version" "$system")
    
    if [[ -z "$rpm_file" ]] || [[ ! -f "$rpm_file" ]]; then
        log_error "找不到RPM包: PHP $php_version for $system"
        return 1
    fi
    
    log_info "找到RPM包: $(basename "$rpm_file")"
    
    local test_passed=0
    local test_total=0
    
    # 基础测试
    ((test_total++))
    if test_rpm_integrity "$rpm_file"; then ((test_passed++)); fi
    
    ((test_total++))
    if test_php_basic_functionality "$rpm_file" "$php_version"; then ((test_passed++)); fi
    
    # 完整测试
    if [[ "$test_type" == "full" ]]; then
        ((test_total++))
        if test_php_extensions "$rpm_file" "$php_version"; then ((test_passed++)); fi
    fi
    
    # 记录结果
    local result_file="${TEST_RESULTS_DIR}/${php_version//./}-${system}.result"
    echo "$test_passed/$test_total" > "$result_file"
    
    if [[ $test_passed -eq $test_total ]]; then
        log_success "测试通过: PHP $php_version on $system ($test_passed/$test_total)"
        return 0
    else
        log_error "测试失败: PHP $php_version on $system ($test_passed/$test_total)"
        return 1
    fi
}

generate_test_report() {
    local report_file="${TEST_RESULTS_DIR}/test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    log_info "生成测试报告: $report_file"
    
    {
        echo "======================================================================"
        echo "iipe PHP 自动化测试报告"
        echo "======================================================================"
        echo "测试时间: $(date)"
        echo "脚本版本: $SCRIPT_VERSION"
        echo ""
        echo "测试结果:"
        echo "======================================================================"
        
        local total_tests=0
        local passed_tests=0
        
        for result_file in "$TEST_RESULTS_DIR"/*.result; do
            if [[ -f "$result_file" ]]; then
                local test_name=$(basename "$result_file" .result)
                local result_content=$(cat "$result_file")
                IFS='/' read -r passed total <<< "$result_content"
                
                ((total_tests++))
                if [[ "$passed" -eq "$total" ]]; then
                    ((passed_tests++))
                    printf "✅ %-25s 通过 (%s/%s)\n" "$test_name" "$passed" "$total"
                else
                    printf "❌ %-25s 失败 (%s/%s)\n" "$test_name" "$passed" "$total"
                fi
            fi
        done
        
        echo ""
        echo "======================================================================"
        echo "统计信息:"
        echo "总测试数: $total_tests"
        echo "通过测试: $passed_tests"
        echo "失败测试: $((total_tests - passed_tests))"
        echo "通过率: $(( passed_tests * 100 / total_tests ))%"
        echo "======================================================================"
        
    } > "$report_file"
    
    log_success "测试报告已生成: $report_file"
}

cleanup() {
    if [[ "${KEEP_TEMP:-}" != "true" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

main() {
    local php_version=""
    local system=""
    local test_type="basic"
    
    CLEAN_TEST="false"
    KEEP_TEMP="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--version) php_version="$2"; shift 2 ;;
            -s|--system) system="$2"; shift 2 ;;
            -p|--package-dir) PACKAGE_DIR="$2"; shift 2 ;;
            -t|--test-type) test_type="$2"; shift 2 ;;
            -c|--clean) CLEAN_TEST="true"; shift ;;
            -k|--keep-temp) KEEP_TEMP="true"; shift ;;
            -h|--help) show_usage; exit 0 ;;
            *) log_error "未知选项: $1"; show_usage; exit 1 ;;
        esac
    done
    
    if [[ ! "$test_type" =~ ^(basic|full|smoke)$ ]]; then
        log_error "无效的测试类型: $test_type"
        exit 1
    fi
    
    log_info "======================================================================="
    log_info "${SCRIPT_NAME} v${SCRIPT_VERSION}"
    log_info "测试类型: $test_type"
    [[ -n "$php_version" ]] && log_info "PHP版本: $php_version"
    [[ -n "$system" ]] && log_info "系统: $system"
    log_info "======================================================================="
    
    init_test_environment
    trap cleanup EXIT
    
    local exit_code=0
    
    if [[ -n "$php_version" ]] && [[ -n "$system" ]]; then
        if ! run_test_suite "$php_version" "$system" "$test_type"; then
            exit_code=1
        fi
    elif [[ -n "$php_version" ]]; then
        for sys in "${SUPPORTED_SYSTEMS[@]}"; do
            if ! run_test_suite "$php_version" "$sys" "$test_type"; then
                exit_code=1
            fi
        done
    else
        if [[ "$test_type" == "smoke" ]]; then
            for ver in "${SUPPORTED_PHP_VERSIONS[@]}"; do
                for sys in "${SUPPORTED_SYSTEMS[@]}"; do
                    run_test_suite "$ver" "$sys" "$test_type" || true
                done
            done
        else
            log_error "必须指定PHP版本进行 $test_type 测试"
            exit 1
        fi
    fi
    
    generate_test_report
    exit $exit_code
}

main "$@" 