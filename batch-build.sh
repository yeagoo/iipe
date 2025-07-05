#!/bin/bash

# =============================================================================
# iipe PHP 批量构建脚本 (Batch Build Script)
# 
# 功能：
# - 支持多PHP版本批量构建
# - 支持多操作系统批量构建  
# - 并行构建支持
# - 构建状态监控
# - 失败重试机制
# - 构建结果汇总
# =============================================================================

set -euo pipefail

# 脚本信息
SCRIPT_NAME="iipe PHP Batch Build"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 配置变量
readonly BUILD_LOG_DIR="${SCRIPT_DIR}/logs/batch-build"
readonly BUILD_RESULTS_DIR="${SCRIPT_DIR}/build-results"
readonly DEFAULT_PARALLEL_JOBS=4
readonly DEFAULT_RETRY_COUNT=2

# 支持的版本和系统
readonly SUPPORTED_PHP_VERSIONS=("7.4" "8.0" "8.1" "8.2" "8.3" "8.4" "8.5")
readonly SUPPORTED_SYSTEMS=(
    "almalinux-9" "almalinux-10"
    "oracle-linux-9" "oracle-linux-10"
    "rocky-linux-9" "rocky-linux-10"
    "rhel-9" "rhel-10"
    "centos-stream-9" "centos-stream-10"
    "openeuler-24.03" "openanolis-23" "opencloudos-9"
)
readonly SUPPORTED_ARCHITECTURES=("x86_64" "aarch64")

# 颜色定义
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${COLOR_BLUE}[INFO]${COLOR_NC} $*" >&1
}

log_warn() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${COLOR_YELLOW}[WARN]${COLOR_NC} $*" >&2
}

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${COLOR_RED}[ERROR]${COLOR_NC} $*" >&2
}

log_success() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${COLOR_GREEN}[SUCCESS]${COLOR_NC} $*" >&1
}

# 显示使用说明
show_usage() {
    cat << EOF
${COLOR_CYAN}${SCRIPT_NAME} v${SCRIPT_VERSION}${COLOR_NC}

用法: $0 [选项]

选项:
    -v, --versions VERSION1,VERSION2,...    指定PHP版本 (默认: 所有版本)
    -s, --systems SYSTEM1,SYSTEM2,...       指定构建系统 (默认: 所有系统)
    -a, --architectures ARCH1,ARCH2,...     指定目标架构 (默认: 所有架构)
    -j, --jobs NUMBER                        并行任务数 (默认: ${DEFAULT_PARALLEL_JOBS})
    -r, --retry NUMBER                       失败重试次数 (默认: ${DEFAULT_RETRY_COUNT})
    -c, --clean                              构建前清理旧文件
    -d, --dry-run                           只显示将要执行的任务，不实际构建
    -q, --quiet                             静默模式，减少输出
    --skip-pecl                             跳过PECL扩展构建
    --pecl-only                             仅构建PECL扩展(需要PHP核心包已存在)
    -h, --help                              显示此帮助信息

支持的PHP版本:
    ${SUPPORTED_PHP_VERSIONS[*]}

支持的系统:
    ${SUPPORTED_SYSTEMS[*]}

支持的架构:
    ${SUPPORTED_ARCHITECTURES[*]}

PECL扩展支持:
    默认情况下会在PHP核心构建成功后自动构建PECL扩展
    支持的扩展: redis, mongodb, xdebug, imagick, yaml, apcu

示例:
    # 构建所有版本和系统(包含PECL扩展)
    $0

    # 构建特定PHP版本
    $0 -v 8.1,8.2,8.3

    # 构建特定系统
    $0 -s almalinux-9,rocky-linux-9

    # 构建特定架构
    $0 -a x86_64,aarch64

    # 构建特定架构的特定版本
    $0 -v 8.3 -s almalinux-9 -a aarch64

    # 并行构建，4个任务
    $0 -j 4

    # 构建前清理，失败重试3次
    $0 -c -r 3

    # 跳过PECL扩展，仅构建PHP核心
    $0 --skip-pecl

    # 仅构建PECL扩展(PHP核心包已存在)
    $0 --pecl-only -v 8.1 -s almalinux-9 -a x86_64

EOF
}

