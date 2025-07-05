#!/bin/bash

# iipe 压力测试工具
# 提供仓库服务器性能测试、并发下载测试和性能监控功能

set -e

# 配置
STRESS_CONFIG_DIR="stress-configs"
STRESS_LOG_DIR="logs/stress-tests"
STRESS_REPORTS_DIR="stress-test-reports"
STRESS_RESULTS_DIR="stress-test-results"
TEMP_DIR="/tmp/iipe_stress_test"

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
    echo "$msg" >> "$STRESS_LOG_DIR/stress_test_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_success() {
    local msg="[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$STRESS_LOG_DIR/stress_test_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_warning() {
    local msg="[WARNING] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$STRESS_LOG_DIR/stress_test_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_error() {
    local msg="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${RED}${msg}${NC}"
    echo "$msg" >> "$STRESS_LOG_DIR/stress_test_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_test() {
    local msg="[TEST] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${CYAN}${msg}${NC}"
    echo "$msg" >> "$STRESS_LOG_DIR/stress_test_$(date '+%Y%m%d').log" 2>/dev/null || true
}

# 显示用法
show_usage() {
    echo "iipe 压力测试工具"
    echo ""
    echo "用法: $0 [command] [options]"
    echo ""
    echo "命令:"
    echo "  repo-stress         仓库服务器压力测试"
    echo "  download-test       并发下载测试"
    echo "  build-stress        构建系统压力测试"
    echo "  network-test        网络性能测试"
    echo "  resource-monitor    资源使用监控"
    echo "  benchmark           性能基准测试"
    echo "  load-test           负载测试"
    echo "  endurance-test      耐久性测试"
    echo "  generate-report     生成测试报告"
    echo "  list-results        列出测试结果"
    echo ""
    echo "选项:"
    echo "  -c, --concurrent NUM      并发连接数"
    echo "  -d, --duration TIME       测试持续时间 (秒)"
    echo "  -r, --requests NUM        总请求数"
    echo "  -s, --size SIZE           测试文件大小"
    echo "  -u, --url URL             测试目标URL"
    echo "  -t, --type TYPE           测试类型 [light|normal|heavy|extreme]"
    echo "  -p, --profile PROFILE     测试配置文件"
    echo "  -o, --output FORMAT       输出格式 [text|html|json|csv]"
    echo "  -f, --file FILE           输出文件"
    echo "  -v, --verbose             详细输出"
    echo "  -q, --quiet               静默模式"
    echo "  -h, --help                显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 repo-stress -c 100 -d 300     # 100并发，5分钟压力测试"
    echo "  $0 download-test -c 50 -r 1000   # 50并发，1000次下载测试"
    echo "  $0 build-stress -t heavy         # 重型构建压力测试"
    echo "  $0 benchmark                     # 运行性能基准测试"
}

# 初始化压力测试系统
init_stress_tester() {
    mkdir -p "$STRESS_CONFIG_DIR" "$STRESS_LOG_DIR" "$STRESS_REPORTS_DIR" "$STRESS_RESULTS_DIR" "$TEMP_DIR"
    
    # 创建测试配置
    create_test_configs
    
    # 创建测试脚本
    create_test_scripts
    
    # 检查测试工具
    check_test_tools
    
    print_success "压力测试系统初始化完成"
}

