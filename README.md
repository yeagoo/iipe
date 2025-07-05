# iipe - PHP 多版本仓库项目

## 📋 项目简介

iipe (Intelligent Infrastructure for PHP Ecosystem) 是一个专业的 PHP 多版本软件仓库项目，旨在为 Red Hat 生态系统及其衍生版本提供完整的 PHP 生命周期版本支持。项目采用 SCL（Software Collections）风格的 YUM/DNF 软件仓库架构，支持多个操作系统同时运行不同版本的 PHP。

### 🎯 项目目标

- 🔄 **多版本并存**: 支持 PHP 7.4 到 8.3+ 的所有版本同时安装
- 🌐 **广泛兼容**: 覆盖 13 个主流 Red Hat 生态操作系统
- 🚀 **自动化构建**: 完整的 CI/CD 流水线和自动化打包
- 🛡️ **生产就绪**: 包含完整的监控、维护和安全扫描工具
- 📦 **标准化**: 遵循 RPM 打包最佳实践和 Fedora 包装指南

## 🖥️ 支持的操作系统

| 操作系统 | 版本 | 架构 | 状态 |
|---------|------|------|------|
| **Red Hat Enterprise Linux** | 9, 10 | x86_64 | ✅ 支持 |
| **CentOS Stream** | 9, 10 | x86_64 | ✅ 支持 |
| **AlmaLinux** | 9, 10 | x86_64 | ✅ 支持 |
| **Rocky Linux** | 9, 10 | x86_64 | ✅ 支持 |
| **Oracle Linux** | 9, 10 | x86_64 | ✅ 支持 |
| **OpenEuler** | 24.03 | x86_64 | ✅ 支持 |
| **OpenAnolis** | 23 | x86_64 | ✅ 支持 |
| **OpenCloudOS** | 9 | x86_64 | ✅ 支持 |

## ✨ 核心功能特性

### 📦 构建系统
- **自动化构建**: `build.sh` - 单系统构建脚本
- **批量构建**: `batch-build.sh` - 多系统并行构建
- **快速开始**: `quick-start.sh` - 一键项目初始化
- **测试构建**: `test-builds.sh` - 构建系统验证

### 🔄 CI/CD 集成
- **GitHub Actions**: 完整的 GitHub 工作流
- **GitLab CI**: GitLab CI/CD 配置
- **Jenkins**: Jenkins 流水线支持
- **Docker**: 容器化构建环境

### 🚀 仓库发布
- **自动发布**: `publish.sh` - 仓库元数据生成和发布
- **镜像同步**: 多镜像站点同步支持
- **CDN 分发**: CDN 加速配置

## 🛠️ 运维工具套件

### 📊 系统监控 (`monitor.sh`)
```bash
./monitor.sh status              # 系统状态总览
./monitor.sh check-builds        # 构建状态检查
./monitor.sh check-repos         # 仓库健康状态
./monitor.sh start-daemon        # 启动监控守护进程
./monitor.sh generate-report     # 生成监控报告
```

**功能特性:**
- 实时系统状态监控
- 构建进度和结果跟踪
- 仓库健康状态检查
- 磁盘使用情况监控
- HTML/CSV 格式报告生成

### 🔧 系统维护 (`maintenance.sh`)
```bash
./maintenance.sh auto-maintain   # 自动维护（推荐）
./maintenance.sh cleanup         # 清理临时文件
./maintenance.sh backup          # 备份重要数据
./maintenance.sh health-check    # 系统健康检查
./maintenance.sh optimize        # 系统优化
```

**功能特性:**
- 自动清理过期文件和日志
- 配置文件和数据备份/恢复
- 系统性能优化
- 磁盘空间管理
- 权限和依赖检查

### 🛡️ 安全扫描 (`security-scanner.sh`)
```bash
./security-scanner.sh quick-scan    # 快速安全扫描
./security-scanner.sh full-scan     # 完整安全扫描
./security-scanner.sh scan-packages # RPM包漏洞扫描
./security-scanner.sh scan-configs  # 配置文件安全检查
```

**功能特性:**
- CVE 漏洞数据库扫描
- 依赖包安全检查
- 配置文件安全审计
- 多格式安全报告（HTML/JSON/文本）
- 严重级别分类和风险评估

### 🔍 故障排查 (`troubleshoot.sh`)
```bash
./troubleshoot.sh diagnose         # 全面系统诊断
./troubleshoot.sh check-build      # 构建问题检查
./troubleshoot.sh fix-common       # 自动修复常见问题
./troubleshoot.sh interactive      # 交互式故障排查
```

**功能特性:**
- 智能问题诊断和分析
- 构建环境完整性检查
- 依赖关系验证
- 权限和网络连接诊断
- 自动修复常见问题
- 已知问题数据库

### 🔄 镜像同步 (`mirror-sync.sh`)
```bash
./mirror-sync.sh add-mirror       # 添加镜像站点
./mirror-sync.sh sync             # 同步所有镜像
./mirror-sync.sh check-mirrors    # 检查镜像状态
./mirror-sync.sh setup-cdn        # 配置CDN分发
```

