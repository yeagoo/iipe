#!/bin/bash

# iipe 镜像同步工具
# 用于多镜像站点同步、CDN分发和镜像管理

set -e

# 配置
SYNC_CONFIG_DIR="mirror-configs"
SYNC_LOG_DIR="logs/mirror-sync"
SYNC_REPORTS_DIR="mirror-sync-reports"
TEMP_DIR="/tmp/iipe_mirror_sync"
MIRRORS_DB="mirrors.db"

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
    echo "$msg" >> "$SYNC_LOG_DIR/mirror_sync_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_success() {
    local msg="[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$SYNC_LOG_DIR/mirror_sync_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_warning() {
    local msg="[WARNING] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$SYNC_LOG_DIR/mirror_sync_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_error() {
    local msg="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${RED}${msg}${NC}"
    echo "$msg" >> "$SYNC_LOG_DIR/mirror_sync_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_sync() {
    local msg="[SYNC] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${CYAN}${msg}${NC}"
    echo "$msg" >> "$SYNC_LOG_DIR/mirror_sync_$(date '+%Y%m%d').log" 2>/dev/null || true
}

# 显示用法
show_usage() {
    echo "iipe 镜像同步工具"
    echo ""
    echo "用法: $0 [command] [options]"
    echo ""
    echo "命令:"
    echo "  add-mirror        添加镜像站点"
    echo "  remove-mirror     删除镜像站点"
    echo "  list-mirrors      列出所有镜像站点"
    echo "  sync              同步到所有镜像站点"
    echo "  sync-single       同步到指定镜像站点"
    echo "  check-mirrors     检查镜像站点状态"
    echo "  setup-cdn         配置CDN分发"
    echo "  test-sync         测试同步连接"
    echo "  generate-report   生成同步报告"
    echo "  monitor           启动同步监控"
    echo ""
    echo "选项:"
    echo "  -m, --mirror NAME         指定镜像站点名称"
    echo "  -t, --type TYPE           镜像类型 [rsync|ssh|ftp|s3|http]"
    echo "  -u, --url URL             镜像URL地址"
    echo "  -p, --path PATH           镜像远程路径"
    echo "  -k, --key FILE            SSH密钥文件"
    echo "  -c, --concurrent NUM      并发同步数量"
    echo "  -f, --force               强制同步（忽略时间戳）"
    echo "  -d, --dry-run             仅显示同步计划"
    echo "  -v, --verbose             详细输出"
    echo "  -o, --output FORMAT       输出格式 [text|html|json]"
    echo "  -h, --help                显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 add-mirror -m mirror1 -t rsync -u rsync://mirror.example.com/iipe/"
    echo "  $0 sync -c 4              # 4个并发同步"
    echo "  $0 sync-single -m mirror1 # 同步指定镜像"
    echo "  $0 check-mirrors          # 检查所有镜像状态"
}

# 初始化镜像同步环境
init_mirror_sync() {
    mkdir -p "$SYNC_CONFIG_DIR" "$SYNC_LOG_DIR" "$SYNC_REPORTS_DIR" "$TEMP_DIR"
    
    # 创建镜像数据库
    if [ ! -f "$MIRRORS_DB" ]; then
        create_mirrors_db
    fi
    
    # 创建默认配置模板
    create_config_templates
    
    print_info "镜像同步环境初始化完成"
}

# 创建镜像数据库
create_mirrors_db() {
    cat > "$MIRRORS_DB" <<EOF
# iipe 镜像站点数据库
# 格式: 镜像名称|类型|URL|路径|状态|最后同步时间|配置文件

# 示例镜像配置
# mirror1|rsync|rsync://mirror.example.com/|/iipe/|active|never|mirror1.conf
# mirror2|ssh|user@mirror2.example.com|/var/www/iipe/|active|never|mirror2.conf
# cdn1|s3|s3://cdn-bucket/|iipe/|active|never|cdn1.conf
EOF
    print_success "镜像数据库创建完成"
}

