# 导入通用宏定义
%include %{_sourcedir}/../macros.iipe-php

# 基本信息
%global scl %{scl}
%global scl_name_base php
%global scl_name_version %{php_version_major}%{php_version_minor}
%global scl_module_spec %{scl}

# 版本特定变量
%global ini_name 40-%{scl_name_base}

# PHP 7.4 特殊处理
%if "%{php_version_short}" == "7.4"
%global need_libzip_compat 1
%global need_oniguruma5 1
%else
%global need_libzip_compat 0
%global need_oniguruma5 0
%endif

# PHP 8.0+ 特殊处理
%if 0%{?php_version_major} >= 8
%global has_jit 1
%global json_builtin 1
%else
%global has_jit 0
%global json_builtin 0
%endif

# PHP 8.1+ 特殊处理
%if 0%{?php_version_major} >= 8 && 0%{?php_version_minor} >= 1
%global has_fibers 1
%global has_enum 1
%else
%global has_fibers 0
%global has_enum 0
%endif

# PHP 8.4+ 特殊处理
%if 0%{?php_version_major} >= 8 && 0%{?php_version_minor} >= 4
%global has_property_hooks 1
%global new_random_api 1
%else
%global has_property_hooks 0
%global new_random_api 0
%endif

Summary: PHP %{php_version} as a Software Collection
Name: %{scl}
Version: %{php_version}
Release: 1%{?dist}
License: PHP and Zend and BSD and MIT and ASL 1.0 and NCSA
Group: Development/Languages
URL: http://www.php.net/

# 源码处理 - 根据版本选择不同来源
%if "%{php_version_short}" == "7.4"
Source0: https://museum.php.net/php7/php-%{version}.tar.xz
%elif "%{php_version_short}" == "8.5" || "%{php_version_short}" == "8.6"
# 开发版本从 GitHub 获取
Source0: https://github.com/php/php-src/archive/PHP-%{version}.tar.gz#/php-%{version}.tar.gz
%else
# 稳定版本从官方站点获取
Source0: https://www.php.net/distributions/php-%{version}.tar.xz
%endif

# 配置文件
Source1: php.ini
Source2: php-fpm.conf
Source3: www.conf
Source4: php-fpm.service
Source5: php-fpm.logrotate
Source6: opcache.ini

# SCL 相关文件
Source10: README
Source11: LICENSE

# 版本特定补丁
%if "%{php_version_short}" == "7.4"
# PHP 7.4 在现代 GCC 上的构建补丁
Patch0: php-7.4-build-on-modern-gcc.patch
# PHP 7.4 OpenSSL 1.1.1 兼容性补丁  
Patch1: php-7.4-openssl-compat.patch
%endif

%if 0%{?php_version_major} == 8 && 0%{?php_version_minor} == 0
# PHP 8.0 JIT 优化补丁
Patch10: php-8.0-jit-optimization.patch
%endif

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

# 构建依赖
BuildRequires: scl-utils-build
BuildRequires: autoconf
BuildRequires: automake
BuildRequires: libtool
BuildRequires: bison
BuildRequires: flex
BuildRequires: gcc
BuildRequires: gcc-c++
BuildRequires: make
BuildRequires: pkgconfig

# PHP 版本特定构建依赖
%php_buildrequires

# 版本特定构建依赖
%if %{need_libzip_compat}
BuildRequires: compat-libzip-devel
%else
BuildRequires: libzip-devel >= 1.7.0
%endif

%if %{need_oniguruma5}
BuildRequires: oniguruma5-devel
%else
BuildRequires: oniguruma-devel >= 6.8.0
%endif

# FPM 相关
BuildRequires: systemd-devel
BuildRequires: systemd-units

# Apache 模块构建依赖
BuildRequires: httpd-devel >= 2.4

# 运行时依赖
Requires: %{name}-common = %{version}-%{release}
Requires: scl-runtime
%php_requires

%description
PHP %{php_version} available as Software Collection.

This package provides the main PHP %{php_version} Software Collection.

%package build
Summary: Package shipping basic build configuration
Requires: scl-utils-build
Requires: %{name} = %{version}-%{release}

%description build
Package shipping essential configuration for building %{scl} Software Collection.

%package runtime
Summary: Package that handles %{scl} Software Collection.
Requires: scl-utils

%description runtime
Package shipping essential scripts to work with %{scl} Software Collection.

%package common
Summary: Common files for PHP
Group: Development/Languages
Requires: %{name}-runtime = %{version}-%{release}