**支持的同步方式:**
- **rsync**: 高效增量同步
- **ssh/scp**: 安全传输
- **ftp**: 传统FTP同步
- **s3**: 云存储同步
- **http**: HTTP API同步

### 📢 通知系统 (`notification.sh`)
```bash
./notification.sh setup           # 初始化通知系统
./notification.sh add-provider    # 添加通知提供商
./notification.sh send            # 发送通知
./notification.sh test            # 测试通知配置
```

**支持的通知方式:**
- **邮件通知**: SMTP邮件发送
- **Webhook**: HTTP回调通知
- **Slack**: Slack消息推送
- **微信**: 微信企业号通知

### ⬆️ 升级管理 (`upgrade-manager.sh`)
```bash
./upgrade-manager.sh check-versions  # 检查版本信息
./upgrade-manager.sh scan-updates    # 扫描可用更新
./upgrade-manager.sh create-plan     # 创建升级计划
./upgrade-manager.sh execute-plan    # 执行升级
./upgrade-manager.sh rollback        # 回滚操作
```

**功能特性:**
- 自动版本检测和更新扫描
- 升级计划创建和管理
- 风险评估和兼容性检查
- 自动备份和回滚机制
- 升级进度监控

### 🗄️ 缓存优化 (`cache-optimizer.sh`)
```bash
./cache-optimizer.sh status       # 缓存状态概览
./cache-optimizer.sh analyze      # 缓存使用分析
./cache-optimizer.sh optimize     # 缓存优化
./cache-optimizer.sh clean        # 缓存清理
```

**缓存类型支持:**
- **Mock缓存**: Mock构建环境缓存
- **构建缓存**: 编译产物缓存
- **源码缓存**: 源代码包缓存
- **RPM缓存**: 构建完成的RPM包缓存
- **仓库缓存**: 仓库元数据缓存

### 🚀 压力测试 (`stress-tester.sh`)
```bash
./stress-tester.sh benchmark      # 性能基准测试
./stress-tester.sh repo-stress    # 仓库服务器压力测试
./stress-tester.sh download-test  # 并发下载测试
./stress-tester.sh build-stress   # 构建系统压力测试
```

**测试类型:**
- **轻度测试**: 10并发，适合开发环境
- **普通测试**: 50并发，适合测试环境
- **重度测试**: 200并发，适合生产验证
- **极限测试**: 1000并发，极限性能测试

## 🚀 快速开始

### 1. 环境准备

```bash
# 安装依赖
sudo dnf install -y mock rpm-build createrepo_c

# 克隆项目
git clone https://github.com/your-org/iipe.git
cd iipe

# 初始化项目
./init-project.sh
```

### 2. 快速启动

```bash
# 一键启动（推荐新用户）
./quick-start.sh

# 或者手动步骤
chmod +x *.sh                    # 添加执行权限
./maintenance.sh health-check    # 健康检查
./build.sh almalinux-9          # 构建单个系统
```

### 3. 批量构建

```bash
# 构建所有支持的系统
./batch-build.sh

# 构建特定系统组
./batch-build.sh --systems "almalinux-9,rocky-linux-9"

# 并行构建（4个进程）
./batch-build.sh --parallel 4
```

### 4. 发布仓库

```bash
# 生成仓库元数据并发布
./publish.sh

# 发布到指定目录
./publish.sh --output /var/www/html/repositories
```

## 📁 项目结构

```
iipe/
├── 📄 核心脚本
│   ├── init-project.sh          # 项目初始化
│   ├── quick-start.sh           # 快速开始
│   ├── build.sh                 # 单系统构建
│   ├── batch-build.sh           # 批量构建
│   ├── test-builds.sh           # 构建测试
│   └── publish.sh               # 仓库发布
│
├── 🛠️ 运维工具
│   ├── monitor.sh               # 系统监控
│   ├── maintenance.sh           # 系统维护
│   ├── security-scanner.sh      # 安全扫描
│   ├── troubleshoot.sh          # 故障排查
│   ├── mirror-sync.sh           # 镜像同步
│   ├── notification.sh          # 通知系统
│   ├── upgrade-manager.sh       # 升级管理
│   ├── cache-optimizer.sh       # 缓存优化
│   └── stress-tester.sh         # 压力测试
│
├── ⚙️ 配置文件
│   ├── mock_configs/            # Mock构建配置
│   ├── macros.iipe-php         # RPM宏定义
│   └── templates/              # 模板文件
│
├── 🏗️ 系统目录
│   ├── almalinux-9/            # AlmaLinux 9 构建环境
│   ├── rocky-linux-9/          # Rocky Linux 9 构建环境
│   └── ... (其他系统)
│
├── 🐳 容器化
│   ├── docker/                 # Docker配置
│   ├── docker-compose.yml      # Docker Compose
│   └── docker-build.sh         # 容器构建
│
├── 🔄 CI/CD
│   ├── .github/workflows/      # GitHub Actions
│   ├── .gitlab-ci.yml         # GitLab CI
│   └── ci/jenkins/            # Jenkins配置
│
└── 📊 运行时数据
    ├── logs/                   # 日志文件
    ├── *-cache/               # 各类缓存目录
    ├── *-configs/             # 工具配置目录
    ├── *-reports/             # 报告输出目录
    └── upgrade-backups/       # 升级备份目录
```