# 验证版本有效性
validate_versions() {
    local versions_str="$1"
    local valid_versions=()
    
    IFS=',' read -ra versions <<< "$versions_str"
    for version in "${versions[@]}"; do
        version=$(echo "$version" | tr -d ' ')
        if [[ " ${SUPPORTED_PHP_VERSIONS[*]} " =~ " ${version} " ]]; then
            valid_versions+=("$version")
        else
            log_error "不支持的PHP版本: $version"
            exit 1
        fi
    done
    
    echo "${valid_versions[@]}"
}

# 验证系统有效性
validate_systems() {
    local systems_str="$1"
    local valid_systems=()
    
    IFS=',' read -ra systems <<< "$systems_str"
    for system in "${systems[@]}"; do
        system=$(echo "$system" | tr -d ' ')
        if [[ " ${SUPPORTED_SYSTEMS[*]} " =~ " ${system} " ]]; then
            valid_systems+=("$system")
        else
            log_error "不支持的系统: $system"
            exit 1
        fi
    done
    
    echo "${valid_systems[@]}"
}

# 验证架构有效性
validate_architectures() {
    local architectures_str="$1"
    local valid_architectures=()
    
    IFS=',' read -ra architectures <<< "$architectures_str"
    for arch in "${architectures[@]}"; do
        arch=$(echo "$arch" | tr -d ' ')
        if [[ " ${SUPPORTED_ARCHITECTURES[*]} " =~ " ${arch} " ]]; then
            valid_architectures+=("$arch")
        else
            log_error "不支持的架构: $arch"
            exit 1
        fi
    done
    
    echo "${valid_architectures[@]}"
}