# 创建配置模板
create_config_templates() {
    
    # Rsync 配置模板
    cat > "$SYNC_CONFIG_DIR/rsync-template.conf" <<EOF
# Rsync 镜像配置模板
MIRROR_NAME=""
MIRROR_TYPE="rsync"
RSYNC_URL=""
RSYNC_OPTIONS="-avz --delete --progress"
BANDWIDTH_LIMIT=""
TIMEOUT="300"
RETRY_COUNT="3"
EXCLUDE_PATTERNS="*.tmp *.lock"
INCLUDE_PATTERNS=""
EOF

    # SSH 配置模板
    cat > "$SYNC_CONFIG_DIR/ssh-template.conf" <<EOF
# SSH 镜像配置模板
MIRROR_NAME=""
MIRROR_TYPE="ssh"
SSH_HOST=""
SSH_USER=""
SSH_PATH=""
SSH_KEY=""
SSH_PORT="22"
RSYNC_OPTIONS="-avz --delete --progress"
TIMEOUT="300"
RETRY_COUNT="3"
EOF

    # S3 配置模板
    cat > "$SYNC_CONFIG_DIR/s3-template.conf" <<EOF
# S3/CDN 配置模板
MIRROR_NAME=""
MIRROR_TYPE="s3"
S3_BUCKET=""
S3_PREFIX=""
S3_REGION=""
AWS_ACCESS_KEY=""
AWS_SECRET_KEY=""
S3_ENDPOINT=""
SYNC_DELETE="true"
STORAGE_CLASS="STANDARD"
EOF

    print_info "配置模板创建完成"
}

# 添加镜像站点
add_mirror() {
    local mirror_name="$1"
    local mirror_type="$2"
    local mirror_url="$3"
    local mirror_path="$4"
    
    if [ -z "$mirror_name" ] || [ -z "$mirror_type" ] || [ -z "$mirror_url" ]; then
        print_error "缺少必要参数: 镜像名称、类型和URL"
        return 1
    fi
    
    # 检查镜像是否已存在
    if grep -q "^$mirror_name|" "$MIRRORS_DB" 2>/dev/null; then
        print_error "镜像站点已存在: $mirror_name"
        return 1
    fi
    
    # 验证镜像类型
    case "$mirror_type" in
        rsync|ssh|ftp|s3|http)
            ;;
        *)
            print_error "不支持的镜像类型: $mirror_type"
            return 1
            ;;
    esac
    
    print_info "添加镜像站点: $mirror_name ($mirror_type)"
    
    # 创建镜像配置文件
    local config_file="$SYNC_CONFIG_DIR/${mirror_name}.conf"
    
    case "$mirror_type" in
        "rsync")
            cp "$SYNC_CONFIG_DIR/rsync-template.conf" "$config_file"
            # macOS兼容的sed命令
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|MIRROR_NAME=\"\"|MIRROR_NAME=\"$mirror_name\"|" "$config_file"
                sed -i '' "s|RSYNC_URL=\"\"|RSYNC_URL=\"$mirror_url\"|" "$config_file"
            else
                sed -i "s|MIRROR_NAME=\"\"|MIRROR_NAME=\"$mirror_name\"|" "$config_file"
                sed -i "s|RSYNC_URL=\"\"|RSYNC_URL=\"$mirror_url\"|" "$config_file"
            fi
            ;;
        "ssh")
            cp "$SYNC_CONFIG_DIR/ssh-template.conf" "$config_file"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|MIRROR_NAME=\"\"|MIRROR_NAME=\"$mirror_name\"|" "$config_file"
                sed -i '' "s|SSH_HOST=\"\"|SSH_HOST=\"$mirror_url\"|" "$config_file"
                [ -n "$mirror_path" ] && sed -i '' "s|SSH_PATH=\"\"|SSH_PATH=\"$mirror_path\"|" "$config_file"
            else
                sed -i "s|MIRROR_NAME=\"\"|MIRROR_NAME=\"$mirror_name\"|" "$config_file"
                sed -i "s|SSH_HOST=\"\"|SSH_HOST=\"$mirror_url\"|" "$config_file"
                [ -n "$mirror_path" ] && sed -i "s|SSH_PATH=\"\"|SSH_PATH=\"$mirror_path\"|" "$config_file"
            fi
            ;;
        "s3")
            cp "$SYNC_CONFIG_DIR/s3-template.conf" "$config_file"
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|MIRROR_NAME=\"\"|MIRROR_NAME=\"$mirror_name\"|" "$config_file"
                sed -i '' "s|S3_BUCKET=\"\"|S3_BUCKET=\"$mirror_url\"|" "$config_file"
                [ -n "$mirror_path" ] && sed -i '' "s|S3_PREFIX=\"\"|S3_PREFIX=\"$mirror_path\"|" "$config_file"
            else
                sed -i "s|MIRROR_NAME=\"\"|MIRROR_NAME=\"$mirror_name\"|" "$config_file"
                sed -i "s|S3_BUCKET=\"\"|S3_BUCKET=\"$mirror_url\"|" "$config_file"
                [ -n "$mirror_path" ] && sed -i "s|S3_PREFIX=\"\"|S3_PREFIX=\"$mirror_path\"|" "$config_file"
            fi
            ;;
    esac
    
    # 添加到数据库
    echo "$mirror_name|$mirror_type|$mirror_url|${mirror_path:-/}|active|never|${mirror_name}.conf" >> "$MIRRORS_DB"
    
    print_success "镜像站点添加完成: $mirror_name"
    print_info "配置文件: $config_file"
    print_info "请编辑配置文件以完成详细设置"
}