## 🔧 系统要求

### 基础要求
- **操作系统**: Red Hat Enterprise Linux 9+ 或兼容系统
- **架构**: x86_64
- **内存**: 最少 4GB，推荐 8GB+
- **磁盘**: 最少 50GB 可用空间
- **网络**: 稳定的互联网连接

### 软件依赖
```bash
# 必需软件包
mock rpm-build createrepo_c

# 推荐软件包
git curl wget rsync bc jq

# 可选软件包（用于高级功能）
ab siege wrk                # 压力测试工具
mailx ssmtp                 # 邮件通知
```

## 📖 详细使用指南

### 构建自定义PHP版本

1. **添加新的PHP版本规格文件**:
```bash
# 在对应系统目录下创建spec文件
cp templates/php.spec.template almalinux-9/php82.spec
# 编辑spec文件，修改版本号和配置
```

2. **修改构建配置**:
```bash
# 编辑构建脚本中的版本列表
vim build.sh
# 添加新版本到 PHP_VERSIONS 数组
```

3. **执行构建**:
```bash
./build.sh almalinux-9 php82
```

### 配置镜像同步

1. **添加rsync镜像**:
```bash
./mirror-sync.sh add-mirror \
  -m primary \
  -t rsync \
  -u rsync://mirror.example.com/iipe/ \
  -p /repositories/
```

2. **添加S3镜像**:
```bash
./mirror-sync.sh add-mirror \
  -m s3-backup \
  -t s3 \
  -u s3://my-bucket/iipe/ \
  -k ~/.aws/credentials
```

3. **执行同步**:
```bash
# 同步所有镜像
./mirror-sync.sh sync

# 同步指定镜像
./mirror-sync.sh sync-single -m primary
```

### 配置通知系统

1. **设置邮件通知**:
```bash
./notification.sh add-provider \
  -p email-admin \
  -t email \
  -r admin@example.com \
  -c notification-configs/smtp.conf
```

2. **设置Slack通知**:
```bash
./notification.sh add-provider \
  -p slack-devops \
  -t slack \
  -u https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK \
  -k YOUR_SLACK_TOKEN
```

3. **发送测试通知**:
```bash
./notification.sh test -p slack-devops
```

## 🔍 故障排查

### 常见问题

#### 构建失败
```bash
# 检查构建环境
./troubleshoot.sh check-build

# 检查依赖
./troubleshoot.sh check-deps

# 自动修复常见问题
./troubleshoot.sh fix-common
```

#### 权限问题
```bash
# 检查权限设置
./troubleshoot.sh check-perms

# 修复Mock权限
sudo usermod -a -G mock $USER
```

#### 网络连接问题
```bash
# 检查网络连接
./troubleshoot.sh check-network

# 检查代理设置
echo $http_proxy $https_proxy
```

### 日志查看

```bash
# 查看构建日志
tail -f logs/build_$(date +%Y%m%d).log

# 查看监控日志
tail -f logs/monitor/monitor_$(date +%Y%m%d).log

# 查看错误日志
grep ERROR logs/*.log
```

## 📈 性能优化

### 缓存优化
```bash
# 分析缓存使用情况
./cache-optimizer.sh analyze

# 自动优化缓存
./cache-optimizer.sh optimize -l balanced

# 清理过期缓存
./cache-optimizer.sh clean -a 7
```

### 并行构建优化
```bash
# 根据CPU核心数设置并行度
./batch-build.sh --parallel $(nproc)

# 限制内存使用
export MOCK_MEMORY_LIMIT=2048M
```

## 🤝 贡献指南

1. **Fork 项目**
2. **创建功能分支**: `git checkout -b feature/amazing-feature`
3. **提交更改**: `git commit -m 'Add amazing feature'`
4. **推送分支**: `git push origin feature/amazing-feature`
5. **提交Pull Request**

### 开发规范

- 所有脚本必须包含详细的帮助信息
- 新功能需要添加相应的测试
- 遵循Shell脚本最佳实践
- 更新文档和示例

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 🆘 获取帮助

- **问题反馈**: [GitHub Issues](https://github.com/your-org/iipe/issues)
- **功能请求**: [GitHub Discussions](https://github.com/your-org/iipe/discussions)
- **邮件联系**: support@example.com

## 🔗 相关链接

- [RPM打包指南](https://rpm-packaging-guide.github.io/)
- [Mock构建系统](https://github.com/rpm-software-management/mock)
- [PHP官方文档](https://www.php.net/docs.php)
- [Red Hat开发者指南](https://developers.redhat.com/)

---

<div align="center">

**⭐ 如果这个项目对您有帮助，请给我们一个星标！ ⭐**

Made with ❤️ by the iipe team

</div> 