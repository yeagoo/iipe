#!/bin/bash

# iipe PHP Repository Publisher
# 用于创建和发布 PHP 多版本 YUM/DNF 软件仓库
# 用法: ./publish.sh [target_system]
# 示例: ./publish.sh almalinux-9  # 发布特定系统
#       ./publish.sh             # 发布所有系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
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

# 显示用法
show_usage() {
    echo "用法: $0 [target_system]"
    echo ""
    echo "参数说明:"
    echo "  target_system - 可选，指定要发布的目标系统目录名"
    echo "                  如果不指定，将发布所有系统的仓库"
    echo ""
    echo "支持的目标系统:"
    echo "  RHEL 9 系列: almalinux-9, oraclelinux-9, rockylinux-9, rhel-9, centos-stream-9"
    echo "  RHEL 10 系列: almalinux-10, oraclelinux-10, rockylinux-10, rhel-10, centos-stream-10"
    echo "  其他发行版: openeuler-24.03, openanolis-23, opencloudos-9"
    echo ""
    echo "示例:"
    echo "  $0                    # 发布所有系统的仓库"
    echo "  $0 almalinux-9        # 仅发布 AlmaLinux 9 仓库"
    echo "  $0 openeuler-24.03    # 仅发布 openEuler 24.03 仓库"
}

# 检查依赖
check_dependencies() {
    print_info "检查构建依赖..."
    
    if ! command -v createrepo_c > /dev/null 2>&1; then
        print_error "createrepo_c 未安装"
        print_error "请安装: dnf install createrepo_c"
        exit 1
    fi
    
    if ! command -v gpg > /dev/null 2>&1; then
        print_warning "gpg 未安装，将跳过 GPG 签名"
        GPG_AVAILABLE=false
    else
        GPG_AVAILABLE=true
        print_info "GPG 可用，将对仓库进行签名"
    fi
    
    print_success "依赖检查完成"
}

# GPG 密钥管理
setup_gpg_key() {
    if [ "$GPG_AVAILABLE" = false ]; then
        return 0
    fi
    
    print_info "设置 GPG 密钥..."
    
    # 检查是否已有 iipe 密钥
    if gpg --list-secret-keys | grep -q "build@ii.pe"; then
        print_info "找到现有的 iipe GPG 密钥"
        return 0
    fi
    
    print_info "生成新的 GPG 密钥..."
    
    # 创建 GPG 密钥配置
    cat > gpg_key_config <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: iipe PHP Repository
Name-Email: build@ii.pe
Expire-Date: 2y
Passphrase: 
%commit
%echo done
EOF

    # 生成密钥
    if gpg --batch --generate-key gpg_key_config; then
        print_success "GPG 密钥生成成功"
        rm -f gpg_key_config
    else
        print_warning "GPG 密钥生成失败，将跳过签名"
        GPG_AVAILABLE=false
        rm -f gpg_key_config
    fi
}

# 导出 GPG 公钥
export_gpg_public_key() {
    if [ "$GPG_AVAILABLE" = false ]; then
        return 0
    fi
    
    print_info "导出 GPG 公钥..."
    
    # 导出公钥到仓库根目录
    if gpg --armor --export build@ii.pe > docs/RPM-GPG-KEY-iipe; then
        print_success "GPG 公钥已导出到: docs/RPM-GPG-KEY-iipe"
    else
        print_warning "GPG 公钥导出失败"
    fi
}

