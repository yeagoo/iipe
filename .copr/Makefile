# Copr构建Makefile for iipe PHP Multi-Version Repository
# 支持多PHP版本和多架构构建

.PHONY: srpm outdir clean help all php74 php80 php81 php82 php83 php84

# 版本配置
PACKAGE_NAME = iipe-php
PACKAGE_VERSION = $(shell date +%Y%m%d)
PACKAGE_RELEASE = 1

# PHP版本列表
PHP_VERSIONS = 7.4 8.0 8.1 8.2 8.3 8.4

# 构建目录
BUILD_DIR = $(PWD)/_build
SRPM_DIR = $(BUILD_DIR)/SRPMS
SOURCES_DIR = $(BUILD_DIR)/SOURCES
SPECS_DIR = $(BUILD_DIR)/SPECS

# 默认目标
all: srpm

# 创建输出目录
outdir:
	@echo "=== 创建构建目录 ==="
	mkdir -p $(BUILD_DIR) $(SRPM_DIR) $(SOURCES_DIR) $(SPECS_DIR)
	@echo "构建目录创建完成"

# 准备源码包
prepare-sources: outdir
	@echo "=== 准备源码包 ==="
	
	# 创建项目源码包
	@echo "打包项目源码..."
	tar --exclude='.git' \
		--exclude='_build' \
		--exclude='*.rpm' \
		--exclude='repo_output' \
		--exclude='logs' \
		--exclude='build-results' \
		--exclude='sources' \
		--exclude='rpmbuild' \
		-czf $(SOURCES_DIR)/$(PACKAGE_NAME)-$(PACKAGE_VERSION).tar.gz \
		--transform 's,^,$(PACKAGE_NAME)-$(PACKAGE_VERSION)/,' \
		*
	
	@echo "源码包准备完成: $(SOURCES_DIR)/$(PACKAGE_NAME)-$(PACKAGE_VERSION).tar.gz"

# 准备规格文件
prepare-specs: outdir
	@echo "=== 准备规格文件 ==="
	
	# 为每个PHP版本创建规格文件
	@for version in $(PHP_VERSIONS); do \
		echo "生成PHP $${version}规格文件..."; \
		php_series=$$(echo $${version} | sed 's/\.//'); \
		sed -e "s/__PHP_VERSION__/$${version}/g" \
			-e "s/__PHP_SERIES__/$${php_series}/g" \
			-e "s/__PACKAGE_VERSION__/$(PACKAGE_VERSION)/g" \
			-e "s/__PACKAGE_RELEASE__/$(PACKAGE_RELEASE)/g" \
			copr-specs/iipe-php.spec.template > $(SPECS_DIR)/$(PACKAGE_NAME)$${php_series}.spec; \
	done
	
	@echo "规格文件准备完成"