%description common
The %{name}-common package contains files used by both the php
package and the %{name}-cli package.

%package cli
Summary: Command-line interface for PHP
Group: Development/Languages
Requires: %{name}-common = %{version}-%{release}

%description cli
The %{name}-cli package contains the command-line interface 
executing PHP scripts, /opt/%{scl_vendor}/%{scl}/root/usr/bin/php, and the CGI interface.

%package devel
Summary: Files needed for building PHP extensions
Group: Development/Libraries
Requires: %{name}-cli = %{version}-%{release}
Requires: autoconf, automake

%description devel
The %{name}-devel package contains the files needed for building PHP
extensions. If you need to compile your own PHP extensions, you will
need to install this package.

%package fpm
Summary: PHP FastCGI Process Manager
Group: Development/Languages
Requires: %{name}-common = %{version}-%{release}
Requires(pre): /usr/sbin/useradd
Requires(post): systemd
Requires(preun): systemd
Requires(postun): systemd

%description fpm
PHP-FPM (FastCGI Process Manager) is an alternative PHP FastCGI implementation
with some additional features useful for sites of any size, especially
busier sites.

# Apache 模块
%package apache
Summary: PHP module for the Apache HTTP Server
Group: Development/Languages
Requires: %{name}-common = %{version}-%{release}
Requires: httpd >= 2.4

%description apache
The %{name}-apache package contains the module which adds support for
the PHP language to Apache HTTP Server.

# 核心扩展包

%package opcache
Summary: The Zend OPcache
Group: Development/Languages
Requires: %{name}-common = %{version}-%{release}

%description opcache
The Zend OPcache provides faster PHP execution through opcode caching and
optimization. It improves PHP performance by storing precompiled script
bytecode in the shared memory.

%package gd
Summary: A module for PHP applications for using the gd graphics library
Group: Development/Languages
Requires: %{name}-common = %{version}-%{release}

%description gd
The %{name}-gd package contains a dynamic shared object that will add
support for using the gd graphics library to PHP.

%package intl
Summary: Internationalization extension for PHP applications
Group: Development/Languages
Requires: %{name}-common = %{version}-%{release}

%description intl
The %{name}-intl package contains a dynamic shared object that will add
support for using the ICU library to PHP.

%package mbstring
Summary: A module for PHP applications which need multi-byte string handling
Group: Development/Languages
Requires: %{name}-common = %{version}-%{release}

%description mbstring
The %{name}-mbstring package contains a dynamic shared object that will add
support for multi-byte string handling to PHP.

%package mysqlnd
Summary: A module for PHP applications that use MySQL databases
Group: Development/Languages
Requires: %{name}-common = %{version}-%{release}

%description mysqlnd
The %{name}-mysqlnd package contains a dynamic shared object that will add
MySQL database support to PHP. MySQL is an object-relational database
management system. PHP is an HTML-embeddable scripting language. If
you need MySQL support for PHP applications, you will need to install
this package and the php package.

%package pdo
Summary: A database access abstraction module for PHP applications
Group: Development/Languages
Requires: %{name}-common = %{version}-%{release}

%description pdo
The %{name}-pdo package contains a dynamic shared object that will add
a database access abstraction layer to PHP. This module provides
a common interface for accessing MySQL, PostgreSQL or other 
databases.

# JSON 扩展 - 仅对 PHP < 8.0 需要
%if !%{json_builtin}
%package json
Summary: JavaScript Object Notation extension for PHP
Group: Development/Languages
Requires: %{name}-common = %{version}-%{release}

%description json
The %{name}-json package provides an extension that will add
support for JavaScript Object Notation (JSON) to PHP.
%endif

%package xml
Summary: A module for PHP applications which use XML
Group: Development/Languages
Requires: %{name}-common = %{version}-%{release}

%description xml
The %{name}-xml package contains dynamic shared objects which add support
to PHP for manipulating XML documents using the DOM API, the
SAX parser, or the XMLReader/XMLWriter streaming API.

%package zip
Summary: A module for PHP applications that need to handle .zip files
Group: Development/Languages
Requires: %{name}-common = %{version}-%{release}

%description zip
The %{name}-zip package provides an extension that will add
support for creating, reading and manipulating ZIP archives to PHP.

%prep
%setup -q -n php-%{version}

# 应用版本特定补丁
%if "%{php_version_short}" == "7.4"
%patch0 -p1
%patch1 -p1
%endif