# 创建单个系统的仓库
create_repository() {
    local system_dir="$1"
    local repo_path="repo_output/$system_dir"
    
    print_info "为系统 $system_dir 创建仓库..."
    
    # 检查目录是否存在且包含 RPM 文件
    if [ ! -d "$repo_path" ]; then
        print_warning "目录不存在，跳过: $repo_path"
        return 0
    fi
    
    if ! ls "$repo_path"/*.rpm >/dev/null 2>&1; then
        print_warning "没有找到 RPM 文件，跳过: $repo_path"
        return 0
    fi
    
    print_info "在 $repo_path 中找到 RPM 文件:"
    ls -la "$repo_path"/*.rpm
    
    # 创建仓库元数据
    print_info "生成仓库元数据..."
    if createrepo_c "$repo_path"; then
        print_success "仓库元数据创建成功: $repo_path"
    else
        print_error "仓库元数据创建失败: $repo_path"
        return 1
    fi
    
    # GPG 签名仓库
    if [ "$GPG_AVAILABLE" = true ]; then
        print_info "对仓库进行 GPG 签名..."
        if gpg --detach-sign --armor "$repo_path/repodata/repomd.xml"; then
            print_success "仓库 GPG 签名完成"
        else
            print_warning "仓库 GPG 签名失败"
        fi
    fi
    
    # 生成仓库统计信息
    local rpm_count=$(find "$repo_path" -name "*.rpm" | wc -l)
    local repo_size=$(du -sh "$repo_path" | cut -f1)
    
    print_success "仓库 $system_dir 发布完成:"
    print_success "  RPM 包数量: $rpm_count"
    print_success "  仓库大小: $repo_size"
}

# 生成仓库索引页面
generate_index_page() {
    print_info "生成仓库索引页面..."
    
    mkdir -p docs/web
    
    cat > docs/web/index.html <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>iipe - PHP 多版本软件仓库</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .repo-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 20px 0; }
        .repo-card { background: #ecf0f1; padding: 20px; border-radius: 6px; border-left: 4px solid #3498db; }
        .repo-card h3 { margin-top: 0; color: #2c3e50; }
        .repo-info { font-size: 14px; color: #7f8c8d; margin: 10px 0; }
        .install-cmd { background: #2c3e50; color: #ecf0f1; padding: 10px; border-radius: 4px; font-family: monospace; margin: 10px 0; word-break: break-all; }
        .usage-section { background: #f8f9fa; padding: 20px; border-radius: 6px; margin: 20px 0; }
        pre { background: #2c3e50; color: #ecf0f1; padding: 15px; border-radius: 4px; overflow-x: auto; }
        .warning { background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 4px; margin: 15px 0; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #bdc3c7; color: #7f8c8d; text-align: center; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐘 iipe - PHP 多版本软件仓库</h1>
        <p>为现代企业 Linux 生态提供 PHP 全生命周期版本支持的 SCL 风格软件仓库。支持 PHP 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5 等版本。</p>
        
        <div class="warning">
            <strong>⚠️ 注意:</strong> 请在安装仓库配置前导入 GPG 公钥以确保软件包的完整性和安全性。
        </div>

        <h2>📦 可用仓库</h2>
        <div class="repo-grid">
EOF

    # 为每个可用的仓库添加卡片
    for system_dir in repo_output/*/; do
        if [ -d "$system_dir" ]; then
            system_name=$(basename "$system_dir")
            rpm_count=$(find "$system_dir" -name "*.rpm" 2>/dev/null | wc -l)
            
            if [ "$rpm_count" -gt 0 ]; then
                # 判断系统类型
                case "$system_name" in
                    almalinux-*) system_display="AlmaLinux $(echo $system_name | cut -d- -f2)" ;;
                    rockylinux-*) system_display="Rocky Linux $(echo $system_name | cut -d- -f2)" ;;
                    oraclelinux-*) system_display="Oracle Linux $(echo $system_name | cut -d- -f2)" ;;
                    rhel-*) system_display="RHEL $(echo $system_name | cut -d- -f2)" ;;
                    centos-stream-*) system_display="CentOS Stream $(echo $system_name | cut -d- -f3)" ;;
                    openeuler-*) system_display="openEuler $(echo $system_name | cut -d- -f2)" ;;
                    openanolis-*) system_display="openAnolis $(echo $system_name | cut -d- -f2)" ;;
                    opencloudos-*) system_display="OpencloudOS $(echo $system_name | cut -d- -f2)" ;;
                    *) system_display="$system_name" ;;
                esac
                
                cat >> docs/web/index.html <<EOF
            <div class="repo-card">
                <h3>$system_display</h3>
                <div class="repo-info">包含 $rpm_count 个 RPM 包</div>
                <div class="install-cmd">baseurl=https://ii.pe/$system_name/</div>
            </div>
EOF
            fi
        fi
    done

    cat >> docs/web/index.html <<EOF
        </div>

        <h2>🚀 快速开始</h2>
        <div class="usage-section">
            <h3>1. 导入 GPG 公钥</h3>
            <pre>sudo rpm --import https://ii.pe/RPM-GPG-KEY-iipe</pre>
            
            <h3>2. 添加仓库配置</h3>
            <pre>sudo dnf config-manager --add-repo https://ii.pe/iipe.repo</pre>
            
            <h3>3. 安装 PHP 版本</h3>
            <pre># 安装 PHP 7.4
sudo dnf install iipe-php74 iipe-php74-php-fpm iipe-php74-php-mysqlnd

# 安装 PHP 8.3  
sudo dnf install iipe-php83 iipe-php83-php-fpm iipe-php83-php-mysqlnd

# 安装 PHP 8.4
sudo dnf install iipe-php84 iipe-php84-php-fpm iipe-php84-php-mysqlnd</pre>

            <h3>4. 启用 SCL 环境</h3>
            <pre># 启用 PHP 7.4
scl enable iipe-php74 -- php -v

# 启用 PHP 8.3
scl enable iipe-php83 -- php -v

