#!/bin/bash

# iipe 系统维护工具
# 用于定期清理、备份和资源管理

set -e

# 配置
BACKUP_DIR="backups"
TEMP_DIR="/tmp/iipe_maintenance"
LOG_FILE="logs/maintenance_$(date '+%Y%m%d').log"
DEFAULT_RETENTION_DAYS=30
DEFAULT_BACKUP_RETENTION=90

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印函数
print_info() {
    local msg="[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${BLUE}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

print_success() {
    local msg="[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

print_warning() {
    local msg="[WARNING] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

print_error() {
    local msg="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${RED}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

# 显示用法
show_usage() {
    echo "iipe 系统维护工具"
    echo ""
    echo "用法: $0 [command] [options]"
    echo ""
    echo "命令:"
    echo "  cleanup          清理临时文件和过期数据"
    echo "  backup           备份重要配置和数据"
    echo "  restore          恢复备份数据"
    echo "  optimize         优化系统性能"
    echo "  health-check     系统健康检查"
    echo "  disk-check       磁盘空间检查"
    echo "  auto-maintain    自动维护(推荐定期执行)"
    echo "  status           显示维护状态"
    echo ""
    echo "选项:"
    echo "  -r, --retention DAYS    数据保留天数 [默认: $DEFAULT_RETENTION_DAYS]"
    echo "  -b, --backup-retention DAYS  备份保留天数 [默认: $DEFAULT_BACKUP_RETENTION]"
    echo "  -f, --force             强制执行，不询问确认"
    echo "  -v, --verbose           详细输出"
    echo "  -h, --help              显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 cleanup -r 7         # 清理7天前的数据"
    echo "  $0 backup               # 备份重要数据"
    echo "  $0 auto-maintain        # 执行自动维护"
}

# 初始化维护环境
init_maintenance() {
    mkdir -p "$BACKUP_DIR" "$(dirname "$LOG_FILE")" "$TEMP_DIR"
    print_info "维护环境初始化完成"
}

# 清理临时文件和过期数据
cleanup_system() {
    local retention_days="${1:-$DEFAULT_RETENTION_DAYS}"
    local force="${2:-false}"
    
    print_info "开始系统清理 (保留 $retention_days 天数据)..."
    
    if [ "$force" != "true" ]; then
        echo -n "确定要清理过期数据吗? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_info "取消清理操作"
            return 0
        fi
    fi
    
    local cleaned_files=0
    local freed_space=0
    
    # 清理构建缓存
    if [ -d "/var/lib/mock" ]; then
        print_info "清理Mock构建缓存..."
        for cache_dir in /var/lib/mock/*/cache/; do
            if [ -d "$cache_dir" ]; then
                local size_before=$(du -sb "$cache_dir" 2>/dev/null | cut -f1 || echo 0)
                find "$cache_dir" -type f -mtime +$retention_days -delete 2>/dev/null || true
                local size_after=$(du -sb "$cache_dir" 2>/dev/null | cut -f1 || echo 0)
                freed_space=$((freed_space + size_before - size_after))
            fi
        done
    fi
    
    # 清理临时文件
    print_info "清理临时文件..."
    if [ -d "sources" ]; then
        find sources -name "*.tmp" -o -name "*.download" -delete 2>/dev/null || true
    fi
    
    # 清理日志文件
    print_info "清理过期日志..."
    for log_dir in logs/*/; do
        if [ -d "$log_dir" ]; then
            local count=$(find "$log_dir" -name "*.log" -mtime +$retention_days -delete -print 2>/dev/null | wc -l)
            cleaned_files=$((cleaned_files + count))
        fi
    done
    
    # 清理指标文件
    print_info "清理过期指标..."
    if [ -d "metrics" ]; then
        local count=$(find metrics -name "*.csv" -mtime +$retention_days -delete -print 2>/dev/null | wc -l)
        cleaned_files=$((cleaned_files + count))
    fi
    
    # 清理备份文件
    local backup_retention="${3:-$DEFAULT_BACKUP_RETENTION}"
    print_info "清理过期备份 (保留 $backup_retention 天)..."
    if [ -d "$BACKUP_DIR" ]; then
        local count=$(find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$backup_retention -delete -print 2>/dev/null | wc -l)
        cleaned_files=$((cleaned_files + count))
    fi
    
    # 清理系统临时文件
    print_info "清理系统临时文件..."
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    mkdir -p "$TEMP_DIR"
    
    print_success "清理完成: 删除 $cleaned_files 个文件，释放 $(( freed_space / 1024 / 1024 )) MB 空间"
}

# 备份重要配置和数据
backup_system() {
    local backup_name="iipe_backup_$(date '+%Y%m%d_%H%M%S')"
    local backup_file="$BACKUP_DIR/${backup_name}.tar.gz"
    
    print_info "开始系统备份: $backup_file"
    
    # 创建临时备份目录
    local temp_backup="$TEMP_DIR/$backup_name"
    mkdir -p "$temp_backup"
    
    # 备份配置文件
    print_info "备份配置文件..."
    cp -r mock_configs "$temp_backup/" 2>/dev/null || true
    cp macros.iipe-php "$temp_backup/" 2>/dev/null || true
    cp *.sh "$temp_backup/" 2>/dev/null || true
    
    # 备份模板和补丁
    [ -d templates ] && cp -r templates "$temp_backup/" || true
    [ -d patches ] && cp -r patches "$temp_backup/" || true
    
    # 备份spec文件
    print_info "备份spec文件..."
    mkdir -p "$temp_backup/specs"
    for system_dir in */; do
        if [ -f "$system_dir/iipe-php.spec" ]; then
            cp "$system_dir/iipe-php.spec" "$temp_backup/specs/${system_dir%/}.spec"
        fi
    done
    
    # 备份CI/CD配置
    [ -d .github ] && cp -r .github "$temp_backup/" || true
    [ -f .gitlab-ci.yml ] && cp .gitlab-ci.yml "$temp_backup/" || true
    [ -d ci ] && cp -r ci "$temp_backup/" || true
    
    # 备份文档
    [ -d docs ] && cp -r docs "$temp_backup/" || true
    [ -f README.md ] && cp README.md "$temp_backup/" || true
    
    # 创建备份元数据
    cat > "$temp_backup/backup_info.txt" <<EOF
iipe 系统备份信息
备份时间: $(date)
备份主机: $(hostname)
备份版本: $backup_name
备份内容:
- 配置文件 (mock_configs/, macros.iipe-php)
- 构建脚本 (*.sh)
- 模板和补丁 (templates/, patches/)
- Spec文件 (所有系统)
- CI/CD配置 (.github/, .gitlab-ci.yml, ci/)
- 文档 (docs/, README.md)
EOF
    
    # 创建压缩包
    print_info "创建压缩包..."
    if tar -czf "$backup_file" -C "$TEMP_DIR" "$backup_name"; then
        local backup_size=$(du -h "$backup_file" | cut -f1)
        print_success "备份完成: $backup_file ($backup_size)"
        
        # 验证备份完整性
        if tar -tzf "$backup_file" >/dev/null 2>&1; then
            print_success "备份文件完整性验证通过"
        else
            print_error "备份文件完整性验证失败"
        fi
    else
        print_error "备份失败"
        return 1
    fi
    
    # 清理临时文件
    rm -rf "$temp_backup"
}

# 恢复备份数据
restore_system() {
    local backup_file="$1"
    local force="${2:-false}"
    
    if [ -z "$backup_file" ]; then
        print_info "可用的备份文件:"
        if [ -d "$BACKUP_DIR" ]; then
            ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || print_warning "没有找到备份文件"
        fi
        echo ""
        echo "用法: $0 restore <备份文件路径>"
        return 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        print_error "备份文件不存在: $backup_file"
        return 1
    fi
    
    print_info "准备恢复备份: $backup_file"
    
    # 验证备份文件
    if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
        print_error "备份文件损坏或格式不正确"
        return 1
    fi
    
    if [ "$force" != "true" ]; then
        echo -n "确定要恢复备份吗? 这将覆盖现有配置 (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_info "取消恢复操作"
            return 0
        fi
    fi
    
    # 创建当前配置的快照
    print_info "创建当前配置快照..."
    backup_system
    
    # 解压备份文件
    local temp_restore="$TEMP_DIR/restore_$(date '+%Y%m%d_%H%M%S')"
    mkdir -p "$temp_restore"
    
    if tar -xzf "$backup_file" -C "$temp_restore"; then
        print_success "备份文件解压完成"
    else
        print_error "备份文件解压失败"
        return 1
    fi
    
    # 恢复文件
    local backup_dir=$(find "$temp_restore" -maxdepth 1 -type d -name "iipe_backup_*" | head -1)
    if [ -n "$backup_dir" ]; then
        print_info "恢复配置文件..."
        
        # 恢复各类文件
        [ -d "$backup_dir/mock_configs" ] && cp -r "$backup_dir/mock_configs" . || true
        [ -f "$backup_dir/macros.iipe-php" ] && cp "$backup_dir/macros.iipe-php" . || true
        [ -d "$backup_dir/templates" ] && cp -r "$backup_dir/templates" . || true
        [ -d "$backup_dir/patches" ] && cp -r "$backup_dir/patches" . || true
        
        # 恢复spec文件
        if [ -d "$backup_dir/specs" ]; then
            for spec_file in "$backup_dir/specs"/*.spec; do
                if [ -f "$spec_file" ]; then
                    local system_name=$(basename "$spec_file" .spec)
                    mkdir -p "$system_name"
                    cp "$spec_file" "$system_name/iipe-php.spec"
                fi
            done
        fi
        
        print_success "配置恢复完成"
    else
        print_error "备份目录结构异常"
        return 1
    fi
    
    # 清理临时文件
    rm -rf "$temp_restore"
}

# 系统优化
optimize_system() {
    print_info "开始系统优化..."
    
    # 优化Mock配置
    print_info "优化Mock配置..."
    if [ -d "/var/lib/mock" ]; then
        # 清理旧的root目录
        for root_dir in /var/lib/mock/*/root/; do
            if [ -d "$root_dir" ]; then
                local age=$(find "$root_dir" -maxdepth 0 -mtime +7 2>/dev/null | wc -l)
                if [ "$age" -gt 0 ]; then
                    print_info "清理过期Mock root: $root_dir"
                    rm -rf "$root_dir" 2>/dev/null || true
                fi
            fi
        done
    fi
    
    # 压缩旧的源码文件
    print_info "压缩源码文件..."
    if [ -d "sources" ]; then
        find sources -name "*.tar.*" -mtime +30 -exec gzip -f {} \; 2>/dev/null || true
    fi
    
    # 优化仓库元数据
    print_info "优化仓库元数据..."
    if [ -d "repo_output" ]; then
        for repo_dir in repo_output/*/; do
            if [ -d "$repo_dir/repodata" ]; then
                # 重新生成仓库元数据以优化性能
                createrepo_c --update "$repo_dir" >/dev/null 2>&1 || true
            fi
        done
    fi
    
    print_success "系统优化完成"
}

# 系统健康检查
health_check() {
    print_info "执行系统健康检查..."
    
    local issues=0
    
    # 检查磁盘空间
    print_info "检查磁盘空间..."
    df -h | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{print $5 " " $6}' | while read output; do
        usage=$(echo $output | awk '{print $1}' | sed 's/%//g')
        mount_point=$(echo $output | awk '{print $2}')
        
        if [ $usage -ge 90 ]; then
            print_error "磁盘空间严重不足: $mount_point ($usage%)"
            issues=$((issues + 1))
        elif [ $usage -ge 80 ]; then
            print_warning "磁盘空间不足: $mount_point ($usage%)"
        fi
    done
    
    # 检查必要文件
    print_info "检查必要文件..."
    local required_files=(
        "build.sh"
        "batch-build.sh"
        "publish.sh"
        "macros.iipe-php"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "缺失必要文件: $file"
            issues=$((issues + 1))
        fi
    done
    
    # 检查Mock配置
    print_info "检查Mock配置..."
    if [ ! -d "mock_configs" ] || [ "$(find mock_configs -name "*.cfg" | wc -l)" -eq 0 ]; then
        print_error "Mock配置缺失或不完整"
        issues=$((issues + 1))
    fi
    
    # 检查系统权限
    print_info "检查系统权限..."
    if ! groups | grep -q mock; then
        print_warning "当前用户不在mock组中"
    fi
    
    if [ $issues -eq 0 ]; then
        print_success "系统健康检查通过"
    else
        print_warning "发现 $issues 个问题需要处理"
    fi
    
    return $issues
}

# 磁盘检查
disk_check() {
    print_info "详细磁盘空间检查..."
    
    # 显示磁盘使用情况
    echo ""
    echo "磁盘使用情况:"
    df -h
    
    echo ""
    echo "目录大小分析:"
    
    # 分析各个目录的大小
    local directories=(
        "repo_output"
        "sources" 
        "logs"
        "metrics"
        "$BACKUP_DIR"
        "/var/lib/mock"
    )
    
    for dir in "${directories[@]}"; do
        if [ -d "$dir" ]; then
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo "  $dir: $size"
        fi
    done
    
    # 查找大文件
    echo ""
    echo "大文件 (>100MB):"
    find . -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -10 || echo "  无大文件"
}

# 自动维护
auto_maintain() {
    local retention_days="${1:-$DEFAULT_RETENTION_DAYS}"
    
    print_info "开始自动维护流程..."
    
    # 执行健康检查
    if ! health_check; then
        print_warning "健康检查发现问题，建议手动检查"
    fi
    
    # 创建备份
    backup_system
    
    # 清理系统
    cleanup_system "$retention_days" "true"
    
    # 优化系统
    optimize_system
    
    print_success "自动维护完成"
}

# 显示维护状态
show_status() {
    print_info "维护状态概览:"
    
    echo ""
    echo "备份状态:"
    if [ -d "$BACKUP_DIR" ]; then
        local backup_count=$(find "$BACKUP_DIR" -name "*.tar.gz" 2>/dev/null | wc -l)
        echo "  备份文件数量: $backup_count"
        if [ $backup_count -gt 0 ]; then
            echo "  最新备份: $(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1 | xargs ls -lh)"
        fi
    else
        echo "  无备份目录"
    fi
    
    echo ""
    echo "日志状态:"
    if [ -d "logs" ]; then
        local log_count=$(find logs -name "*.log" 2>/dev/null | wc -l)
        local log_size=$(du -sh logs 2>/dev/null | cut -f1)
        echo "  日志文件数量: $log_count"
        echo "  日志总大小: $log_size"
    fi
    
    echo ""
    disk_check
}

# 主函数
main() {
    local command=""
    local retention_days="$DEFAULT_RETENTION_DAYS"
    local backup_retention="$DEFAULT_BACKUP_RETENTION"
    local force=false
    local verbose=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            cleanup|backup|restore|optimize|health-check|disk-check|auto-maintain|status)
                command="$1"
                shift
                ;;
            -r|--retention)
                retention_days="$2"
                shift 2
                ;;
            -b|--backup-retention)
                backup_retention="$2"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                if [ -z "$command" ]; then
                    print_error "未知命令: $1"
                    show_usage
                    exit 1
                else
                    # 可能是restore命令的备份文件参数
                    backup_file="$1"
                    shift
                fi
                ;;
        esac
    done
    
    # 初始化维护环境
    init_maintenance
    
    # 执行命令
    case "$command" in
        "cleanup")
            cleanup_system "$retention_days" "$force" "$backup_retention"
            ;;
        "backup")
            backup_system
            ;;
        "restore")
            restore_system "$backup_file" "$force"
            ;;
        "optimize")
            optimize_system
            ;;
        "health-check")
            health_check
            ;;
        "disk-check")
            disk_check
            ;;
        "auto-maintain")
            auto_maintain "$retention_days"
            ;;
        "status")
            show_status
            ;;
        "")
            show_status
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