%if 0%{?php_version_major} == 8 && 0%{?php_version_minor} == 0
%patch10 -p1
%endif

%build
# 生成配置脚本
%if "%{php_version_short}" == "8.5" || "%{php_version_short}" == "8.6"
# 开发版本需要生成配置脚本
./buildconf --force
%endif

# 设置构建环境变量
export CC=gcc
export CXX=g++

# 版本特定的编译标志
%if %{need_libzip_compat}
export LDFLAGS="-L/usr/lib64/compat-libzip $LDFLAGS"
export CPPFLAGS="-I/usr/include/compat-libzip $CPPFLAGS"
%endif

%if %{need_oniguruma5}
export LDFLAGS="-L/usr/lib64/oniguruma5 $LDFLAGS"
export CPPFLAGS="-I/usr/include/oniguruma5 $CPPFLAGS"
%endif

# 配置选项
./configure \
    --prefix=%{_prefix} \
    --exec-prefix=%{_exec_prefix} \
    --bindir=%{_bindir} \
    --sbindir=%{_sbindir} \
    --sysconfdir=%{_sysconfdir} \
    --datadir=%{_datadir} \
    --includedir=%{_includedir} \
    --libdir=%{_libdir} \
    --libexecdir=%{_libexecdir} \
    --localstatedir=%{_localstatedir} \
    --sharedstatedir=%{_sharedstatedir} \
    --mandir=%{_mandir} \
    --infodir=%{_infodir} \
    --enable-fpm \
    --with-fpm-user=apache \
    --with-fpm-group=apache \
    --with-fpm-systemd \
    --with-config-file-path=%{_sysconfdir} \
    --with-config-file-scan-dir=%{php_inidir} \
    --enable-cli \
    --enable-cgi \
    --with-apxs2=/usr/bin/apxs \
%if !%{json_builtin}
    --enable-json \
%endif
%if %{has_jit}
    --enable-opcache-jit \
%endif
    %{php_configure_options}

# 编译
make %{?_smp_mflags}

%install
rm -rf %{buildroot}

# 安装 PHP
make install INSTALL_ROOT=%{buildroot}

# 创建目录
install -d %{buildroot}%{_sysconfdir}
install -d %{buildroot}%{php_inidir}
install -d %{buildroot}%{php_fpm_dir}
install -d %{buildroot}%{_localstatedir}/log/php-fpm
install -d %{buildroot}%{_rundir}/php-fpm
install -d %{buildroot}%{_localstatedir}/lib/php/session
install -d %{buildroot}%{_localstatedir}/lib/php/wsdlcache
install -d %{buildroot}%{_localstatedir}/lib/php/opcache

# 安装配置文件
install -m 644 %{SOURCE1} %{buildroot}%{_sysconfdir}/php.ini
install -m 644 %{SOURCE2} %{buildroot}%{_sysconfdir}/php-fpm.conf
install -m 644 %{SOURCE3} %{buildroot}%{php_fpm_dir}/www.conf
install -m 644 %{SOURCE6} %{buildroot}%{php_inidir}/10-opcache.ini

# 安装 systemd 服务文件
install -d %{buildroot}%{_unitdir}
install -m 644 %{SOURCE4} %{buildroot}%{_unitdir}/%{php_fpm_service}.service

# logrotate 配置
install -d %{buildroot}%{_sysconfdir}/logrotate.d
install -m 644 %{SOURCE5} %{buildroot}%{_sysconfdir}/logrotate.d/%{php_fpm_service}

# SCL 环境脚本
install -d %{buildroot}%{_scl_scripts}
cat >> %{buildroot}%{_scl_scripts}/enable << EOF
%{scl_enable_content}
EOF

# Apache 模块配置
install -d %{buildroot}%{httpd_modconfdir}
cat > %{buildroot}%{httpd_modconfdir}/10-%{scl}-php.conf << EOF
# Load %{scl} PHP module
LoadModule php_module %{httpd_moddir}/lib%{scl}.so

# Handle PHP files with %{scl}
<FilesMatch "\.php$">
    SetHandler application/x-httpd-php
</FilesMatch>

# Allow php to handle Multiviews
AddType text/html .php

# Add index.php to the list of files that will be served as directory
DirectoryIndex index.php
EOF

# 版本特定的配置调整
%if %{has_jit}
# 添加 JIT 配置
cat >> %{buildroot}%{php_inidir}/10-opcache.ini << EOF

; JIT configuration for PHP 8.0+
opcache.jit_buffer_size=128M
opcache.jit=1255
EOF
%endif