# 删除镜像站点
remove_mirror() {
    local mirror_name="$1"
    
    if [ -z "$mirror_name" ]; then
        print_error "请指定要删除的镜像名称"
        return 1
    fi
    
    if ! grep -q "^$mirror_name|" "$MIRRORS_DB" 2>/dev/null; then
        print_error "镜像站点不存在: $mirror_name"
        return 1
    fi
    
    print_info "删除镜像站点: $mirror_name"
    
    # 从数据库中删除
    grep -v "^$mirror_name|" "$MIRRORS_DB" > "$MIRRORS_DB.tmp" && mv "$MIRRORS_DB.tmp" "$MIRRORS_DB"
    
    # 删除配置文件
    rm -f "$SYNC_CONFIG_DIR/${mirror_name}.conf"
    
    print_success "镜像站点删除完成: $mirror_name"
}

# 列出所有镜像站点
list_mirrors() {
    print_info "当前配置的镜像站点:"
    echo ""
    
    if [ ! -f "$MIRRORS_DB" ] || [ ! -s "$MIRRORS_DB" ]; then
        print_warning "没有配置任何镜像站点"
        return 0
    fi
    
    printf "%-15s %-8s %-30s %-20s %-10s %-20s\n" "名称" "类型" "URL" "路径" "状态" "最后同步"
    printf "%-15s %-8s %-30s %-20s %-10s %-20s\n" "----" "----" "---" "----" "----" "--------"
    
    while IFS='|' read -r name type url path status last_sync config; do
        # 跳过注释行
        if [[ "$name" =~ ^#.*$ ]] || [ -z "$name" ]; then
            continue
        fi
        
        printf "%-15s %-8s %-30s %-20s %-10s %-20s\n" "$name" "$type" "$url" "$path" "$status" "$last_sync"
    done < "$MIRRORS_DB"
}

# 检查镜像站点状态
check_mirrors() {
    print_info "检查镜像站点连接状态..."
    echo ""
    
    local total_mirrors=0
    local active_mirrors=0
    local failed_mirrors=0
    
    while IFS='|' read -r name type url path status last_sync config; do
        # 跳过注释行
        if [[ "$name" =~ ^#.*$ ]] || [ -z "$name" ]; then
            continue
        fi
        
        total_mirrors=$((total_mirrors + 1))
        
        print_info "检查镜像: $name ($type)"
        
        case "$type" in
            "rsync")
                if timeout 30 rsync --list-only "$url" >/dev/null 2>&1; then
                    print_success "✓ $name - 连接正常"
                    active_mirrors=$((active_mirrors + 1))
                else
                    print_error "✗ $name - 连接失败"
                    failed_mirrors=$((failed_mirrors + 1))
                fi
                ;;
            "ssh")
                local ssh_host=$(echo "$url" | cut -d'@' -f2)
                if timeout 30 ssh -o ConnectTimeout=10 -o BatchMode=yes "$url" "echo 'connection test'" >/dev/null 2>&1; then
                    print_success "✓ $name - 连接正常"
                    active_mirrors=$((active_mirrors + 1))
                else
                    print_error "✗ $name - 连接失败"
                    failed_mirrors=$((failed_mirrors + 1))
                fi
                ;;
            "s3")
                if command -v aws >/dev/null 2>&1; then
                    if aws s3 ls "$url" >/dev/null 2>&1; then
                        print_success "✓ $name - 连接正常"
                        active_mirrors=$((active_mirrors + 1))
                    else
                        print_error "✗ $name - 连接失败"
                        failed_mirrors=$((failed_mirrors + 1))
                    fi
                else
                    print_warning "⚠ $name - AWS CLI未安装"
                fi
                ;;
            *)
                print_warning "⚠ $name - 不支持的类型检查"
                ;;
        esac
    done < "$MIRRORS_DB"
    
    echo ""
    print_info "检查完成 - 总计: $total_mirrors, 正常: $active_mirrors, 失败: $failed_mirrors"
}

