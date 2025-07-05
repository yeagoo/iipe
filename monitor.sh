#!/bin/bash

# iipe 监控系统
# 用于监控构建过程、仓库状态和系统健康

set -e

# 配置
LOG_DIR="logs/monitor"
METRICS_DIR="metrics"
DEFAULT_CHECK_INTERVAL=300

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

# 显示用法
show_usage() {
    echo "iipe 监控系统"
    echo ""
    echo "用法: $0 [command]"
    echo ""
    echo "命令:"
    echo "  status           显示系统状态总览"
    echo "  check-builds     检查构建状态"
    echo "  check-repos      检查仓库健康状态"
    echo "  check-disk       检查磁盘使用情况"
    echo "  start-daemon     启动监控守护进程"
    echo "  stop-daemon      停止监控守护进程"
    echo "  generate-report  生成监控报告"
    echo "  cleanup          清理过期日志"
    echo ""
}

# 初始化监控目录
init_monitoring() {
    mkdir -p "$LOG_DIR" "$METRICS_DIR" "reports" "alerts"
}

# 记录指标
record_metric() {
    local metric_name="$1"
    local metric_value="$2"
    local timestamp=$(date '+%s')
    local date_str=$(date '+%Y-%m-%d')
    
    echo "$timestamp,$metric_value" >> "$METRICS_DIR/${metric_name}_${date_str}.csv"
}

# 系统状态总览
show_status() {
    clear
    echo "=================================="
    echo "    iipe 系统监控状态总览"
    echo "=================================="
    echo ""
    
    print_info "系统信息:"
    echo "  主机名: $(hostname)"
    echo "  当前时间: $(date)"
    echo ""
    
    check_builds_status
    check_repos_status
    check_disk_usage
}

# 检查构建状态
check_builds_status() {
    print_info "构建状态检查:"
    
    local build_count=0
    local success_count=0
    local failed_count=0
    
    if [ -d "repo_output" ]; then
        for system_dir in repo_output/*/; do
            if [ -d "$system_dir" ]; then
                system_name=$(basename "$system_dir")
                rpm_count=$(find "$system_dir" -name "*.rpm" 2>/dev/null | wc -l)
                
                build_count=$((build_count + 1))
                if [ "$rpm_count" -gt 0 ]; then
                    success_count=$((success_count + 1))
                    echo "  ✅ $system_name: $rpm_count RPM包"
                else
                    failed_count=$((failed_count + 1))
                    echo "  ❌ $system_name: 无RPM包"
                fi
            fi
        done
    fi
    
    echo "  总系统数: $build_count, 成功: $success_count, 失败: $failed_count"
    
    record_metric "builds_total" "$build_count"
    record_metric "builds_success" "$success_count"
    record_metric "builds_failed" "$failed_count"
    
    echo ""
}

# 检查仓库健康状态
check_repos_status() {
    print_info "仓库健康状态检查:"
    
    local repo_count=0
    local healthy_count=0
    
    if [ -d "repo_output" ]; then
        for system_dir in repo_output/*/; do
            if [ -d "$system_dir" ]; then
                system_name=$(basename "$system_dir")
                repo_count=$((repo_count + 1))
                
                if [ -d "$system_dir/repodata" ] && [ -f "$system_dir/repodata/repomd.xml" ]; then
                    healthy_count=$((healthy_count + 1))
                    echo "  ✅ $system_name: 仓库元数据正常"
                else
                    echo "  ❌ $system_name: 仓库元数据缺失"
                fi
            fi
        done
    fi
    
    echo "  总仓库数: $repo_count, 健康: $healthy_count"
    record_metric "repos_healthy" "$healthy_count"
    echo ""
}

