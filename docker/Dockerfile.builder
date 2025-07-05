# =============================================================================
# iipe PHP 构建环境 Docker 镜像
# 
# 功能：
# - 完整的RPM构建环境
# - Mock构建支持
# - 多发行版支持
# - 自动化构建工具
# =============================================================================

FROM centos:stream9

LABEL maintainer="iipe PHP Team <admin@ii.pe>" \
      version="1.0.0" \
      description="iipe PHP Build Environment" \
      usage="docker run --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:rw iipe-php-builder"

# 环境变量
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Asia/Shanghai \
    MOCK_CONFIG_DIR=/etc/mock \
    BUILD_USER=builder \
    BUILD_UID=1000 \
    BUILD_GID=1000

# 安装基础包和构建工具
RUN dnf update -y && \
    dnf install -y epel-release && \
    dnf install -y \
        # 基础开发工具
        gcc gcc-c++ make autoconf automake libtool \
        # RPM构建工具
        rpm-build rpm-devel rpmdevtools rpmlint \
        # Mock构建环境
        mock \
        # 仓库管理工具
        createrepo_c \
        # 网络和下载工具
        wget curl git rsync \
        # 压缩和解压工具
        tar gzip bzip2 xz unzip \
        # 文本处理工具
        sed awk grep \
        # 系统工具
        which file findutils \
        # Python和相关工具
        python3 python3-pip \
        # 其他有用工具
        vim nano tree htop \
        # 清理缓存
    && dnf clean all \
    && rm -rf /var/cache/dnf

# 创建构建用户
RUN groupadd -g ${BUILD_GID} ${BUILD_USER} && \
    useradd -u ${BUILD_UID} -g ${BUILD_GID} -m -s /bin/bash ${BUILD_USER} && \
    usermod -aG mock ${BUILD_USER}

# 配置sudo权限
RUN echo "${BUILD_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# 创建必要的目录
RUN mkdir -p \
        /workspace \
        /build-output \
        /mock-configs \
        /rpm-sources \
    && chown -R ${BUILD_USER}:${BUILD_USER} \
        /workspace \
        /build-output \
        /mock-configs \
        /rpm-sources

# 配置Git（用于CI/CD环境）
RUN git config --system user.name "iipe Builder" && \
    git config --system user.email "builder@ii.pe" && \
    git config --system init.defaultBranch main

# 安装额外的Python包
RUN pip3 install --no-cache-dir \
        jinja2 \
        pyyaml \
        requests

# 复制Mock配置文件
COPY mock-configs/ /etc/mock/

# 复制构建脚本
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# 创建入口脚本
RUN cat > /usr/local/bin/docker-entrypoint.sh << 'EOF'
#!/bin/bash
set -e

# 初始化系统服务（如果需要）
if [ "$1" = "--init" ]; then
    # 启动必要的系统服务
    echo "初始化构建环境..."
    
    # 检查特权模式
    if [ ! -w /sys/fs/cgroup ]; then
        echo "警告: 未检测到特权模式，某些功能可能受限"
    fi
    
    shift
fi

# 如果是构建用户身份运行
if [ "$(id -u)" = "0" ]; then
    # 切换到构建用户
    exec gosu ${BUILD_USER} "$@"
else
    # 直接执行命令
    exec "$@"
fi
EOF

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# 安装gosu用于用户切换
RUN wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.16/gosu-amd64" && \
    chmod +x /usr/local/bin/gosu && \
    gosu nobody true

# 设置工作目录
WORKDIR /workspace

# 切换到构建用户
USER ${BUILD_USER}

# 暴露端口（如果需要Web服务）
EXPOSE 8080

# 设置卷
VOLUME ["/workspace", "/build-output"]

# 入口点
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# 默认命令
CMD ["/bin/bash"] 