%if %{has_fibers}
# 添加 Fibers 相关配置注释
cat >> %{buildroot}%{_sysconfdir}/php.ini << EOF

; Fiber configuration (PHP 8.1+)
; No additional configuration needed for fibers
EOF
%endif

%clean
rm -rf %{buildroot}

# 安装前脚本
%pre fpm
# 添加 php-fpm 用户
getent group apache >/dev/null || groupadd -r apache
getent passwd apache >/dev/null || \
    useradd -r -g apache -d /var/www -s /sbin/nologin \
    -c "Apache" apache
exit 0

%post fpm
%systemd_post %{php_fpm_service}.service

%preun fpm
%systemd_preun %{php_fpm_service}.service

%postun fpm
%systemd_postun_with_restart %{php_fpm_service}.service

%post apache
# 重启 Apache 以加载新模块
if [ $1 -eq 1 ] ; then
    systemctl try-restart httpd.service >/dev/null 2>&1 || :
fi

%files
%defattr(-,root,root,-)
%{_scl_scripts}

%files runtime
%defattr(-,root,root,-)
%doc README LICENSE
%{_scl_scripts}

%files build
%defattr(-,root,root,-)

%files common
%defattr(-,root,root,-)
%dir %{_sysconfdir}
%dir %{php_inidir}
%config(noreplace) %{_sysconfdir}/php.ini
%dir %{_localstatedir}/lib/php
%dir %{_localstatedir}/lib/php/session
%dir %{_localstatedir}/lib/php/wsdlcache
%{_libdir}/php/modules/*.so
%exclude %{_libdir}/php/modules/opcache.so

%files cli
%defattr(-,root,root,-)
%{_bindir}/php
%{_bindir}/php-cgi
%{_mandir}/man1/php.1*

%files devel
%defattr(-,root,root,-)
%{_bindir}/phpize
%{_bindir}/php-config
%{_includedir}/php
%{_libdir}/php/build

%files fpm
%defattr(-,root,root,-)
%{_sbindir}/php-fpm
%config(noreplace) %{_sysconfdir}/php-fpm.conf
%config(noreplace) %{php_fpm_dir}/www.conf
%{_unitdir}/%{php_fpm_service}.service
%config(noreplace) %{_sysconfdir}/logrotate.d/%{php_fpm_service}
%attr(755,apache,apache) %dir %{_localstatedir}/log/php-fpm
%attr(755,apache,apache) %dir %{_rundir}/php-fpm
%{_mandir}/man8/php-fpm.8*

%files apache
%defattr(-,root,root,-)
%{httpd_moddir}/lib%{scl}.so
%config(noreplace) %{httpd_modconfdir}/10-%{scl}-php.conf

%files opcache
%defattr(-,root,root,-)
%{_libdir}/php/modules/opcache.so
%config(noreplace) %{php_inidir}/10-opcache.ini
%dir %{_localstatedir}/lib/php/opcache

%files gd
%defattr(-,root,root,-)
%{_libdir}/php/modules/gd.so

%files intl
%defattr(-,root,root,-)
%{_libdir}/php/modules/intl.so

%files mbstring
%defattr(-,root,root,-)
%{_libdir}/php/modules/mbstring.so

%files mysqlnd
%defattr(-,root,root,-)
%{_libdir}/php/modules/mysqlnd.so
%{_libdir}/php/modules/mysqli.so

%files pdo
%defattr(-,root,root,-)
%{_libdir}/php/modules/pdo.so
%{_libdir}/php/modules/pdo_mysql.so
%{_libdir}/php/modules/pdo_pgsql.so
%{_libdir}/php/modules/pdo_sqlite.so

# JSON 包仅对 PHP < 8.0
%if !%{json_builtin}
%files json
%defattr(-,root,root,-)
%{_libdir}/php/modules/json.so
%endif

%files xml
%defattr(-,root,root,-)
%{_libdir}/php/modules/xml.so
%{_libdir}/php/modules/xmlreader.so
%{_libdir}/php/modules/xmlwriter.so
%{_libdir}/php/modules/dom.so
%{_libdir}/php/modules/simplexml.so

%files zip
%defattr(-,root,root,-)
%{_libdir}/php/modules/zip.so

%changelog
* %(date "+%a %b %d %Y") Auto Build <build@ii.pe> - %{version}-1
- Initial package for PHP %{version} SCL
- Support for PHP versions 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5
- Conditional compilation based on PHP version
- Comprehensive extension support for modern PHP applications 