# 在脚本中使用
#!/bin/bash
source scl_source enable iipe-php83
php your-script.php</pre>

            <h3>5. 管理 PHP-FPM 服务</h3>
            <pre># 启动 PHP 8.3 FPM
sudo systemctl start iipe-php83-php-fpm
sudo systemctl enable iipe-php83-php-fpm

# 查看状态
sudo systemctl status iipe-php83-php-fpm</pre>
        </div>

        <h2>📚 文档与支持</h2>
        <ul>
            <li><a href="iipe.repo">仓库配置文件</a></li>
            <li><a href="RPM-GPG-KEY-iipe">GPG 公钥</a></li>
            <li><strong>项目主页:</strong> <a href="https://github.com/iipe/php-repo">https://github.com/iipe/php-repo</a></li>
            <li><strong>问题反馈:</strong> <a href="https://github.com/iipe/php-repo/issues">GitHub Issues</a></li>
        </ul>

        <div class="footer">
            <p>iipe PHP 多版本仓库 &copy; $(date +%Y) | 构建时间: $(date)</p>
            <p>支持的 PHP 版本: 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5</p>
        </div>
    </div>
</body>
</html>
EOF

    print_success "仓库索引页面已生成: docs/web/index.html"
}

# 生成仓库统计报告
generate_statistics() {
    print_info "生成仓库统计报告..."
    
    local total_repos=0
    local total_rpms=0
    local total_size=0
    
    cat > docs/repository-stats.txt <<EOF
iipe PHP 多版本仓库统计报告
生成时间: $(date)
====================================

EOF

    for system_dir in repo_output/*/; do
        if [ -d "$system_dir" ]; then
            system_name=$(basename "$system_dir")
            rpm_count=$(find "$system_dir" -name "*.rpm" 2>/dev/null | wc -l)
            
            if [ "$rpm_count" -gt 0 ]; then
                system_size=$(du -sh "$system_dir" 2>/dev/null | cut -f1)
                echo "系统: $system_name" >> docs/repository-stats.txt
                echo "  RPM 包数量: $rpm_count" >> docs/repository-stats.txt
                echo "  仓库大小: $system_size" >> docs/repository-stats.txt
                echo "" >> docs/repository-stats.txt
                
                total_repos=$((total_repos + 1))
                total_rpms=$((total_rpms + rpm_count))
            fi
        fi
    done
    
    echo "=====================================" >> docs/repository-stats.txt
    echo "总计:" >> docs/repository-stats.txt
    echo "  支持系统数量: $total_repos" >> docs/repository-stats.txt
    echo "  总 RPM 包数量: $total_rpms" >> docs/repository-stats.txt
    echo "  项目总大小: $(du -sh repo_output 2>/dev/null | cut -f1)" >> docs/repository-stats.txt
    
    print_success "统计报告已生成: docs/repository-stats.txt"
}

# 主函数
main() {
    print_info "=== iipe PHP 仓库发布工具 ==="
    
    # 检查当前目录
    if [ ! -d "repo_output" ]; then
        print_error "repo_output 目录不存在，请先运行构建脚本"
        exit 1
    fi
    
    # 创建文档目录
    mkdir -p docs
    
    # 检查依赖
    check_dependencies
    
    # 设置 GPG
    setup_gpg_key
    export_gpg_public_key
    
    # 处理参数
    if [ $# -eq 0 ]; then
        # 发布所有仓库
        print_info "发布所有系统的仓库..."
        
        for system_dir in repo_output/*/; do
            if [ -d "$system_dir" ]; then
                system_name=$(basename "$system_dir")
                create_repository "$system_name"
            fi
        done
        
    elif [ $# -eq 1 ]; then
        # 发布指定仓库
        local target_system="$1"
        
        if [ "$target_system" = "-h" ] || [ "$target_system" = "--help" ]; then
            show_usage
            exit 0
        fi
        
        if [ ! -d "repo_output/$target_system" ]; then
            print_error "目标系统目录不存在: repo_output/$target_system"
            exit 1
        fi
        
        print_info "发布系统 $target_system 的仓库..."
        create_repository "$target_system"
        
    else
        print_error "参数过多"
        show_usage
        exit 1
    fi
    
    # 生成辅助文件
    generate_index_page
    generate_statistics
    
    print_success "=== 仓库发布完成 ==="
    print_info ""
    print_info "下一步操作:"
    print_info "1. 将 repo_output/ 目录部署到 Web 服务器"
    print_info "2. 配置 Nginx/Apache 提供仓库服务"
    print_info "3. 将 docs/ 目录内容复制到网站根目录"
    print_info ""
    print_info "Web 服务器配置:"
    print_info "  仓库根目录: /var/www/html/repos/"
    print_info "  网站根目录: /var/www/html/"
    print_info "  示例配置: docs/nginx.conf"
}

# 脚本入口
main "$@" 