# 同步到单个镜像站点
sync_single_mirror() {
    local mirror_name="$1"
    local force_sync="${2:-false}"
    local dry_run="${3:-false}"
    
    if [ -z "$mirror_name" ]; then
        print_error "请指定镜像名称"
        return 1
    fi
    
    # 获取镜像信息
    local mirror_info=$(grep "^$mirror_name|" "$MIRRORS_DB" 2>/dev/null)
    if [ -z "$mirror_info" ]; then
        print_error "镜像站点不存在: $mirror_name"
        return 1
    fi
    
    local mirror_type=$(echo "$mirror_info" | cut -d'|' -f2)
    local mirror_url=$(echo "$mirror_info" | cut -d'|' -f3)
    local mirror_path=$(echo "$mirror_info" | cut -d'|' -f4)
    local config_file="$SYNC_CONFIG_DIR/${mirror_name}.conf"
    
    if [ ! -f "$config_file" ]; then
        print_error "配置文件不存在: $config_file"
        return 1
    fi
    
    # 加载配置
    source "$config_file"
    
    print_info "开始同步到镜像: $mirror_name ($mirror_type)"
    
    local sync_start_time=$(date '+%Y-%m-%d %H:%M:%S')
    local sync_result=0
    
    case "$mirror_type" in
        "rsync")
            sync_rsync_mirror "$mirror_name" "$force_sync" "$dry_run"
            sync_result=$?
            ;;
        "ssh")
            sync_ssh_mirror "$mirror_name" "$force_sync" "$dry_run"
            sync_result=$?
            ;;
        "s3")
            sync_s3_mirror "$mirror_name" "$force_sync" "$dry_run"
            sync_result=$?
            ;;
        *)
            print_error "不支持的镜像类型: $mirror_type"
            return 1
            ;;
    esac
    
    # 更新同步状态
    if [ $sync_result -eq 0 ]; then
        update_mirror_sync_status "$mirror_name" "success" "$sync_start_time"
        print_success "镜像同步完成: $mirror_name"
    else
        update_mirror_sync_status "$mirror_name" "failed" "$sync_start_time"
        print_error "镜像同步失败: $mirror_name"
    fi
    
    return $sync_result
}

# Rsync 镜像同步
sync_rsync_mirror() {
    local mirror_name="$1"
    local force_sync="$2"
    local dry_run="$3"
    
    local rsync_cmd="rsync $RSYNC_OPTIONS"
    
    # 添加带宽限制
    if [ -n "$BANDWIDTH_LIMIT" ]; then
        rsync_cmd="$rsync_cmd --bwlimit=$BANDWIDTH_LIMIT"
    fi
    
    # 添加排除模式
    if [ -n "$EXCLUDE_PATTERNS" ]; then
        for pattern in $EXCLUDE_PATTERNS; do
            rsync_cmd="$rsync_cmd --exclude=$pattern"
        done
    fi
    
    # 添加包含模式
    if [ -n "$INCLUDE_PATTERNS" ]; then
        for pattern in $INCLUDE_PATTERNS; do
            rsync_cmd="$rsync_cmd --include=$pattern"
        done
    fi
    
    # 干运行模式
    if [ "$dry_run" = "true" ]; then
        rsync_cmd="$rsync_cmd --dry-run"
        print_info "模拟同步: $rsync_cmd"
    fi
    
    print_sync "执行 Rsync 同步: $RSYNC_URL"
    
    # 执行同步
    local retry=0
    while [ $retry -lt "${RETRY_COUNT:-3}" ]; do
        if timeout "${TIMEOUT:-300}" $rsync_cmd repositories/ "$RSYNC_URL"; then
            return 0
        else
            retry=$((retry + 1))
            print_warning "同步失败，重试 $retry/${RETRY_COUNT:-3}"
            sleep 10
        fi
    done
    
    return 1
}

# SSH 镜像同步
sync_ssh_mirror() {
    local mirror_name="$1"
    local force_sync="$2"
    local dry_run="$3"
    
    local ssh_opts="-o ConnectTimeout=30 -o ServerAliveInterval=60"
    
    # 添加SSH密钥
    if [ -n "$SSH_KEY" ] && [ -f "$SSH_KEY" ]; then
        ssh_opts="$ssh_opts -i $SSH_KEY"
    fi
    
    # 添加端口
    if [ -n "$SSH_PORT" ] && [ "$SSH_PORT" != "22" ]; then
        ssh_opts="$ssh_opts -p $SSH_PORT"
    fi
    
    local rsync_cmd="rsync $RSYNC_OPTIONS -e 'ssh $ssh_opts'"
    
    # 干运行模式
    if [ "$dry_run" = "true" ]; then
        rsync_cmd="$rsync_cmd --dry-run"
        print_info "模拟同步: $rsync_cmd"
    fi
    
    local remote_target="${SSH_USER}@${SSH_HOST}:${SSH_PATH}"
    print_sync "执行 SSH 同步: $remote_target"
    
    # 执行同步
    local retry=0
    while [ $retry -lt "${RETRY_COUNT:-3}" ]; do
        if timeout "${TIMEOUT:-300}" eval "$rsync_cmd repositories/ $remote_target"; then
            return 0
        else
            retry=$((retry + 1))
            print_warning "同步失败，重试 $retry/${RETRY_COUNT:-3}"
            sleep 10
        fi
    done
    
    return 1
}