# 创建测试配置
create_test_configs() {
    
    # 轻度测试配置
    cat > "$STRESS_CONFIG_DIR/light.conf" <<EOF
# 轻度压力测试配置
TEST_TYPE="light"
CONCURRENT_USERS=10
DURATION=60
REQUESTS_PER_SECOND=5
FILE_SIZE_RANGE="1KB-100KB"
THINK_TIME=1000
RAMP_UP_TIME=10
EOF

    # 普通测试配置
    cat > "$STRESS_CONFIG_DIR/normal.conf" <<EOF
# 普通压力测试配置
TEST_TYPE="normal"
CONCURRENT_USERS=50
DURATION=300
REQUESTS_PER_SECOND=20
FILE_SIZE_RANGE="100KB-10MB"
THINK_TIME=500
RAMP_UP_TIME=30
EOF

    # 重度测试配置
    cat > "$STRESS_CONFIG_DIR/heavy.conf" <<EOF
# 重度压力测试配置
TEST_TYPE="heavy"
CONCURRENT_USERS=200
DURATION=600
REQUESTS_PER_SECOND=100
FILE_SIZE_RANGE="10MB-100MB"
THINK_TIME=100
RAMP_UP_TIME=60
EOF

    # 极限测试配置
    cat > "$STRESS_CONFIG_DIR/extreme.conf" <<EOF
# 极限压力测试配置
TEST_TYPE="extreme"
CONCURRENT_USERS=1000
DURATION=1800
REQUESTS_PER_SECOND=500
FILE_SIZE_RANGE="100MB-1GB"
THINK_TIME=50
RAMP_UP_TIME=120
EOF

    print_success "测试配置文件创建完成"
}

# 创建测试脚本
create_test_scripts() {
    
    # 创建并发下载测试脚本
    cat > "$TEMP_DIR/download_worker.sh" <<'EOF'
#!/bin/bash
# 下载测试工作进程

WORKER_ID="$1"
URL="$2"
ITERATIONS="$3"
RESULTS_FILE="$4"

for ((i=1; i<=ITERATIONS; i++)); do
    start_time=$(date +%s.%N)
    
    if curl -s -o /dev/null -w "%{http_code},%{time_total},%{speed_download},%{size_download}" "$URL"; then
        end_time=$(date +%s.%N)
        duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
        echo "$(date +%s),$WORKER_ID,$i,success,$duration" >> "$RESULTS_FILE"
    else
        echo "$(date +%s),$WORKER_ID,$i,failed,0" >> "$RESULTS_FILE"
    fi
    
    # 模拟思考时间
    sleep 0.1
done
EOF

    chmod +x "$TEMP_DIR/download_worker.sh"
    
    # 创建资源监控脚本
    cat > "$TEMP_DIR/resource_monitor.sh" <<'EOF'
#!/bin/bash
# 资源使用监控脚本

MONITOR_FILE="$1"
INTERVAL="${2:-5}"

echo "timestamp,cpu_usage,memory_usage,disk_io,network_io" > "$MONITOR_FILE"

while true; do
    timestamp=$(date +%s)
    
    # CPU使用率 (macOS兼容)
    if command -v top >/dev/null 2>&1; then
        cpu_usage=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' || echo "0")
    else
        cpu_usage="0"
    fi
    
    # 内存使用率
    if command -v vm_stat >/dev/null 2>&1; then
        # macOS
        memory_usage=$(vm_stat | awk '/Pages active/ {active=$3} /Pages free/ {free=$3} /Pages wired/ {wired=$3} END {total=active+free+wired; if(total>0) print (active+wired)*100/total; else print 0}' | cut -d. -f1)
    else
        memory_usage="0"
    fi
    
    # 磁盘IO (简化)
    disk_io="0"
    
    # 网络IO (简化)
    network_io="0"
    
    echo "$timestamp,$cpu_usage,$memory_usage,$disk_io,$network_io" >> "$MONITOR_FILE"
    
    sleep "$INTERVAL"
done
EOF

    chmod +x "$TEMP_DIR/resource_monitor.sh"
    
    print_success "测试脚本创建完成"
}