# 检查磁盘使用情况
check_disk_usage() {
    print_info "磁盘使用情况检查:"
    
    df -h | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{print $5 " " $6}' | while read output; do
        usage=$(echo $output | awk '{print $1}' | sed 's/%//g')
        mount_point=$(echo $output | awk '{print $2}')
        
        if [ $usage -ge 90 ]; then
            print_error "磁盘空间严重不足: $mount_point ($usage%)"
        elif [ $usage -ge 80 ]; then
            print_warning "磁盘空间不足: $mount_point ($usage%)"
        else
            echo "  ✅ $mount_point: $usage%"
        fi
        
        mount_name=$(echo "$mount_point" | sed 's/\//_/g' | sed 's/^_//')
        record_metric "disk_usage_${mount_name:-root}" "$usage"
    done
    echo ""
}

# 启动监控守护进程
start_daemon() {
    local pidfile="monitor.pid"
    local interval="${1:-$DEFAULT_CHECK_INTERVAL}"
    
    if [ -f "$pidfile" ] && kill -0 "$(cat $pidfile)" 2>/dev/null; then
        print_error "监控守护进程已在运行 (PID: $(cat $pidfile))"
        exit 1
    fi
    
    print_info "启动监控守护进程 (检查间隔: ${interval}秒)"
    
    {
        while true; do
            {
                echo "=== 监控检查: $(date) ==="
                check_builds_status
                check_repos_status
                check_disk_usage
                echo ""
            } >> "$LOG_DIR/monitor_$(date '+%Y%m%d').log" 2>&1
            
            sleep "$interval"
        done
    } &
    
    echo $! > "$pidfile"
    print_success "监控守护进程已启动 (PID: $!)"
}

# 停止监控守护进程
stop_daemon() {
    local pidfile="monitor.pid"
    
    if [ -f "$pidfile" ]; then
        local pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$pidfile"
            print_success "监控守护进程已停止"
        else
            print_warning "监控守护进程未运行"
            rm -f "$pidfile"
        fi
    else
        print_warning "未找到监控守护进程"
    fi
}

# 生成监控报告
generate_report() {
    local report_file="reports/monitor_report_$(date '+%Y%m%d_%H%M%S').html"
    
    print_info "正在生成监控报告: $report_file"
    
    cat > "$report_file" <<REPORT_EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>iipe 监控报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .metric { margin: 10px 0; padding: 10px; border-left: 4px solid #007acc; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🐘 iipe PHP 仓库监控报告</h1>
        <p>生成时间: $(date)</p>
        <p>主机: $(hostname)</p>
    </div>

    <h2>📊 当前状态</h2>
    <div class="metric">
        <pre>$(show_status 2>&1 | sed 's/\x1b\[[0-9;]*m//g')</pre>
    </div>
    
    <h2>📈 最近指标</h2>
    <div class="metric">
        <p>指标数据存储在 metrics/ 目录中</p>
    </div>
</body>
</html>
REPORT_EOF

    print_success "监控报告已生成: $report_file"
}

# 清理过期数据
cleanup() {
    local retention_days="${1:-30}"
    
    print_info "清理 $retention_days 天前的监控数据..."
    
    find "$LOG_DIR" -name "*.log" -mtime +$retention_days -delete 2>/dev/null || true
    find "$METRICS_DIR" -name "*.csv" -mtime +$retention_days -delete 2>/dev/null || true
    find "reports" -name "*.html" -mtime +$retention_days -delete 2>/dev/null || true
    
    print_success "数据清理完成"
}

# 主函数
main() {
    init_monitoring
    
    case "${1:-status}" in
        "status")
            show_status
            ;;
        "check-builds")
            check_builds_status
            ;;
        "check-repos")
            check_repos_status
            ;;
        "check-disk")
            check_disk_usage
            ;;
        "start-daemon")
            start_daemon "$2"
            ;;
        "stop-daemon")
            stop_daemon
            ;;
        "generate-report")
            generate_report
            ;;
        "cleanup")
            cleanup "$2"
            ;;
        "-h"|"--help")
            show_usage
            ;;
        *)
            print_error "未知命令: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