# S3 镜像同步
sync_s3_mirror() {
    local mirror_name="$1"
    local force_sync="$2"
    local dry_run="$3"
    
    # 检查AWS CLI
    if ! command -v aws >/dev/null 2>&1; then
        print_error "AWS CLI 未安装"
        return 1
    fi
    
    # 设置AWS凭证
    if [ -n "$AWS_ACCESS_KEY" ] && [ -n "$AWS_SECRET_KEY" ]; then
        export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY"
        export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_KEY"
    fi
    
    if [ -n "$S3_REGION" ]; then
        export AWS_DEFAULT_REGION="$S3_REGION"
    fi
    
    local s3_target="s3://${S3_BUCKET}/${S3_PREFIX}"
    local aws_cmd="aws s3 sync repositories/ $s3_target"
    
    # 添加删除选项
    if [ "$SYNC_DELETE" = "true" ]; then
        aws_cmd="$aws_cmd --delete"
    fi
    
    # 添加存储类别
    if [ -n "$STORAGE_CLASS" ]; then
        aws_cmd="$aws_cmd --storage-class $STORAGE_CLASS"
    fi
    
    # 添加端点
    if [ -n "$S3_ENDPOINT" ]; then
        aws_cmd="$aws_cmd --endpoint-url $S3_ENDPOINT"
    fi
    
    # 干运行模式
    if [ "$dry_run" = "true" ]; then
        aws_cmd="$aws_cmd --dryrun"
        print_info "模拟同步: $aws_cmd"
    fi
    
    print_sync "执行 S3 同步: $s3_target"
    
    # 执行同步
    if eval "$aws_cmd"; then
        return 0
    else
        return 1
    fi
}

