#!/bin/bash

# iipe (ii.pe) - PHP Multi-Version Repository Project Initialization Script
# 用于为多个 Linux 发行版创建 PHP 全版本生命周期支持的 YUM/DNF 软件仓库

set -e

echo "正在初始化 iipe 项目目录结构..."

# 创建主要目录结构
echo "创建主要目录..."
mkdir -p sources
mkdir -p repo_output
mkdir -p mock_configs
mkdir -p patches
mkdir -p scripts
mkdir -p docs

# RHEL 9 系列发行版
echo "创建 RHEL 9 系列目录..."
mkdir -p almalinux-9
mkdir -p oraclelinux-9
mkdir -p rockylinux-9
mkdir -p rhel-9
mkdir -p centos-stream-9

# RHEL 10 系列发行版
echo "创建 RHEL 10 系列目录..."
mkdir -p almalinux-10
mkdir -p oraclelinux-10
mkdir -p rockylinux-10
mkdir -p rhel-10
mkdir -p centos-stream-10

# 其他现代发行版
echo "创建其他发行版目录..."
mkdir -p openeuler-24.03
mkdir -p openanolis-23
mkdir -p opencloudos-9

# 创建对应的仓库输出目录
echo "创建仓库输出目录..."
for distro in almalinux-{9,10} oraclelinux-{9,10} rockylinux-{9,10} rhel-{9,10} centos-stream-{9,10} openeuler-24.03 openanolis-23 opencloudos-9; do
    mkdir -p "repo_output/$distro"
done

echo "项目目录结构创建完成！"
echo ""
echo "目录结构："
echo "├── sources/                 # 共享源码目录"
echo "├── repo_output/             # 仓库产物输出目录"
echo "├── mock_configs/            # Mock 配置文件目录"
echo "├── patches/                 # 补丁文件目录"
echo "├── scripts/                 # 构建脚本目录"
echo "├── docs/                    # 文档目录"
echo "├── [distro-version]/        # 各发行版目录，包含独立的 .spec 文件"
echo "│   ├── almalinux-9/"
echo "│   ├── almalinux-10/"
echo "│   ├── rockylinux-9/"
echo "│   ├── rockylinux-10/"
echo "│   ├── oraclelinux-9/"
echo "│   ├── oraclelinux-10/"
echo "│   ├── rhel-9/"
echo "│   ├── rhel-10/"
echo "│   ├── centos-stream-9/"
echo "│   ├── centos-stream-10/"
echo "│   ├── openeuler-24.03/"
echo "│   ├── openanolis-23/"
echo "│   └── opencloudos-9/"
echo ""
echo "下一步：运行相应的脚本配置 mock 环境和创建 RPM 打包文件。" 