# 初始化目录
init_directories() {
    mkdir -p "$BUILD_LOG_DIR"
    mkdir -p "$BUILD_RESULTS_DIR"
    
    if [[ "${CLEAN_BUILD:-}" == "true" ]]; then
        log_info "清理旧的构建文件..."
        rm -rf "${BUILD_LOG_DIR:?}"/*
        rm -rf "${BUILD_RESULTS_DIR:?}"/*
    fi
}

# 单个构建任务
build_single_task() {
    local php_version="$1"
    local system="$2"
    local architecture="$3"
    local task_id="${php_version}-${system}-${architecture}"
    local log_file="${BUILD_LOG_DIR}/${task_id}.log"
    local result_file="${BUILD_RESULTS_DIR}/${task_id}.result"
    
    local start_time=$(date +%s)
    local attempt=1
    local max_attempts=$((RETRY_COUNT + 1))
    
    while [[ $attempt -le $max_attempts ]]; do
        if [[ $attempt -gt 1 ]]; then
            log_warn "重试构建 $task_id (第 $attempt 次尝试)"
        fi
        
        # 执行PHP核心构建
        if [[ "${QUIET_MODE:-}" != "true" ]]; then
            log_info "开始构建: PHP $php_version on $system $architecture (尝试 $attempt/$max_attempts)"
        fi
        
        if ./build.sh "$php_version" "$system" "$architecture" &> "$log_file"; then
            # PHP核心构建成功，继续构建PECL扩展
            if [[ "${BUILD_PECL_EXTENSIONS:-true}" == "true" ]]; then
                if [[ "${QUIET_MODE:-}" != "true" ]]; then
                    log_info "开始构建PECL扩展: PHP $php_version on $system $architecture"
                fi
                
                # 构建PECL扩展
                if build_pecl_extensions_for_task "$php_version" "$system" "$architecture" "$log_file"; then
                    local end_time=$(date +%s)
                    local duration=$((end_time - start_time))
                    
                    echo "SUCCESS|$duration|$attempt|with_pecl" > "$result_file"
                    
                    if [[ "${QUIET_MODE:-}" != "true" ]]; then
                        log_success "构建成功: PHP $php_version on $system $architecture (含PECL扩展, 耗时: ${duration}s)"
                    fi
                    return 0
                else
                    # PECL扩展构建失败，但PHP核心构建成功
                    local end_time=$(date +%s)
                    local duration=$((end_time - start_time))
                    
                    echo "PARTIAL|$duration|$attempt|php_only" > "$result_file"
                    
                    if [[ "${QUIET_MODE:-}" != "true" ]]; then
                        log_warn "部分成功: PHP $php_version on $system $architecture (PHP核心成功, PECL扩展失败, 耗时: ${duration}s)"
                    fi
                    return 0
                fi
            else
                # 仅构建PHP核心
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                
                echo "SUCCESS|$duration|$attempt|php_only" > "$result_file"
                
                if [[ "${QUIET_MODE:-}" != "true" ]]; then
                    log_success "构建成功: PHP $php_version on $system $architecture (仅PHP核心, 耗时: ${duration}s)"
                fi
                return 0
            fi
        else
            # PHP核心构建失败
            if [[ $attempt -lt $max_attempts ]]; then
                log_warn "构建失败，准备重试: PHP $php_version on $system $architecture"
                ((attempt++))
                sleep 2
            else
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                
                echo "FAILED|$duration|$attempt|none" > "$result_file"
                log_error "构建失败: PHP $php_version on $system $architecture (耗时: ${duration}s)"
                return 1
            fi
        fi
    done
}

# 为特定任务构建PECL扩展
build_pecl_extensions_for_task() {
    local php_version="$1"
    local system="$2"
    local architecture="$3"
    local log_file="$4"
    
    # 检查PECL扩展管理器是否存在
    if [[ ! -x "${SCRIPT_DIR}/pecl-extension-manager.sh" ]]; then
        echo "PECL扩展管理器不存在，跳过PECL扩展构建" >> "$log_file"
        return 0
    fi
    
    # 获取可用的PECL扩展列表
    local extensions=($(${SCRIPT_DIR}/pecl-extension-manager.sh list-extensions 2>/dev/null | grep -v "可用的PECL扩展" | grep -v "扩展名" | grep -v "-----" | awk '{print $1}' | grep -v "^$"))
    
    if [[ ${#extensions[@]} -eq 0 ]]; then
        echo "没有找到可用的PECL扩展" >> "$log_file"
        return 0
    fi
    
    echo "开始构建PECL扩展: ${extensions[*]}" >> "$log_file"
    
    local pecl_success_count=0
    local pecl_total_count=${#extensions[@]}
    
    # 逐个构建扩展
    for extension in "${extensions[@]}"; do
        echo "构建PECL扩展: $extension for PHP $php_version on $system $architecture" >> "$log_file"
        
        if ${SCRIPT_DIR}/pecl-extension-manager.sh build -e "$extension" -p "$php_version" -s "$system" -a "$architecture" >> "$log_file" 2>&1; then
            echo "PECL扩展构建成功: $extension" >> "$log_file"
            ((pecl_success_count++))
        else
            echo "PECL扩展构建失败: $extension" >> "$log_file"
        fi
    done
    
    echo "PECL扩展构建汇总: $pecl_success_count/$pecl_total_count 成功" >> "$log_file"
    
    # 如果至少有一半的扩展构建成功，认为构建成功
    if [[ $pecl_success_count -ge $((pecl_total_count / 2)) ]]; then
        return 0
    else
        return 1
    fi
}

# 并行构建任务
execute_parallel_builds() {
    local php_versions=($1)
    local systems=($2)
    local architectures=($3)
    local total_tasks=$((${#php_versions[@]} * ${#systems[@]} * ${#architectures[@]}))
    local completed_tasks=0
    local failed_tasks=0
    
    log_info "开始批量构建: ${#php_versions[@]} 个PHP版本 × ${#systems[@]} 个系统 × ${#architectures[@]} 个架构 = $total_tasks 个任务"
    log_info "并行任务数: $PARALLEL_JOBS"
    
    # 创建任务队列
    local tasks=()
    for php_version in "${php_versions[@]}"; do
        for system in "${systems[@]}"; do
            for architecture in "${architectures[@]}"; do
                tasks+=("$php_version|$system|$architecture")
            done
        done
    done
    
    # 执行并行构建
    local active_jobs=()
    local task_index=0
    
    while [[ $task_index -lt ${#tasks[@]} ]] || [[ ${#active_jobs[@]} -gt 0 ]]; do
        # 启动新任务（如果有空闲槽位）
        while [[ ${#active_jobs[@]} -lt $PARALLEL_JOBS ]] && [[ $task_index -lt ${#tasks[@]} ]]; do
            local task="${tasks[$task_index]}"
            IFS='|' read -r php_version system architecture <<< "$task"
            
            if [[ "${DRY_RUN:-}" == "true" ]]; then
                echo "DRY-RUN: 将构建 PHP $php_version on $system $architecture"
                ((task_index++))
                continue
            fi
            
            # 后台启动构建任务
            (build_single_task "$php_version" "$system" "$architecture") &
            local job_pid=$!
            active_jobs+=("$job_pid|$php_version|$system|$architecture")
            
            ((task_index++))
        done
        
        # 检查完成的任务
        local new_active_jobs=()
        for job_info in "${active_jobs[@]:-}"; do
            if [[ -n "$job_info" ]]; then
                IFS='|' read -r job_pid php_version system architecture <<< "$job_info"
                
                if ! kill -0 "$job_pid" 2>/dev/null; then
                    # 任务已完成
                    wait "$job_pid"
                    local exit_code=$?
                    
                    ((completed_tasks++))
                    if [[ $exit_code -ne 0 ]]; then
                        ((failed_tasks++))
                    fi
                    
                    # 显示进度
                    local progress=$((completed_tasks * 100 / total_tasks))
                    log_info "进度: $completed_tasks/$total_tasks ($progress%) [成功: $((completed_tasks - failed_tasks)), 失败: $failed_tasks]"
                else
                    # 任务仍在运行
                    new_active_jobs+=("$job_info")
                fi
            fi
        done
        active_jobs=("${new_active_jobs[@]:-}")
        
        # 短暂休眠避免CPU占用过高
        sleep 1
    done
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        log_info "DRY-RUN 完成: 总共 $total_tasks 个任务"
        return 0
    fi
    
    log_info "批量构建完成: 总共 $total_tasks 个任务, 成功 $((completed_tasks - failed_tasks)) 个, 失败 $failed_tasks 个"
    
    if [[ $failed_tasks -gt 0 ]]; then
        return 1
    fi
    return 0
}

# 生成构建报告
generate_build_report() {
    local report_file="${BUILD_RESULTS_DIR}/build-report-$(date +%Y%m%d-%H%M%S).txt"
    
    log_info "生成构建报告: $report_file"
    
    cat > "$report_file" << EOF
======================================================================
iipe PHP 批量构建报告
======================================================================
构建时间: $(date)
脚本版本: $SCRIPT_VERSION

配置信息:
- PHP版本: ${PHP_VERSIONS[*]}
- 构建系统: ${BUILD_SYSTEMS[*]}
- 构建架构: ${BUILD_ARCHITECTURES[*]}
- 并行任务数: $PARALLEL_JOBS
- 重试次数: $RETRY_COUNT

======================================================================
构建结果汇总:
======================================================================

EOF

    local total_tasks=0
    local successful_tasks=0
    local failed_tasks=0
    local total_duration=0

    # 统计结果
    for result_file in "$BUILD_RESULTS_DIR"/*.result; do
        if [[ -f "$result_file" ]]; then
            local task_name=$(basename "$result_file" .result)
            local result_content=$(cat "$result_file")
            IFS='|' read -r status duration attempts <<< "$result_content"
            
            ((total_tasks++))
            total_duration=$((total_duration + duration))
            
            if [[ "$status" == "SUCCESS" ]]; then
                ((successful_tasks++))
                printf "✅ %-25s 成功 (耗时: %3ds, 尝试: %d次)\n" "$task_name" "$duration" "$attempts" >> "$report_file"
            else
                ((failed_tasks++))
                printf "❌ %-25s 失败 (耗时: %3ds, 尝试: %d次)\n" "$task_name" "$duration" "$attempts" >> "$report_file"
            fi
        fi
    done

    # 汇总统计
    cat >> "$report_file" << EOF

======================================================================
统计信息:
======================================================================
总任务数: $total_tasks
成功任务: $successful_tasks
失败任务: $failed_tasks
成功率: $(( successful_tasks * 100 / total_tasks ))%
总耗时: $total_duration 秒
平均耗时: $(( total_duration / total_tasks )) 秒/任务

EOF

    if [[ $failed_tasks -gt 0 ]]; then
        cat >> "$report_file" << EOF
======================================================================
失败任务详情:
======================================================================

EOF
        for result_file in "$BUILD_RESULTS_DIR"/*.result; do
            if [[ -f "$result_file" ]]; then
                local task_name=$(basename "$result_file" .result)
                local result_content=$(cat "$result_file")
                IFS='|' read -r status duration attempts <<< "$result_content"
                
                if [[ "$status" == "FAILED" ]]; then
                    echo "任务: $task_name" >> "$report_file"
                    echo "日志文件: ${BUILD_LOG_DIR}/${task_name}.log" >> "$report_file"
                    echo "错误摘要:" >> "$report_file"
                    tail -n 10 "${BUILD_LOG_DIR}/${task_name}.log" >> "$report_file"
                    echo "" >> "$report_file"
                fi
            fi
        done
    fi

    log_success "构建报告已生成: $report_file"
    
    # 显示简要汇总
    echo
    log_info "======================================================================="
    log_info "构建汇总: $successful_tasks/$total_tasks 任务成功, 耗时 $total_duration 秒"
    if [[ $failed_tasks -gt 0 ]]; then
        log_error "有 $failed_tasks 个任务失败，详情请查看构建报告"
    else
        log_success "🎉 所有构建任务都成功完成！"
    fi
    log_info "======================================================================="
}

# 仅构建PECL扩展
execute_pecl_only_builds() {
    local php_versions=($1)
    local systems=($2)
    local architectures=($3)
    local total_tasks=$((${#php_versions[@]} * ${#systems[@]} * ${#architectures[@]}))
    local completed_tasks=0
    local failed_tasks=0
    
    log_info "开始仅构建PECL扩展: ${#php_versions[@]} 个PHP版本 × ${#systems[@]} 个系统 × ${#architectures[@]} 个架构 = $total_tasks 个任务"
    log_info "并行任务数: $PARALLEL_JOBS"
    
    # 创建任务队列
    local tasks=()
    for php_version in "${php_versions[@]}"; do
        for system in "${systems[@]}"; do
            for architecture in "${architectures[@]}"; do
                tasks+=("$php_version|$system|$architecture")
            done
        done
    done
    
    # 执行并行构建
    local active_jobs=()
    local task_index=0
    
    while [[ $task_index -lt ${#tasks[@]} ]] || [[ ${#active_jobs[@]:-0} -gt 0 ]]; do
        # 启动新任务（如果有空闲槽位）
        while [[ ${#active_jobs[@]:-0} -lt $PARALLEL_JOBS ]] && [[ $task_index -lt ${#tasks[@]} ]]; do
            local task="${tasks[$task_index]}"
            IFS='|' read -r php_version system architecture <<< "$task"
            
            if [[ "${DRY_RUN:-}" == "true" ]]; then
                echo "DRY-RUN: 将构建PECL扩展 for PHP $php_version on $system $architecture"
                ((task_index++))
                continue
            fi
            
            # 后台启动PECL扩展构建任务
            (build_pecl_only_task "$php_version" "$system" "$architecture") &
            local job_pid=$!
            active_jobs+=("$job_pid|$php_version|$system|$architecture")
            
            ((task_index++))
        done
        
        # 检查完成的任务
        local new_active_jobs=()
        for job_info in "${active_jobs[@]:-}"; do
            if [[ -n "$job_info" ]]; then
                IFS='|' read -r job_pid php_version system architecture <<< "$job_info"
                
                if ! kill -0 "$job_pid" 2>/dev/null; then
                    # 任务已完成
                    wait "$job_pid"
                    local exit_code=$?
                    
                    ((completed_tasks++))
                    if [[ $exit_code -ne 0 ]]; then
                        ((failed_tasks++))
                    fi
                    
                    # 显示进度
                    local progress=$((completed_tasks * 100 / total_tasks))
                    log_info "进度: $completed_tasks/$total_tasks ($progress%) [成功: $((completed_tasks - failed_tasks)), 失败: $failed_tasks]"
                else
                    # 任务仍在运行
                    new_active_jobs+=("$job_info")
                fi
            fi
        done
        active_jobs=("${new_active_jobs[@]:-}")
        
        # 短暂休眠避免CPU占用过高
        sleep 1
    done
    
    if [[ "${DRY_RUN:-}" == "true" ]]; then
        log_info "DRY-RUN 完成: 总共 $total_tasks 个PECL扩展构建任务"
        return 0
    fi
    
    log_info "PECL扩展批量构建完成: 总共 $total_tasks 个任务, 成功 $((completed_tasks - failed_tasks)) 个, 失败 $failed_tasks 个"
    
    if [[ $failed_tasks -gt 0 ]]; then
        return 1
    fi
    return 0
}

# 仅构建PECL扩展任务
build_pecl_only_task() {
    local php_version="$1"
    local system="$2"
    local architecture="$3"
    local task_id="pecl-${php_version}-${system}-${architecture}"
    local log_file="${BUILD_LOG_DIR}/${task_id}.log"
    local result_file="${BUILD_RESULTS_DIR}/${task_id}.result"
    
    local start_time=$(date +%s)
    
    if [[ "${QUIET_MODE:-}" != "true" ]]; then
        log_info "开始构建PECL扩展: PHP $php_version on $system $architecture"
    fi
    
    # 构建PECL扩展
    if build_pecl_extensions_for_task "$php_version" "$system" "$architecture" "$log_file"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        echo "SUCCESS|$duration|1|pecl_only" > "$result_file"
        
        if [[ "${QUIET_MODE:-}" != "true" ]]; then
            log_success "PECL扩展构建成功: PHP $php_version on $system $architecture (耗时: ${duration}s)"
        fi
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        echo "FAILED|$duration|1|pecl_only" > "$result_file"
        log_error "PECL扩展构建失败: PHP $php_version on $system $architecture (耗时: ${duration}s)"
        return 1
    fi
}

# 主函数
main() {
    local php_versions_str=""
    local systems_str=""
    local architectures_str=""
    
    # 设置默认值
    PARALLEL_JOBS="$DEFAULT_PARALLEL_JOBS"
    RETRY_COUNT="$DEFAULT_RETRY_COUNT"
    CLEAN_BUILD="false"
    DRY_RUN="false"
    QUIET_MODE="false"
    BUILD_PECL_EXTENSIONS="true"
    PECL_ONLY_MODE="false"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--versions)
                php_versions_str="$2"
                shift 2
                ;;
            -s|--systems)
                systems_str="$2"
                shift 2
                ;;
            -a|--architectures)
                architectures_str="$2"
                shift 2
                ;;
            -j|--jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            -r|--retry)
                RETRY_COUNT="$2"
                shift 2
                ;;
            -c|--clean)
                CLEAN_BUILD="true"
                shift
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -q|--quiet)
                QUIET_MODE="true"
                shift
                ;;
            --skip-pecl)
                BUILD_PECL_EXTENSIONS="false"
                shift
                ;;
            --pecl-only)
                PECL_ONLY_MODE="true"
                BUILD_PECL_EXTENSIONS="true"
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
    
    # 验证并设置版本
    if [[ -n "$php_versions_str" ]]; then
        read -ra PHP_VERSIONS <<< "$(validate_versions "$php_versions_str")"
    else
        PHP_VERSIONS=("${SUPPORTED_PHP_VERSIONS[@]}")
    fi
    
    # 验证并设置系统
    if [[ -n "$systems_str" ]]; then
        read -ra BUILD_SYSTEMS <<< "$(validate_systems "$systems_str")"
    else
        BUILD_SYSTEMS=("${SUPPORTED_SYSTEMS[@]}")
    fi
    
    # 验证并设置架构
    if [[ -n "$architectures_str" ]]; then
        read -ra BUILD_ARCHITECTURES <<< "$(validate_architectures "$architectures_str")"
    else
        BUILD_ARCHITECTURES=("${SUPPORTED_ARCHITECTURES[@]}")
    fi
    
    # 验证并行任务数
    if ! [[ "$PARALLEL_JOBS" =~ ^[1-9][0-9]*$ ]] || [[ "$PARALLEL_JOBS" -gt 20 ]]; then
        log_error "并行任务数必须是1-20之间的整数"
        exit 1
    fi
    
    # 验证重试次数
    if ! [[ "$RETRY_COUNT" =~ ^[0-9]+$ ]] || [[ "$RETRY_COUNT" -gt 10 ]]; then
        log_error "重试次数必须是0-10之间的整数"
        exit 1
    fi
    
    # 检查脚本依赖
    if [[ "$PECL_ONLY_MODE" == "false" ]]; then
        # 检查build.sh脚本是否存在
        if [[ ! -x "${SCRIPT_DIR}/build.sh" ]]; then
            log_error "构建脚本 build.sh 不存在或不可执行"
            exit 1
        fi
    fi
    
    if [[ "$BUILD_PECL_EXTENSIONS" == "true" ]] || [[ "$PECL_ONLY_MODE" == "true" ]]; then
        # 检查PECL扩展管理器是否存在
        if [[ ! -x "${SCRIPT_DIR}/pecl-extension-manager.sh" ]]; then
            log_error "PECL扩展管理器 pecl-extension-manager.sh 不存在或不可执行"
            exit 1
        fi
    fi
    
    # 显示配置信息
    log_info "======================================================================="
    log_info "${SCRIPT_NAME} v${SCRIPT_VERSION}"
    log_info "======================================================================="
    log_info "PHP版本: ${PHP_VERSIONS[*]}"
    log_info "构建系统: ${BUILD_SYSTEMS[*]}"
    log_info "构建架构: ${BUILD_ARCHITECTURES[*]}"
    log_info "并行任务数: $PARALLEL_JOBS"
    log_info "重试次数: $RETRY_COUNT"
    log_info "清理构建: $CLEAN_BUILD"
    log_info "DRY-RUN模式: $DRY_RUN"
    log_info "静默模式: $QUIET_MODE"
    log_info "构建PECL扩展: $BUILD_PECL_EXTENSIONS"
    log_info "仅构建PECL扩展: $PECL_ONLY_MODE"
    log_info "======================================================================="
    
    # 初始化目录
    init_directories
    
    # 执行批量构建
    if [[ "$PECL_ONLY_MODE" == "true" ]]; then
        if execute_pecl_only_builds "${PHP_VERSIONS[*]}" "${BUILD_SYSTEMS[*]}" "${BUILD_ARCHITECTURES[*]}"; then
            if [[ "${DRY_RUN:-}" != "true" ]]; then
                generate_build_report
            fi
            exit 0
        else
            if [[ "${DRY_RUN:-}" != "true" ]]; then
                generate_build_report
            fi
            exit 1
        fi
    else
        if execute_parallel_builds "${PHP_VERSIONS[*]}" "${BUILD_SYSTEMS[*]}" "${BUILD_ARCHITECTURES[*]}"; then
            if [[ "${DRY_RUN:-}" != "true" ]]; then
                generate_build_report
            fi
            exit 0
        else
            if [[ "${DRY_RUN:-}" != "true" ]]; then
                generate_build_report
            fi
            exit 1
        fi
    fi
}

# 脚本入口
main "$@" 