# iipe PHP Multi-Version Copr使用指南

本文档详细介绍如何使用Copr (Community projects) 来构建、测试和发布iipe PHP多版本仓库。

## 目录

1. [Copr简介](#copr简介)
2. [环境准备](#环境准备)
3. [项目配置](#项目配置)
4. [构建流程](#构建流程)
5. [自动化CI/CD](#自动化cicd)
6. [使用和安装](#使用和安装)
7. [维护管理](#维护管理)
8. [故障排查](#故障排查)
9. [最佳实践](#最佳实践)

## Copr简介

### 什么是Copr

Copr (Community projects) 是Fedora项目提供的免费构建服务，类似于Ubuntu的Launchpad PPA。它提供：

- **多架构支持**: x86_64, aarch64, armhfp, ppc64le, s390x等
- **多发行版支持**: Fedora, EPEL (RHEL/CentOS), Mageia等
- **自动构建**: 支持Git、SCM、Upload等多种源码方式
- **Web界面**: 直观的项目管理和构建监控
- **API/CLI**: 完整的命令行和API支持
- **免费使用**: 开源项目完全免费

### 为什么选择Copr

1. **企业级质量**: 使用与Fedora相同的基础设施
2. **多架构原生支持**: 无需额外配置即可构建ARM64
3. **自动化友好**: 完善的API和CLI工具
4. **社区认可**: Fedora官方推荐的第三方仓库平台
5. **零成本**: 完全免费，无限制使用

## 环境准备

### 1. 安装依赖工具

#### 在RHEL/CentOS/AlmaLinux上：

```bash
# 安装EPEL仓库
sudo dnf install -y epel-release

# 安装Copr CLI和相关工具
sudo dnf install -y copr-cli git rpm-build rpmdevtools
```

#### 在Fedora上：

```bash
# 安装Copr CLI和相关工具
sudo dnf install -y copr-cli git rpm-build rpmdevtools
```

#### 在Ubuntu/Debian上：

```bash
# 安装Python和pip
sudo apt-get update
sudo apt-get install -y python3-pip git rpm

# 通过pip安装copr-cli
pip3 install copr-cli
```

### 2. 设置Copr认证

#### 获取API令牌

1. 访问 [Copr API页面](https://copr.fedorainfracloud.org/api/)
2. 使用GitHub、Google或FAS账号登录
3. 获取API配置信息

#### 配置认证文件

```bash
# 创建配置目录
mkdir -p ~/.config

# 创建Copr配置文件
cat > ~/.config/copr << EOF
[copr-cli]
login = your-username
username = your-username
token = your-api-token
copr_url = https://copr.fedorainfracloud.org
EOF

# 设置安全权限
chmod 600 ~/.config/copr
```

#### 验证配置

```bash
# 验证认证是否正确
copr-cli whoami
```

应该显示您的用户名。

### 3. 克隆iipe项目

```bash
# 克隆项目
git clone https://github.com/yourusername/iipe.git
cd iipe

# 设置可执行权限
chmod +x copr-build.sh
```

## 项目配置

### 1. Copr项目结构

```
iipe/
├── .copr/
│   └── Makefile              # Copr构建脚本
├── copr-configs/
│   └── iipe-php.yml          # 项目配置文件
├── copr-specs/
│   └── iipe-php.spec.template   # RPM规格文件模板
├── copr-build.sh             # Copr管理脚本
└── .github/workflows/
    └── copr-build.yml        # GitHub Actions自动化
```

### 2. 主要配置文件

#### `.copr/Makefile`

Copr构建系统的核心文件，定义如何构建SRPM包：

- 支持多PHP版本构建
- 自动生成规格文件
- 处理源码打包
- 提供调试和清理功能

#### `copr-specs/iipe-php.spec.template`

RPM规格文件模板，支持：

- 多版本PHP包（7.4-8.4）
- 多架构构建（x86_64, aarch64）
- 子包分离（devel, extensions, monitoring）
- 完整的安装脚本

#### `copr-configs/iipe-php.yml`

项目配置文件，包含：

- 支持的操作系统和架构
- 构建设置和超时配置
- 权限和仓库设置
- 外部依赖仓库

### 3. 环境变量配置

```bash
# 设置环境变量
export COPR_USER="your-copr-username"
export COPR_PROJECT="iipe-php"
export GIT_URL="https://github.com/yourusername/iipe.git"
export GIT_BRANCH="main"
```

## 构建流程

### 1. 创建Copr项目

```bash
# 使用脚本创建项目
./copr-build.sh -u your-username create-project

# 或手动创建
copr-cli create iipe-php \
    --description "iipe PHP Multi-Version Enterprise Repository" \
    --chroot epel-9-x86_64 \
    --chroot epel-9-aarch64 \
    --enable-net=on
```

### 2. 构建单个PHP版本

```bash
# 构建PHP 8.1 (x86_64和aarch64)
./copr-build.sh -u your-username -v 8.1 build

# 构建特定架构
./copr-build.sh -u your-username -v 8.2 -c "epel-9-x86_64" build
```

### 3. 批量构建所有版本

```bash
# 构建所有PHP版本
./copr-build.sh -u your-username build-all

# 指定特定架构
./copr-build.sh -u your-username -c "epel-9-x86_64,epel-9-aarch64" build-all
```

### 4. 监控构建进度

```bash
# 查看构建列表
./copr-build.sh -u your-username list-builds

# 监控特定构建
./copr-build.sh -u your-username watch 12345

# 查看项目状态
./copr-build.sh -u your-username status
```

### 5. 本地测试构建

```bash
# 使用Makefile进行本地测试
cd .copr
make check-env      # 检查环境
make php81          # 构建PHP 8.1
make clean          # 清理文件
```

## 自动化CI/CD

### 1. GitHub Actions配置

项目包含完整的GitHub Actions工作流 (`.github/workflows/copr-build.yml`)，支持：

#### 触发条件

- **推送触发**: main/develop分支的相关文件变更
- **PR触发**: 针对main分支的Pull Request
- **手动触发**: 支持自定义PHP版本和架构
- **定时触发**: 每周日自动构建

#### 工作流程

1. **验证阶段**: 检查配置文件语法和依赖
2. **构建阶段**: 并行构建多个PHP版本
3. **测试阶段**: 在容器中测试包安装
4. **通知阶段**: Slack通知和Release创建
5. **清理阶段**: 清理旧构建和资源

### 2. 设置GitHub Secrets

在GitHub仓库设置中添加以下Secrets：

```
COPR_USER=your-copr-username
COPR_TOKEN=your-copr-api-token
SLACK_WEBHOOK_URL=your-slack-webhook-url (可选)
```

### 3. 手动触发构建

在GitHub Actions页面：

1. 选择 "Copr Build - iipe PHP Multi-Version"
2. 点击 "Run workflow"
3. 配置参数：
   - PHP版本: `8.1,8.2,8.3`
   - 目标架构: `epel-9-x86_64,epel-9-aarch64`
   - 强制重新构建: 是/否

## 使用和安装

### 1. 用户安装指南

#### 启用Copr仓库

```bash
# 在RHEL/CentOS/AlmaLinux上
sudo dnf copr enable your-username/iipe-php

# 或手动添加仓库文件
sudo tee /etc/yum.repos.d/iipe-php.repo << EOF
[copr:copr.fedorainfracloud.org:your-username:iipe-php]
name=Copr repo for iipe-php owned by your-username
baseurl=https://download.copr.fedorainfracloud.org/results/your-username/iipe-php/epel-\$releasever-\$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/your-username/iipe-php/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF
```

#### 安装PHP包

```bash
# 查看可用PHP版本
dnf list available | grep iipe-php

# 安装PHP 8.1
sudo dnf install iipe-php81

# 安装开发工具
sudo dnf install iipe-php81-devel

# 安装扩展包
sudo dnf install iipe-php81-extensions
```

#### 使用构建工具

```bash
# 查看可用命令
iipe-php81-build --help
iipe-php81-batch-build --help

# 构建PHP包
iipe-php81-build 8.1.27 almalinux-9

# 批量构建
iipe-php81-batch-build -v 8.1 -s almalinux-9,rocky-linux-9
```

### 2. 仓库地址

- **项目主页**: https://copr.fedorainfracloud.org/coprs/your-username/iipe-php/
- **下载地址**: https://download.copr.fedorainfracloud.org/results/your-username/iipe-php/
- **API接口**: https://copr.fedorainfracloud.org/api_3/package?ownername=your-username&projectname=iipe-php

### 3. 架构支持

| 架构 | 支持状态 | 说明 |
|------|----------|------|
| x86_64 | ✅ 完全支持 | Intel/AMD 64位 |
| aarch64 | ✅ 完全支持 | ARM 64位 |
| armhfp | ⚠️ 实验性 | ARM 32位硬浮点 |
| ppc64le | ❌ 暂不支持 | IBM Power |
| s390x | ❌ 暂不支持 | IBM Z |

## 维护管理

### 1. 项目维护

#### 更新项目设置

```bash
# 修改项目描述
copr-cli modify iipe-php --description "新的描述"

# 添加新的chroot
copr-cli edit-chroot your-username/iipe-php/epel-10-x86_64

# 查看项目详情
copr-cli get-project your-username/iipe-php
```

#### 管理构建

```bash
# 取消构建
copr-cli cancel-build 12345

# 重新提交构建
copr-cli resubmit-build 12345

# 删除构建
copr-cli delete-build 12345
```

### 2. 版本管理

#### 发布新版本

1. 更新版本号：
   ```bash
   # 修改.copr/Makefile中的版本
   PACKAGE_VERSION = $(shell date +%Y%m%d)
   ```

2. 提交构建：
   ```bash
   ./copr-build.sh -u your-username build-all
   ```

3. 验证构建：
   ```bash
   ./copr-build.sh -u your-username status
   ```

#### 版本回滚

```bash
# 禁用失败的包
copr-cli delete-package your-username/iipe-php iipe-php81

# 重新构建稳定版本
./copr-build.sh -u your-username -v 8.1 build
```

### 3. 监控和告警

#### 构建状态监控

```bash
# 定期检查构建状态
crontab -e
# 添加：0 */6 * * * /path/to/copr-build.sh -u your-username status
```

#### 邮件通知

在Copr Web界面设置：
1. 访问项目设置
2. 启用邮件通知
3. 设置通知邮箱

### 4. 清理和优化

#### 清理旧构建

```bash
# 列出所有构建
copr-cli list-builds your-username/iipe-php

# 删除7天前的失败构建
for build in $(copr-cli list-builds your-username/iipe-php | grep failed | awk '{print $1}'); do
    copr-cli delete-build $build
done
```

#### 存储优化

```bash
# 查看存储使用
copr-cli get-project your-username/iipe-php | grep storage

# 设置自动删除策略
copr-cli modify iipe-php --delete-after-days 30
```

## 故障排查

### 1. 常见问题

#### 构建失败

**问题**: 构建在%prep阶段失败
```
+ /usr/bin/tar -xof /builddir/build/SOURCES/iipe-php-20240704.tar.gz
/usr/bin/tar: Error is not recoverable: exiting now
```

**解决方案**:
1. 检查源码包完整性：
   ```bash
   cd .copr
   make prepare-sources
   tar -tzf _build/SOURCES/iipe-php-*.tar.gz | head
   ```

2. 验证Makefile语法：
   ```bash
   make -n srpm
   ```

#### 依赖问题

**问题**: 缺少构建依赖
```
No package 'mock' available.
```

**解决方案**:
1. 更新BuildRequires：
   ```spec
   BuildRequires: mock
   BuildRequires: epel-release
   ```

2. 添加外部仓库：
   ```bash
   copr-cli edit-chroot your-username/iipe-php/epel-9-x86_64 \
       --repos 'https://download.fedoraproject.org/pub/epel/9/Everything/$basearch/'
   ```

#### 权限问题

**问题**: 无法访问Copr项目
```
Error: You are not allowed to access project
```

**解决方案**:
1. 检查项目权限：
   ```bash
   copr-cli get-project your-username/iipe-php
   ```

2. 添加协作者：
   ```bash
   copr-cli request-permissions your-username/iipe-php --permissions builder
   ```

### 2. 调试技巧

#### 本地调试

```bash
# 启用调试模式
export DEBUG=true
./copr-build.sh -u your-username -d build

# 检查Makefile
cd .copr
make check-env
make -n srpm
```

#### 构建日志分析

```bash
# 获取构建日志
copr-cli get-build 12345

# 下载详细日志
wget "https://download.copr.fedorainfracloud.org/results/your-username/iipe-php/epel-9-x86_64/build.log"
```

#### 容器调试

```bash
# 使用相同环境测试
podman run -it --rm fedora:39 bash
dnf install -y rpm-build mock
# 手动执行构建步骤
```

### 3. 性能优化

#### 构建加速

1. **并行构建**:
   ```bash
   # 在Makefile中使用并行任务
   PHP_VERSIONS = 8.1 8.2 8.3
   build-all: $(PHP_VERSIONS)
   $(PHP_VERSIONS):
       @$(MAKE) build-single-version PHP_VERSION=$@
   ```

2. **缓存优化**:
   ```bash
   # 启用网络访问缓存
   copr-cli modify iipe-php --enable-net=on
   ```

3. **资源限制调整**:
   ```bash
   # 增加内存限制
   copr-cli modify iipe-php --memory-limit 4096
   ```

## 最佳实践

### 1. 开发流程

#### 分支策略

```
main (生产)
├── develop (开发)
├── feature/copr-integration (功能)
└── hotfix/build-fix (热修复)
```

#### 测试流程

1. **本地测试**: 使用Mock进行本地构建测试
2. **开发环境**: 在develop分支进行Copr测试
3. **预发布**: 创建pre-release进行完整测试
4. **生产发布**: 合并到main分支自动发布

### 2. 版本管理

#### 语义化版本

```
格式: YYYY.MM.DD-{BUILD_NUMBER}
示例: 2024.07.04-1
```

#### 标签策略

```bash
# 发布标签
git tag -a v2024.07.04 -m "Release v2024.07.04"

# Copr构建标签
git tag -a copr-build-123 -m "Copr Build #123"
```

### 3. 安全考虑

#### Secrets管理

1. **GitHub Secrets**: 存储敏感信息
2. **环境分离**: 开发/生产使用不同token
3. **权限最小化**: 仅给予必要权限

#### 签名验证

```bash
# 启用GPG签名
copr-cli modify iipe-php --enable-gpg

# 验证包签名
rpm --checksig package.rpm
```

### 4. 监控和告警

#### 关键指标

- 构建成功率
- 构建时间
- 下载量统计
- 错误日志数量

#### 告警设置

```bash
# 构建失败告警
./copr-build.sh monitor --alert-on-failure

# 磁盘空间告警
df -h | awk '$5 > 80 {print "Warning: " $1 " is " $5 " full"}'
```

### 5. 文档维护

#### 用户文档

- 安装指南
- 使用示例
- 故障排查
- FAQ

#### 开发文档

- API文档
- 构建说明
- 贡献指南
- 变更日志

## 总结

Copr为iipe PHP多版本仓库项目提供了理想的构建和分发平台，具有以下优势：

### 核心优势

1. **多架构原生支持**: 无缝支持x86_64和ARM64架构
2. **企业级稳定性**: 基于Fedora基础设施，质量可靠
3. **完全自动化**: 从代码提交到包发布全程自动化
4. **零运维成本**: 无需维护构建服务器和基础设施
5. **社区友好**: Fedora官方推荐，用户接受度高

### 技术特点

- **多版本并行**: 同时支持PHP 7.4-8.4全生命周期
- **智能构建**: 仅在相关文件变更时触发构建
- **质量保证**: 包含完整的测试和验证流程
- **监控完善**: 实时构建状态和结果通知
- **扩展性强**: 易于添加新PHP版本和操作系统支持

### 使用建议

1. **优先使用自动化**: 通过GitHub Actions实现CI/CD
2. **合理规划版本**: 根据用户需求确定支持的PHP版本
3. **监控构建质量**: 定期检查构建成功率和错误日志
4. **及时响应问题**: 建立快速的问题响应机制
5. **文档保持更新**: 确保用户文档与实际功能同步

通过Copr平台，iipe项目能够为用户提供高质量、多架构的PHP包，满足现代云原生和边缘计算环境的需求。 