# 同步到所有镜像站点
sync_all_mirrors() {
    local concurrent="${1:-1}"
    local force_sync="${2:-false}"
    local dry_run="${3:-false}"
    
    print_info "开始同步到所有镜像站点 (并发: $concurrent)"
    
    local total_mirrors=0
    local success_count=0
    local failed_count=0
    local pids=()
    
    # 创建临时结果目录
    local results_dir="$TEMP_DIR/sync_results_$$"
    mkdir -p "$results_dir"
    
    while IFS='|' read -r name type url path status last_sync config; do
        # 跳过注释行和非活动镜像
        if [[ "$name" =~ ^#.*$ ]] || [ -z "$name" ] || [ "$status" != "active" ]; then
            continue
        fi
        
        total_mirrors=$((total_mirrors + 1))
        
        # 控制并发数量
        while [ ${#pids[@]} -ge $concurrent ]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[i]}" 2>/dev/null; then
                    wait "${pids[i]}"
                    unset pids[i]
                fi
            done
            pids=("${pids[@]}")  # 重新索引数组
            sleep 1
        done
        
        # 在后台执行同步
        (
            if sync_single_mirror "$name" "$force_sync" "$dry_run"; then
                echo "success" > "$results_dir/$name"
            else
                echo "failed" > "$results_dir/$name"
            fi
        ) &
        
        pids+=($!)
        print_info "启动同步任务: $name (PID: $!)"
        
    done < "$MIRRORS_DB"
    
    # 等待所有同步完成
    print_info "等待所有同步任务完成..."
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # 统计结果
    for result_file in "$results_dir"/*; do
        if [ -f "$result_file" ]; then
            if [ "$(cat "$result_file")" = "success" ]; then
                success_count=$((success_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
        fi
    done
    
    # 清理临时文件
    rm -rf "$results_dir"
    
    print_info "同步完成 - 总计: $total_mirrors, 成功: $success_count, 失败: $failed_count"
    
    # 生成同步报告
    generate_sync_report "text" "$total_mirrors" "$success_count" "$failed_count"
}

# 更新镜像同步状态
update_mirror_sync_status() {
    local mirror_name="$1"
    local sync_status="$2"
    local sync_time="$3"
    
    # 创建临时文件
    local temp_file="$MIRRORS_DB.tmp"
    
    while IFS='|' read -r name type url path status last_sync config; do
        if [ "$name" = "$mirror_name" ]; then
            echo "$name|$type|$url|$path|$status|$sync_time|$config"
        else
            echo "$name|$type|$url|$path|$status|$last_sync|$config"
        fi
    done < "$MIRRORS_DB" > "$temp_file"
    
    mv "$temp_file" "$MIRRORS_DB"
}

# 生成同步报告
generate_sync_report() {
    local output_format="${1:-text}"
    local total="${2:-0}"
    local success="${3:-0}"
    local failed="${4:-0}"
    
    local report_file="$SYNC_REPORTS_DIR/sync_report_$(date '+%Y%m%d_%H%M%S')"
    
    print_info "生成同步报告 (格式: $output_format)..."
    
    case "$output_format" in
        "html")
            generate_html_sync_report "$report_file.html" "$total" "$success" "$failed"
            ;;
        "json")
            generate_json_sync_report "$report_file.json" "$total" "$success" "$failed"
            ;;
        *)
            generate_text_sync_report "$report_file.txt" "$total" "$success" "$failed"
            ;;
    esac
    
    print_success "同步报告已生成: $report_file.$output_format"
}

# 生成文本格式同步报告
generate_text_sync_report() {
    local report_file="$1"
    local total="$2"
    local success="$3" 
    local failed="$4"
    
    cat > "$report_file" <<EOF
iipe 镜像同步报告
================

生成时间: $(date)
同步统计:
- 总镜像数: $total
- 成功同步: $success
- 失败同步: $failed
- 成功率: $([ $total -gt 0 ] && echo "scale=2; $success * 100 / $total" | bc || echo "0")%

镜像状态详情:
EOF

    while IFS='|' read -r name type url path status last_sync config; do
        if [[ "$name" =~ ^#.*$ ]] || [ -z "$name" ]; then
            continue
        fi
        echo "- $name ($type): $status, 最后同步: $last_sync" >> "$report_file"
    done < "$MIRRORS_DB"
    
    cat >> "$report_file" <<EOF

建议:
1. 定期检查失败的镜像连接
2. 优化带宽设置以提高同步速度
3. 配置监控以及时发现问题
4. 考虑增加CDN节点以提高用户访问速度
EOF
}

# 生成HTML格式同步报告
generate_html_sync_report() {
    local report_file="$1"
    local total="$2"
    local success="$3"
    local failed="$4"
    local success_rate=$([ $total -gt 0 ] && echo "scale=2; $success * 100 / $total" | bc || echo "0")
    
    cat > "$report_file" <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>iipe 镜像同步报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f8f9fa; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .stats { display: flex; gap: 20px; margin: 20px 0; }
        .stat-card { background: #fff; border: 1px solid #ddd; padding: 15px; border-radius: 5px; text-align: center; flex: 1; }
        .stat-value { font-size: 2em; font-weight: bold; }
        .stat-label { color: #666; }
        .success { color: #28a745; }
        .failed { color: #dc3545; }
        .total { color: #007bff; }
        .table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        .table th, .table td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        .table th { background-color: #f2f2f2; }
        .status-active { color: #28a745; font-weight: bold; }
        .status-failed { color: #dc3545; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🌐 iipe 镜像同步报告</h1>
        <p>生成时间: $(date)</p>
    </div>

    <div class="stats">
        <div class="stat-card">
            <div class="stat-value total">$total</div>
            <div class="stat-label">总镜像数</div>
        </div>
        <div class="stat-card">
            <div class="stat-value success">$success</div>
            <div class="stat-label">成功同步</div>
        </div>
        <div class="stat-card">
            <div class="stat-value failed">$failed</div>
            <div class="stat-label">失败同步</div>
        </div>
        <div class="stat-card">
            <div class="stat-value">$success_rate%</div>
            <div class="stat-label">成功率</div>
        </div>
    </div>

    <h2>📋 镜像状态详情</h2>
    <table class="table">
        <tr>
            <th>镜像名称</th>
            <th>类型</th>
            <th>URL</th>
            <th>状态</th>
            <th>最后同步时间</th>
        </tr>
EOF

    while IFS='|' read -r name type url path status last_sync config; do
        if [[ "$name" =~ ^#.*$ ]] || [ -z "$name" ]; then
            continue
        fi
        
        local status_class="status-active"
        if [ "$status" != "active" ]; then
            status_class="status-failed"
        fi
        
        cat >> "$report_file" <<EOF
        <tr>
            <td>$name</td>
            <td>$type</td>
            <td>$url</td>
            <td class="$status_class">$status</td>
            <td>$last_sync</td>
        </tr>
EOF
    done < "$MIRRORS_DB"
    
    cat >> "$report_file" <<EOF
    </table>

    <h2>💡 建议和优化</h2>
    <ul>
        <li>定期检查失败的镜像连接</li>
        <li>优化带宽设置以提高同步速度</li>
        <li>配置监控以及时发现问题</li>
        <li>考虑增加CDN节点以提高用户访问速度</li>
    </ul>
</body>
</html>
EOF
}

# 生成JSON格式同步报告
generate_json_sync_report() {
    local report_file="$1"
    local total="$2"
    local success="$3"
    local failed="$4"
    local success_rate=$([ $total -gt 0 ] && echo "scale=2; $success * 100 / $total" | bc || echo "0")
    
    cat > "$report_file" <<EOF
{
  "report": {
    "title": "iipe 镜像同步报告",
    "generated_at": "$(date -Iseconds)",
    "statistics": {
      "total_mirrors": $total,
      "successful_syncs": $success,
      "failed_syncs": $failed,
      "success_rate": $success_rate
    },
    "mirrors": [
EOF

    local first_entry=true
    while IFS='|' read -r name type url path status last_sync config; do
        if [[ "$name" =~ ^#.*$ ]] || [ -z "$name" ]; then
            continue
        fi
        
        if [ "$first_entry" = "true" ]; then
            first_entry=false
        else
            echo "," >> "$report_file"
        fi
        
        cat >> "$report_file" <<EOF
      {
        "name": "$name",
        "type": "$type",
        "url": "$url",
        "path": "$path",
        "status": "$status",
        "last_sync": "$last_sync",
        "config_file": "$config"
      }
EOF
    done < "$MIRRORS_DB"
    
    cat >> "$report_file" <<EOF
    ],
    "recommendations": [
      "定期检查失败的镜像连接",
      "优化带宽设置以提高同步速度",
      "配置监控以及时发现问题",
      "考虑增加CDN节点以提高用户访问速度"
    ],
    "next_steps": [
      "运行 ./mirror-sync.sh check-mirrors 检查镜像状态",
      "运行 ./mirror-sync.sh sync 开始同步",
      "配置定期同步计划任务"
    ]
  }
}
EOF
}

# 设置CDN分发
setup_cdn() {
    print_info "配置CDN分发..."
    
    # 创建CDN配置模板
    local cdn_config="$SYNC_CONFIG_DIR/cdn-setup.conf"
    
    cat > "$cdn_config" <<EOF
# CDN分发配置
# 支持AWS CloudFront, Cloudflare, 阿里云CDN等

# AWS CloudFront 配置
AWS_CLOUDFRONT_DISTRIBUTION_ID=""
AWS_CLOUDFRONT_DOMAIN=""
AWS_CLOUDFRONT_ORIGIN_BUCKET=""

# Cloudflare 配置
CLOUDFLARE_ZONE_ID=""
CLOUDFLARE_API_TOKEN=""
CLOUDFLARE_DOMAIN=""

# 阿里云CDN配置
ALIYUN_ACCESS_KEY=""
ALIYUN_SECRET_KEY=""
ALIYUN_CDN_DOMAIN=""

# CDN缓存设置
CDN_CACHE_TTL="86400"
CDN_PURGE_AFTER_SYNC="true"

# 缓存规则
CDN_CACHE_RULES="
*.rpm=604800
repodata/*=3600
*.xml.gz=3600
"
EOF

    print_success "CDN配置模板已创建: $cdn_config"
    print_info "请编辑配置文件以完成CDN设置"
    
    # 创建CDN管理脚本
    create_cdn_management_script
}

# 创建CDN管理脚本
create_cdn_management_script() {
    local cdn_script="cdn-management.sh"
    
    cat > "$cdn_script" <<'EOF'
#!/bin/bash

# CDN管理脚本

# CloudFront 缓存刷新
purge_cloudfront() {
    local distribution_id="$1"
    local paths="$2"
    
    if [ -n "$distribution_id" ] && command -v aws >/dev/null 2>&1; then
        echo "刷新 CloudFront 缓存..."
        aws cloudfront create-invalidation \
            --distribution-id "$distribution_id" \
            --paths "$paths"
    fi
}

# Cloudflare 缓存刷新
purge_cloudflare() {
    local zone_id="$1"
    local api_token="$2"
    local files="$3"
    
    if [ -n "$zone_id" ] && [ -n "$api_token" ]; then
        echo "刷新 Cloudflare 缓存..."
        curl -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/purge_cache" \
            -H "Authorization: Bearer $api_token" \
            -H "Content-Type: application/json" \
            --data "{\"files\":[$files]}"
    fi
}

# 主函数
case "$1" in
    "cloudfront")
        purge_cloudfront "$2" "$3"
        ;;
    "cloudflare")
        purge_cloudflare "$2" "$3" "$4"
        ;;
    *)
        echo "用法: $0 {cloudfront|cloudflare} [参数...]"
        ;;
esac
EOF

    chmod +x "$cdn_script"
    print_success "CDN管理脚本已创建: $cdn_script"
}

# 测试同步连接
test_sync() {
    local mirror_name="$1"
    
    if [ -n "$mirror_name" ]; then
        print_info "测试指定镜像连接: $mirror_name"
        sync_single_mirror "$mirror_name" "false" "true"
    else
        print_info "测试所有镜像连接..."
        sync_all_mirrors "1" "false" "true"
    fi
}

# 启动同步监控
start_sync_monitor() {
    print_info "启动镜像同步监控..."
    
    local monitor_script="monitor-daemon.sh"
    
    cat > "$monitor_script" <<'EOF'
#!/bin/bash

# 镜像同步监控守护进程

INTERVAL=3600  # 1小时检查一次
LOG_FILE="logs/mirror-sync/monitor_daemon.log"

print_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 主监控循环
while true; do
    print_log "开始定期同步检查..."
    
    # 检查镜像状态
    ./mirror-sync.sh check-mirrors
    
    # 执行自动同步（如果配置了自动同步）
    if [ -f "mirror-configs/auto-sync.conf" ]; then
        source "mirror-configs/auto-sync.conf"
        if [ "$AUTO_SYNC_ENABLED" = "true" ]; then
            print_log "执行自动同步..."
            ./mirror-sync.sh sync -c "${AUTO_SYNC_CONCURRENT:-2}"
        fi
    fi
    
    print_log "等待下次检查 ($INTERVAL 秒)..."
    sleep $INTERVAL
done
EOF

    chmod +x "$monitor_script"
    
    # 创建自动同步配置
    mkdir -p mirror-configs
    cat > "mirror-configs/auto-sync.conf" <<EOF
# 自动同步配置
AUTO_SYNC_ENABLED=false
AUTO_SYNC_CONCURRENT=2
AUTO_SYNC_INTERVAL=3600
AUTO_SYNC_TIME="02:00"
EOF

    print_success "监控脚本已创建: $monitor_script"
    print_info "启动监控: nohup ./$monitor_script &"
}

# 主函数
main() {
    local command=""
    local mirror_name=""
    local mirror_type=""
    local mirror_url=""
    local mirror_path=""
    local ssh_key=""
    local concurrent=1
    local force_sync=false
    local dry_run=false
    local verbose=false
    local output_format="text"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            add-mirror|remove-mirror|list-mirrors|sync|sync-single|check-mirrors|setup-cdn|test-sync|generate-report|monitor)
                command="$1"
                shift
                ;;
            -m|--mirror)
                mirror_name="$2"
                shift 2
                ;;
            -t|--type)
                mirror_type="$2"
                shift 2
                ;;
            -u|--url)
                mirror_url="$2"
                shift 2
                ;;
            -p|--path)
                mirror_path="$2"
                shift 2
                ;;
            -k|--key)
                ssh_key="$2"
                shift 2
                ;;
            -c|--concurrent)
                concurrent="$2"
                shift 2
                ;;
            -f|--force)
                force_sync=true
                shift
                ;;
            -d|--dry-run)
                dry_run=true
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
    init_mirror_sync
    
    # 执行命令
    case "$command" in
        "add-mirror")
            add_mirror "$mirror_name" "$mirror_type" "$mirror_url" "$mirror_path"
            ;;
        "remove-mirror")
            remove_mirror "$mirror_name"
            ;;
        "list-mirrors")
            list_mirrors
            ;;
        "sync")
            sync_all_mirrors "$concurrent" "$force_sync" "$dry_run"
            ;;
        "sync-single")
            sync_single_mirror "$mirror_name" "$force_sync" "$dry_run"
            ;;
        "check-mirrors")
            check_mirrors
            ;;
        "setup-cdn")
            setup_cdn
            ;;
        "test-sync")
            test_sync "$mirror_name"
            ;;
        "generate-report")
            generate_sync_report "$output_format"
            ;;
        "monitor")
            start_sync_monitor
            ;;
        "")
            # 默认显示镜像状态
            list_mirrors
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