# 构建SRPM包
build-srpms: prepare-sources prepare-specs
	@echo "=== 构建SRPM包 ==="
	
	@for version in $(PHP_VERSIONS); do \
		echo "构建PHP $${version} SRPM..."; \
		php_series=$$(echo $${version} | sed 's/\.//'); \
		rpmbuild -bs $(SPECS_DIR)/$(PACKAGE_NAME)$${php_series}.spec \
			--define "_topdir $(BUILD_DIR)" \
			--define "_sourcedir $(SOURCES_DIR)" \
			--define "_srcrpmdir $(SRPM_DIR)" \
			--define "php_version $${version}" \
			--define "php_series $${php_series}" \
			--define "package_version $(PACKAGE_VERSION)" \
			--define "package_release $(PACKAGE_RELEASE)"; \
		if [ $$? -eq 0 ]; then \
			echo "✅ PHP $${version} SRPM构建成功"; \
		else \
			echo "❌ PHP $${version} SRPM构建失败"; \
			exit 1; \
		fi; \
	done
	
	@echo "=== SRPM构建完成 ==="
	@ls -la $(SRPM_DIR)/*.src.rpm

# Copr默认目标
srpm: build-srpms
	@echo "=== Copr SRPM构建完成 ==="
	
	# 将SRPM复制到Copr期望的位置
	@mkdir -p $(outdir)
	@cp $(SRPM_DIR)/*.src.rpm $(outdir)/ 2>/dev/null || true
	
	@echo "SRPM包已准备就绪："
	@ls -la $(outdir)/*.src.rpm 2>/dev/null || echo "警告: 未找到SRPM文件"

# 单独构建特定PHP版本
php74: outdir
	@$(MAKE) build-single-version PHP_VERSION=7.4

php80: outdir
	@$(MAKE) build-single-version PHP_VERSION=8.0

php81: outdir
	@$(MAKE) build-single-version PHP_VERSION=8.1

php82: outdir
	@$(MAKE) build-single-version PHP_VERSION=8.2

php83: outdir
	@$(MAKE) build-single-version PHP_VERSION=8.3

php84: outdir
	@$(MAKE) build-single-version PHP_VERSION=8.4

# 构建单个PHP版本的辅助目标
build-single-version:
	@echo "=== 构建PHP $(PHP_VERSION) ==="
	@php_series=$$(echo $(PHP_VERSION) | sed 's/\.//'); \
	echo "生成PHP $(PHP_VERSION)规格文件..."; \
	sed -e "s/__PHP_VERSION__/$(PHP_VERSION)/g" \
		-e "s/__PHP_SERIES__/$${php_series}/g" \
		-e "s/__PACKAGE_VERSION__/$(PACKAGE_VERSION)/g" \
		-e "s/__PACKAGE_RELEASE__/$(PACKAGE_RELEASE)/g" \
		copr-specs/iipe-php.spec.template > $(SPECS_DIR)/$(PACKAGE_NAME)$${php_series}.spec; \
	echo "构建PHP $(PHP_VERSION) SRPM..."; \
	rpmbuild -bs $(SPECS_DIR)/$(PACKAGE_NAME)$${php_series}.spec \
		--define "_topdir $(BUILD_DIR)" \
		--define "_sourcedir $(SOURCES_DIR)" \
		--define "_srcrpmdir $(SRPM_DIR)" \
		--define "php_version $(PHP_VERSION)" \
		--define "php_series $${php_series}" \
		--define "package_version $(PACKAGE_VERSION)" \
		--define "package_release $(PACKAGE_RELEASE)"

# 验证构建环境
check-env:
	@echo "=== 检查构建环境 ==="
	@echo "当前目录: $(PWD)"
	@echo "包名称: $(PACKAGE_NAME)"
	@echo "包版本: $(PACKAGE_VERSION)"
	@echo "包发布: $(PACKAGE_RELEASE)"
	@echo "PHP版本: $(PHP_VERSIONS)"
	@echo "构建目录: $(BUILD_DIR)"
	
	@echo ""
	@echo "检查必要工具..."
	@which rpmbuild >/dev/null 2>&1 || (echo "❌ rpmbuild未安装"; exit 1)
	@which tar >/dev/null 2>&1 || (echo "❌ tar未安装"; exit 1)
	@which sed >/dev/null 2>&1 || (echo "❌ sed未安装"; exit 1)
	@echo "✅ 构建工具检查通过"
	
	@echo ""
	@echo "检查规格文件模板..."
	@test -f copr-specs/iipe-php.spec.template || (echo "❌ 规格文件模板不存在"; exit 1)
	@echo "✅ 规格文件模板存在"

# 清理构建文件
clean:
	@echo "=== 清理构建文件 ==="
	rm -rf $(BUILD_DIR)
	rm -rf $(outdir)
	@echo "清理完成"

# 显示帮助信息
help:
	@echo "iipe PHP Multi-Version Copr构建系统"
	@echo ""
	@echo "可用目标:"
	@echo "  all        - 构建所有PHP版本的SRPM包 (默认)"
	@echo "  srpm       - 构建SRPM包 (Copr使用)"
	@echo "  php74      - 仅构建PHP 7.4"
	@echo "  php80      - 仅构建PHP 8.0"
	@echo "  php81      - 仅构建PHP 8.1"
	@echo "  php82      - 仅构建PHP 8.2"
	@echo "  php83      - 仅构建PHP 8.3"
	@echo "  php84      - 仅构建PHP 8.4"
	@echo "  check-env  - 检查构建环境"
	@echo "  clean      - 清理构建文件"
	@echo "  help       - 显示此帮助信息"
	@echo ""
	@echo "示例:"
	@echo "  make srpm              # Copr构建"
	@echo "  make php81             # 仅构建PHP 8.1"
	@echo "  make check-env         # 检查环境"
	@echo "  make clean             # 清理文件" 