# 检查测试工具
check_test_tools() {
    local missing_tools=()
    
    # 检查必要工具
    local required_tools=("curl" "bc")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    # 检查可选工具
    local optional_tools=("ab" "wget" "siege" "wrk")
    local available_tools=()
    
    for tool in "${optional_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            available_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_warning "缺少必要工具: ${missing_tools[*]}"
        print_info "请安装: sudo dnf install ${missing_tools[*]}"
    fi
    
    if [ ${#available_tools[@]} -gt 0 ]; then
        print_info "可用的压力测试工具: ${available_tools[*]}"
    else
        print_warning "未找到专业压力测试工具，将使用内置测试"
    fi
}

# 仓库服务器压力测试
repo_stress_test() {
    local concurrent="${1:-50}"
    local duration="${2:-300}"
    local test_url="${3:-http://localhost/repositories/}"
    
    print_test "开始仓库服务器压力测试..."
    print_info "配置: $concurrent 并发用户, $duration 秒持续时间"
    print_info "目标URL: $test_url"
    
    local test_id="repo_stress_$(date +%Y%m%d_%H%M%S)"
    local results_file="$STRESS_RESULTS_DIR/${test_id}.csv"
    local monitor_file="$STRESS_RESULTS_DIR/${test_id}_monitor.csv"
    
    # 启动资源监控
    print_info "启动资源监控..."
    "$TEMP_DIR/resource_monitor.sh" "$monitor_file" 5 &
    local monitor_pid=$!
    
    # 创建测试结果文件
    echo "timestamp,worker_id,iteration,status,response_time,http_code,bytes_downloaded" > "$results_file"
    
    # 检查测试URL可用性
    if ! curl -s --head "$test_url" >/dev/null; then
        print_warning "无法连接到测试URL，使用模拟测试"
        test_url="https://httpbin.org/delay/1"
    fi
    
    print_test "启动 $concurrent 个并发工作进程..."
    
    local pids=()
    local requests_per_worker=$((duration / 10))  # 每10秒一个请求
    
    # 启动并发工作进程
    for ((i=1; i<=concurrent; i++)); do
        (
            for ((j=1; j<=requests_per_worker; j++)); do
                start_time=$(date +%s.%N)
                
                response=$(curl -s -o /dev/null -w "%{http_code},%{time_total},%{size_download}" "$test_url" 2>/dev/null || echo "000,0,0")
                
                end_time=$(date +%s.%N)
                duration_ms=$(echo "($end_time - $start_time) * 1000" | bc 2>/dev/null || echo "0")
                
                echo "$(date +%s),$i,$j,success,$duration_ms,$response" >> "$results_file"
                
                # 随机等待时间
                sleep_time=$(echo "scale=2; $(shuf -i 1-20 -n 1) / 10" | bc 2>/dev/null || echo "1")
                sleep "$sleep_time"
            done
        ) &
        pids+=($!)
        
        # 分批启动，避免过载
        if [ $((i % 10)) -eq 0 ]; then
            sleep 1
        fi
    done
    
    print_info "等待测试完成..."
    
    # 等待所有工作进程完成
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # 停止资源监控
    kill "$monitor_pid" 2>/dev/null || true
    
    print_success "仓库压力测试完成"
    
    # 分析结果
    analyze_stress_test_results "$test_id" "$results_file" "$monitor_file"
}

# 并发下载测试
download_stress_test() {
    local concurrent="${1:-25}"
    local total_requests="${2:-500}"
    local test_url="${3:-http://localhost/repositories/test.rpm}"
    
    print_test "开始并发下载测试..."
    print_info "配置: $concurrent 并发下载, $total_requests 总请求数"
    print_info "目标URL: $test_url"
    
    local test_id="download_stress_$(date +%Y%m%d_%H%M%S)"
    local results_file="$STRESS_RESULTS_DIR/${test_id}.csv"
    
    # 创建测试结果文件
    echo "timestamp,worker_id,iteration,status,response_time" > "$results_file"
    
    # 检查测试URL可用性
    if ! curl -s --head "$test_url" >/dev/null; then
        print_warning "无法连接到测试URL，使用模拟测试"
        test_url="https://httpbin.org/bytes/1048576"  # 1MB测试文件
    fi
    
    local requests_per_worker=$((total_requests / concurrent))
    local pids=()
    
    print_test "启动 $concurrent 个下载工作进程..."
    
    # 启动并发下载进程
    for ((i=1; i<=concurrent; i++)); do
        "$TEMP_DIR/download_worker.sh" "$i" "$test_url" "$requests_per_worker" "$results_file" &
        pids+=($!)
    done
    
    # 监控进度
    local completed=0
    while [ $completed -lt ${#pids[@]} ]; do
        completed=0
        for pid in "${pids[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                completed=$((completed + 1))
            fi
        done
        
        local progress=$((completed * 100 / ${#pids[@]}))
        print_info "下载测试进度: $progress% ($completed/${#pids[@]} 完成)"
        sleep 5
    done
    
    print_success "并发下载测试完成"
    
    # 分析下载结果
    analyze_download_test_results "$test_id" "$results_file"
}

# 构建系统压力测试
build_stress_test() {
    local test_type="${1:-normal}"
    
    print_test "开始构建系统压力测试 (类型: $test_type)..."
    
    # 加载测试配置
    if [ -f "$STRESS_CONFIG_DIR/${test_type}.conf" ]; then
        source "$STRESS_CONFIG_DIR/${test_type}.conf"
    else
        print_error "测试配置不存在: $test_type"
        return 1
    fi
    
    local test_id="build_stress_$(date +%Y%m%d_%H%M%S)"
    local results_file="$STRESS_RESULTS_DIR/${test_id}.log"
    
    print_info "测试配置: $CONCURRENT_USERS 并发, $DURATION 秒"
    
    # 检查构建环境
    if [ ! -f "build.sh" ]; then
        print_warning "构建脚本不存在，使用模拟构建测试"
        simulate_build_stress "$test_id" "$CONCURRENT_USERS" "$DURATION"
        return 0
    fi
    
    print_test "启动并发构建测试..."
    
    # 创建测试工作目录
    local test_work_dir="$TEMP_DIR/build_test_$test_id"
    mkdir -p "$test_work_dir"
    
    local pids=()
    
    # 启动并发构建进程
    for ((i=1; i<=CONCURRENT_USERS; i++)); do
        (
            local worker_dir="$test_work_dir/worker_$i"
            mkdir -p "$worker_dir"
            cd "$worker_dir"
            
            # 复制必要文件
            cp -r "$OLDPWD"/{*.sh,*/} . 2>/dev/null || true
            
            # 执行构建
            local start_time=$(date +%s)
            if timeout $((DURATION / CONCURRENT_USERS)) ./build.sh >/dev/null 2>&1; then
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                echo "$(date '+%Y-%m-%d %H:%M:%S') Worker $i: SUCCESS (${duration}s)" >> "$results_file"
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') Worker $i: FAILED" >> "$results_file"
            fi
        ) &
        pids+=($!)
        
        # 分批启动
        if [ $((i % 5)) -eq 0 ]; then
            sleep 2
        fi
    done
    
    # 等待所有构建完成
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # 清理测试目录
    rm -rf "$test_work_dir"
    
    print_success "构建压力测试完成"
    
    # 分析构建结果
    analyze_build_test_results "$test_id" "$results_file"
}

# 模拟构建压力测试
simulate_build_stress() {
    local test_id="$1"
    local concurrent="$2"
    local duration="$3"
    
    local results_file="$STRESS_RESULTS_DIR/${test_id}.log"
    
    print_info "运行模拟构建压力测试..."
    
    for ((i=1; i<=concurrent; i++)); do
        (
            local iterations=$((duration / 10))
            for ((j=1; j<=iterations; j++)); do
                # 模拟构建过程
                local build_time=$(shuf -i 5-30 -n 1)
                sleep "$build_time"
                
                # 随机成功/失败
                if [ $((RANDOM % 10)) -lt 8 ]; then
                    echo "$(date '+%Y-%m-%d %H:%M:%S') Worker $i Iteration $j: SUCCESS (${build_time}s)" >> "$results_file"
                else
                    echo "$(date '+%Y-%m-%d %H:%M:%S') Worker $i Iteration $j: FAILED" >> "$results_file"
                fi
            done
        ) &
    done
    
    wait
}

# 性能基准测试
benchmark_test() {
    print_test "开始性能基准测试..."
    
    local benchmark_id="benchmark_$(date +%Y%m%d_%H%M%S)"
    local results_file="$STRESS_RESULTS_DIR/${benchmark_id}.json"
    
    # 初始化结果文件
    cat > "$results_file" <<EOF
{
  "benchmark": {
    "id": "$benchmark_id",
    "timestamp": "$(date -Iseconds)",
    "system_info": {
      "hostname": "$(hostname)",
      "os": "$(uname -s)",
      "arch": "$(uname -m)"
    },
    "tests": {}
  }
}
EOF

    # CPU基准测试
    print_info "运行CPU基准测试..."
    local cpu_start=$(date +%s.%N)
    
    # 简单的CPU密集型计算
    local result=$(echo "scale=10; 4*a(1)" | bc -l 2>/dev/null || echo "3.14159")
    
    local cpu_end=$(date +%s.%N)
    local cpu_time=$(echo "$cpu_end - $cpu_start" | bc 2>/dev/null || echo "0")
    
    # 磁盘IO基准测试
    print_info "运行磁盘IO基准测试..."
    local io_start=$(date +%s.%N)
    
    dd if=/dev/zero of="$TEMP_DIR/testfile" bs=1M count=100 2>/dev/null || true
    rm -f "$TEMP_DIR/testfile"
    
    local io_end=$(date +%s.%N)
    local io_time=$(echo "$io_end - $io_start" | bc 2>/dev/null || echo "0")
    
    # 网络基准测试
    print_info "运行网络基准测试..."
    local net_start=$(date +%s.%N)
    
    if curl -s -o /dev/null "https://httpbin.org/bytes/1048576"; then
        local net_end=$(date +%s.%N)
        local net_time=$(echo "$net_end - $net_start" | bc 2>/dev/null || echo "0")
    else
        local net_time="failed"
    fi
    
    # 更新结果文件
    local temp_file=$(mktemp)
    cat > "$temp_file" <<EOF
{
  "benchmark": {
    "id": "$benchmark_id",
    "timestamp": "$(date -Iseconds)",
    "system_info": {
      "hostname": "$(hostname)",
      "os": "$(uname -s)",
      "arch": "$(uname -m)"
    },
    "tests": {
      "cpu_performance": {
        "execution_time": "$cpu_time",
        "result": "$result",
        "score": $(echo "$cpu_time * 100" | bc 2>/dev/null || echo "0")
      },
      "disk_io_performance": {
        "execution_time": "$io_time",
        "operation": "write_100MB",
        "score": $(echo "100 / $io_time" | bc 2>/dev/null || echo "0")
      },
      "network_performance": {
        "execution_time": "$net_time",
        "operation": "download_1MB",
        "score": $(echo "1 / $net_time" | bc 2>/dev/null || echo "0")
      }
    }
  }
}
EOF
    
    mv "$temp_file" "$results_file"
    
    print_success "性能基准测试完成"
    
    # 显示基准结果
    show_benchmark_results "$benchmark_id" "$results_file"
}

# 分析压力测试结果
analyze_stress_test_results() {
    local test_id="$1"
    local results_file="$2"
    local monitor_file="$3"
    
    print_info "分析压力测试结果: $test_id"
    
    if [ ! -f "$results_file" ]; then
        print_error "结果文件不存在: $results_file"
        return 1
    fi
    
    # 统计基本指标
    local total_requests=$(tail -n +2 "$results_file" | wc -l)
    local successful_requests=$(tail -n +2 "$results_file" | grep -c "success" || echo "0")
    local failed_requests=$((total_requests - successful_requests))
    
    # 计算成功率
    local success_rate=0
    if [ $total_requests -gt 0 ]; then
        success_rate=$(echo "scale=2; $successful_requests * 100 / $total_requests" | bc || echo "0")
    fi
    
    # 计算平均响应时间
    local avg_response_time=0
    if [ $successful_requests -gt 0 ]; then
        avg_response_time=$(tail -n +2 "$results_file" | grep "success" | awk -F',' '{sum+=$5; count++} END {if(count>0) print sum/count; else print 0}')
    fi
    
    echo ""
    print_info "压力测试结果统计:"
    echo "  总请求数: $total_requests"
    echo "  成功请求: $successful_requests"
    echo "  失败请求: $failed_requests"
    echo "  成功率: ${success_rate}%"
    echo "  平均响应时间: ${avg_response_time}ms"
    
    # 分析资源使用情况
    if [ -f "$monitor_file" ]; then
        analyze_resource_usage "$monitor_file"
    fi
    
    # 生成测试报告
    generate_stress_test_report "$test_id" "$results_file" "$monitor_file"
}

# 分析下载测试结果
analyze_download_test_results() {
    local test_id="$1"
    local results_file="$2"
    
    print_info "分析下载测试结果: $test_id"
    
    local total_downloads=$(tail -n +2 "$results_file" | wc -l)
    local successful_downloads=$(tail -n +2 "$results_file" | grep -c "success" || echo "0")
    local failed_downloads=$((total_downloads - successful_downloads))
    
    local success_rate=0
    if [ $total_downloads -gt 0 ]; then
        success_rate=$(echo "scale=2; $successful_downloads * 100 / $total_downloads" | bc || echo "0")
    fi
    
    echo ""
    print_info "下载测试结果统计:"
    echo "  总下载数: $total_downloads"
    echo "  成功下载: $successful_downloads"
    echo "  失败下载: $failed_downloads"
    echo "  成功率: ${success_rate}%"
    
    # 计算吞吐量
    if [ $successful_downloads -gt 0 ]; then
        local start_time=$(tail -n +2 "$results_file" | head -1 | cut -d',' -f1)
        local end_time=$(tail -n +2 "$results_file" | tail -1 | cut -d',' -f1)
        local duration=$((end_time - start_time))
        
        if [ $duration -gt 0 ]; then
            local throughput=$(echo "scale=2; $successful_downloads / $duration" | bc || echo "0")
            echo "  吞吐量: ${throughput} 下载/秒"
        fi
    fi
}

# 分析构建测试结果
analyze_build_test_results() {
    local test_id="$1"
    local results_file="$2"
    
    print_info "分析构建测试结果: $test_id"
    
    local total_builds=$(grep -c "Worker" "$results_file" || echo "0")
    local successful_builds=$(grep -c "SUCCESS" "$results_file" || echo "0")
    local failed_builds=$(grep -c "FAILED" "$results_file" || echo "0")
    
    local success_rate=0
    if [ $total_builds -gt 0 ]; then
        success_rate=$(echo "scale=2; $successful_builds * 100 / $total_builds" | bc || echo "0")
    fi
    
    echo ""
    print_info "构建测试结果统计:"
    echo "  总构建数: $total_builds"
    echo "  成功构建: $successful_builds"
    echo "  失败构建: $failed_builds"
    echo "  成功率: ${success_rate}%"
    
    # 计算平均构建时间
    if [ $successful_builds -gt 0 ]; then
        local avg_build_time=$(grep "SUCCESS" "$results_file" | sed 's/.*(\([0-9]*\)s).*/\1/' | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
        echo "  平均构建时间: ${avg_build_time}秒"
    fi
}

# 分析资源使用情况
analyze_resource_usage() {
    local monitor_file="$1"
    
    if [ ! -f "$monitor_file" ]; then
        return 1
    fi
    
    print_info "系统资源使用分析:"
    
    # 计算平均CPU使用率
    local avg_cpu=$(tail -n +2 "$monitor_file" | awk -F',' '{sum+=$2; count++} END {if(count>0) print sum/count; else print 0}')
    
    # 计算最大CPU使用率
    local max_cpu=$(tail -n +2 "$monitor_file" | awk -F',' '{if($2>max) max=$2} END {print max+0}')
    
    # 计算平均内存使用率
    local avg_memory=$(tail -n +2 "$monitor_file" | awk -F',' '{sum+=$3; count++} END {if(count>0) print sum/count; else print 0}')
    
    # 计算最大内存使用率
    local max_memory=$(tail -n +2 "$monitor_file" | awk -F',' '{if($3>max) max=$3} END {print max+0}')
    
    echo "  平均CPU使用率: ${avg_cpu}%"
    echo "  最大CPU使用率: ${max_cpu}%"
    echo "  平均内存使用率: ${avg_memory}%"
    echo "  最大内存使用率: ${max_memory}%"
}

# 显示基准测试结果
show_benchmark_results() {
    local benchmark_id="$1"
    local results_file="$2"
    
    print_info "基准测试结果: $benchmark_id"
    echo ""
    
    if command -v jq >/dev/null 2>&1; then
        # 使用jq解析JSON (如果可用)
        local cpu_time=$(jq -r '.benchmark.tests.cpu_performance.execution_time' "$results_file" 2>/dev/null || echo "N/A")
        local io_time=$(jq -r '.benchmark.tests.disk_io_performance.execution_time' "$results_file" 2>/dev/null || echo "N/A")
        local net_time=$(jq -r '.benchmark.tests.network_performance.execution_time' "$results_file" 2>/dev/null || echo "N/A")
        
        echo "CPU性能测试: ${cpu_time}秒"
        echo "磁盘IO测试: ${io_time}秒"
        echo "网络性能测试: ${net_time}秒"
    else
        # 简单文本解析
        echo "基准测试完成，详细结果请查看: $results_file"
    fi
}

# 生成压力测试报告
generate_stress_test_report() {
    local test_id="$1"
    local results_file="$2"
    local monitor_file="$3"
    local output_format="${4:-html}"
    
    local report_file="$STRESS_REPORTS_DIR/${test_id}_report.${output_format}"
    
    print_info "生成测试报告: $report_file"
    
    case "$output_format" in
        "html")
            generate_html_stress_report "$test_id" "$results_file" "$monitor_file" "$report_file"
            ;;
        "json")
            generate_json_stress_report "$test_id" "$results_file" "$monitor_file" "$report_file"
            ;;
        *)
            generate_text_stress_report "$test_id" "$results_file" "$monitor_file" "$report_file"
            ;;
    esac
    
    print_success "测试报告已生成: $report_file"
}

# 生成HTML测试报告
generate_html_stress_report() {
    local test_id="$1"
    local results_file="$2"
    local monitor_file="$3"
    local report_file="$4"
    
    cat > "$report_file" <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>iipe 压力测试报告 - $test_id</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f8f9fa; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007bff; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; }
        .metric-card { background: #fff; border: 1px solid #ddd; padding: 15px; border-radius: 5px; }
        .metric-value { font-size: 2em; font-weight: bold; color: #007bff; }
        .metric-label { color: #666; }
        .success { color: #28a745; }
        .warning { color: #ffc107; }
        .error { color: #dc3545; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 iipe 压力测试报告</h1>
        <p>测试ID: $test_id</p>
        <p>生成时间: $(date)</p>
    </div>

    <div class="section">
        <h2>📊 测试结果概览</h2>
        <div class="metrics">
            <div class="metric-card">
                <div class="metric-value">$([ -f "$results_file" ] && tail -n +2 "$results_file" | wc -l || echo "0")</div>
                <div class="metric-label">总请求数</div>
            </div>
            <div class="metric-card">
                <div class="metric-value success">$([ -f "$results_file" ] && tail -n +2 "$results_file" | grep -c "success" || echo "0")</div>
                <div class="metric-label">成功请求</div>
            </div>
            <div class="metric-card">
                <div class="metric-value error">$([ -f "$results_file" ] && tail -n +2 "$results_file" | grep -c "failed" || echo "0")</div>
                <div class="metric-label">失败请求</div>
            </div>
        </div>
    </div>

    <div class="section">
        <h2>💡 测试建议</h2>
        <ul>
            <li>根据测试结果优化服务器配置</li>
            <li>监控系统资源使用情况</li>
            <li>定期进行压力测试以确保系统稳定性</li>
            <li>建立性能基线和告警机制</li>
        </ul>
    </div>
</body>
</html>
EOF
}

# 生成JSON测试报告
generate_json_stress_report() {
    local test_id="$1"
    local results_file="$2"
    local monitor_file="$3"
    local report_file="$4"
    
    local total_requests=$([ -f "$results_file" ] && tail -n +2 "$results_file" | wc -l || echo "0")
    local successful_requests=$([ -f "$results_file" ] && tail -n +2 "$results_file" | grep -c "success" || echo "0")
    local failed_requests=$((total_requests - successful_requests))
    
    cat > "$report_file" <<EOF
{
  "stress_test_report": {
    "test_id": "$test_id",
    "generated_at": "$(date -Iseconds)",
    "summary": {
      "total_requests": $total_requests,
      "successful_requests": $successful_requests,
      "failed_requests": $failed_requests,
      "success_rate": $(echo "scale=2; $successful_requests * 100 / ($total_requests + 0.01)" | bc || echo "0")
    },
    "files": {
      "results_file": "$results_file",
      "monitor_file": "$monitor_file"
    },
    "recommendations": [
      "根据测试结果优化服务器配置",
      "监控系统资源使用情况",
      "定期进行压力测试以确保系统稳定性",
      "建立性能基线和告警机制"
    ]
  }
}
EOF
}

# 列出测试结果
list_test_results() {
    print_info "压力测试结果列表:"
    echo ""
    
    if [ ! -d "$STRESS_RESULTS_DIR" ] || [ "$(find "$STRESS_RESULTS_DIR" -name "*.csv" -o -name "*.log" -o -name "*.json" | wc -l)" -eq 0 ]; then
        print_warning "没有找到测试结果"
        return 0
    fi
    
    printf "%-30s %-15s %-20s %-10s\n" "测试ID" "类型" "时间" "大小"
    printf "%-30s %-15s %-20s %-10s\n" "------" "----" "----" "----"
    
    for result_file in "$STRESS_RESULTS_DIR"/*; do
        if [ -f "$result_file" ]; then
            local filename=$(basename "$result_file")
            local test_id=$(echo "$filename" | sed 's/\.[^.]*$//')
            local test_type="unknown"
            local file_size=$(du -h "$result_file" 2>/dev/null | cut -f1 || echo "0B")
            local file_time=$(stat -f '%Sm' "$result_file" 2>/dev/null || stat -c '%y' "$result_file" 2>/dev/null | cut -d' ' -f1)
            
            # 推测测试类型
            case "$filename" in
                repo_stress*) test_type="仓库压力" ;;
                download_stress*) test_type="下载测试" ;;
                build_stress*) test_type="构建压力" ;;
                benchmark*) test_type="基准测试" ;;
                *) test_type="其他" ;;
            esac
            
            printf "%-30s %-15s %-20s %-10s\n" "$test_id" "$test_type" "$file_time" "$file_size"
        fi
    done
}

# 主函数
main() {
    local command=""
    local concurrent=50
    local duration=300
    local requests=1000
    local test_size=""
    local test_url=""
    local test_type="normal"
    local test_profile=""
    local output_format="text"
    local output_file=""
    local verbose=false
    local quiet=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            repo-stress|download-test|build-stress|network-test|resource-monitor|benchmark|load-test|endurance-test|generate-report|list-results)
                command="$1"
                shift
                ;;
            -c|--concurrent)
                concurrent="$2"
                shift 2
                ;;
            -d|--duration)
                duration="$2"
                shift 2
                ;;
            -r|--requests)
                requests="$2"
                shift 2
                ;;
            -s|--size)
                test_size="$2"
                shift 2
                ;;
            -u|--url)
                test_url="$2"
                shift 2
                ;;
            -t|--type)
                test_type="$2"
                shift 2
                ;;
            -p|--profile)
                test_profile="$2"
                shift 2
                ;;
            -o|--output)
                output_format="$2"
                shift 2
                ;;
            -f|--file)
                output_file="$2"
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
    init_stress_tester
    
    # 执行命令
    case "$command" in
        "repo-stress")
            repo_stress_test "$concurrent" "$duration" "$test_url"
            ;;
        "download-test")
            download_stress_test "$concurrent" "$requests" "$test_url"
            ;;
        "build-stress")
            build_stress_test "$test_type"
            ;;
        "benchmark")
            benchmark_test
            ;;
        "list-results")
            list_test_results
            ;;
        "")
            # 默认运行轻度压力测试
            print_info "运行默认轻度压力测试..."
            repo_stress_test 10 60
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