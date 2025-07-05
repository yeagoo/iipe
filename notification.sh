#!/bin/bash

# iipe 通知系统
# 支持邮件、Webhook、Slack、微信等多种通知方式

set -e

# 配置
NOTIFICATION_CONFIG_DIR="notification-configs"
NOTIFICATION_LOG_DIR="logs/notifications"
NOTIFICATION_TEMPLATES_DIR="notification-templates"
NOTIFICATION_REPORTS_DIR="notification-reports"
TEMP_DIR="/tmp/iipe_notifications"

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
    echo "$msg" >> "$NOTIFICATION_LOG_DIR/notification_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_success() {
    local msg="[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$NOTIFICATION_LOG_DIR/notification_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_warning() {
    local msg="[WARNING] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$NOTIFICATION_LOG_DIR/notification_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_error() {
    local msg="[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${RED}${msg}${NC}"
    echo "$msg" >> "$NOTIFICATION_LOG_DIR/notification_$(date '+%Y%m%d').log" 2>/dev/null || true
}

print_notify() {
    local msg="[NOTIFY] $(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "${CYAN}${msg}${NC}"
    echo "$msg" >> "$NOTIFICATION_LOG_DIR/notification_$(date '+%Y%m%d').log" 2>/dev/null || true
}

# 显示用法
show_usage() {
    echo "iipe 通知系统"
    echo ""
    echo "用法: $0 [command] [options]"
    echo ""
    echo "命令:"
    echo "  setup               初始化通知系统"
    echo "  add-provider        添加通知提供商"
    echo "  remove-provider     删除通知提供商"
    echo "  list-providers      列出通知提供商"
    echo "  send                发送通知"
    echo "  test                测试通知配置"
    echo "  create-template     创建通知模板"
    echo "  list-templates      列出通知模板"
    echo "  configure-events    配置事件通知"
    echo "  generate-report     生成通知报告"
    echo "  monitor             启动通知监控"
    echo ""
    echo "选项:"
    echo "  -p, --provider NAME       通知提供商名称"
    echo "  -t, --type TYPE           通知类型 [email|webhook|slack|wechat]"
    echo "  -c, --config FILE         配置文件路径"
    echo "  -m, --message TEXT        通知消息内容"
    echo "  -s, --subject TEXT        通知主题"
    echo "  -e, --event TYPE          事件类型 [build|error|warning|info]"
    echo "  -r, --recipient EMAIL     收件人邮箱"
    echo "  -u, --url URL             Webhook URL"
    echo "  -k, --key TOKEN           API密钥或Token"
    echo "  -f, --format FORMAT       输出格式 [text|html|json|markdown]"
    echo "  -v, --verbose             详细输出"
    echo "  -h, --help                显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 setup                  # 初始化通知系统"
    echo "  $0 add-provider -p email1 -t email -r admin@example.com"
    echo "  $0 send -p slack1 -m \"构建完成\" -e build"
    echo "  $0 test -p webhook1       # 测试Webhook配置"
}

# 初始化通知系统
init_notification_system() {
    mkdir -p "$NOTIFICATION_CONFIG_DIR" "$NOTIFICATION_LOG_DIR" "$NOTIFICATION_TEMPLATES_DIR" "$NOTIFICATION_REPORTS_DIR" "$TEMP_DIR"
    
    # 创建主配置文件
    create_main_config
    
    # 创建通知模板
    create_notification_templates
    
    # 创建事件配置
    create_event_config
    
    print_success "通知系统初始化完成"
}

# 创建主配置文件
create_main_config() {
    local main_config="$NOTIFICATION_CONFIG_DIR/main.conf"
    
    if [ ! -f "$main_config" ]; then
        cat > "$main_config" <<EOF
# iipe 通知系统主配置

# 全局设置
NOTIFICATION_ENABLED=true
DEFAULT_TIMEOUT=30
MAX_RETRY_COUNT=3
RETRY_INTERVAL=10

# 日志设置
LOG_LEVEL=INFO
LOG_RETENTION_DAYS=30

# 通知限制
RATE_LIMIT_ENABLED=true
RATE_LIMIT_WINDOW=300  # 5分钟
RATE_LIMIT_MAX_COUNT=10

# 通知队列
QUEUE_ENABLED=false
QUEUE_MAX_SIZE=1000
QUEUE_BATCH_SIZE=10

# 默认通知模板
DEFAULT_EMAIL_TEMPLATE="email-default"
DEFAULT_SLACK_TEMPLATE="slack-default"
DEFAULT_WEBHOOK_TEMPLATE="webhook-default"
DEFAULT_WECHAT_TEMPLATE="wechat-default"
EOF
        print_success "主配置文件创建完成: $main_config"
    fi
}

# 创建通知模板
create_notification_templates() {
    
    # 邮件模板
    cat > "$NOTIFICATION_TEMPLATES_DIR/email-default.html" <<'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>{{SUBJECT}}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
        .header { background: #f8f9fa; padding: 20px; border-radius: 5px; }
        .content { margin: 20px 0; }
        .footer { color: #666; font-size: 12px; }
        .status-success { color: #28a745; }
        .status-error { color: #dc3545; }
        .status-warning { color: #ffc107; }
        .status-info { color: #17a2b8; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔧 iipe 通知</h1>
        <p>时间: {{TIMESTAMP}}</p>
        <p>事件: <span class="status-{{EVENT_TYPE}}">{{EVENT_TYPE_NAME}}</span></p>
    </div>
    
    <div class="content">
        <h2>{{SUBJECT}}</h2>
        <p>{{MESSAGE}}</p>
        
        {{#if DETAILS}}
        <h3>详细信息:</h3>
        <pre>{{DETAILS}}</pre>
        {{/if}}
    </div>
    
    <div class="footer">
        <p>此邮件由 iipe 自动发送，请勿回复。</p>
        <p>项目地址: {{PROJECT_URL}}</p>
    </div>
</body>
</html>
EOF

    # Slack模板
    cat > "$NOTIFICATION_TEMPLATES_DIR/slack-default.json" <<'EOF'
{
    "text": "{{SUBJECT}}",
    "blocks": [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": "🔧 iipe 通知"
            }
        },
        {
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": "*事件类型:*\n{{EVENT_TYPE_NAME}}"
                },
                {
                    "type": "mrkdwn",
                    "text": "*时间:*\n{{TIMESTAMP}}"
                }
            ]
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*消息:*\n{{MESSAGE}}"
            }
        }
        {{#if DETAILS}}
        ,{
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*详细信息:*\n```{{DETAILS}}```"
            }
        }
        {{/if}}
    ]
}
EOF

    # Webhook模板
    cat > "$NOTIFICATION_TEMPLATES_DIR/webhook-default.json" <<'EOF'
{
    "timestamp": "{{TIMESTAMP}}",
    "event_type": "{{EVENT_TYPE}}",
    "subject": "{{SUBJECT}}",
    "message": "{{MESSAGE}}",
    "details": "{{DETAILS}}",
    "source": "iipe",
    "severity": "{{SEVERITY}}"
}
EOF

    # 微信模板
    cat > "$NOTIFICATION_TEMPLATES_DIR/wechat-default.json" <<'EOF'
{
    "msgtype": "markdown",
    "markdown": {
        "content": "## 🔧 iipe 通知\n\n**事件:** {{EVENT_TYPE_NAME}}\n**时间:** {{TIMESTAMP}}\n**消息:** {{MESSAGE}}\n\n{{#if DETAILS}}**详细信息:**\n```\n{{DETAILS}}\n```{{/if}}"
    }
}
EOF

    print_success "通知模板创建完成"
}

# 创建事件配置
create_event_config() {
    local event_config="$NOTIFICATION_CONFIG_DIR/events.conf"
    
    if [ ! -f "$event_config" ]; then
        cat > "$event_config" <<EOF
# 事件通知配置

# 构建事件
BUILD_SUCCESS_ENABLED=true
BUILD_SUCCESS_PROVIDERS="email,slack"
BUILD_FAILED_ENABLED=true
BUILD_FAILED_PROVIDERS="email,slack,wechat"

# 错误事件
ERROR_CRITICAL_ENABLED=true
ERROR_CRITICAL_PROVIDERS="email,slack,wechat"
ERROR_HIGH_ENABLED=true
ERROR_HIGH_PROVIDERS="email,slack"
ERROR_MEDIUM_ENABLED=false
ERROR_MEDIUM_PROVIDERS="slack"

# 警告事件
WARNING_ENABLED=false
WARNING_PROVIDERS="slack"

# 信息事件
INFO_ENABLED=false
INFO_PROVIDERS="slack"

# 系统事件
SYSTEM_START_ENABLED=true
SYSTEM_START_PROVIDERS="slack"
SYSTEM_STOP_ENABLED=true
SYSTEM_STOP_PROVIDERS="email,slack"

# 监控事件
MONITOR_DISK_FULL_ENABLED=true
MONITOR_DISK_FULL_PROVIDERS="email,slack,wechat"
MONITOR_SERVICE_DOWN_ENABLED=true
MONITOR_SERVICE_DOWN_PROVIDERS="email,slack,wechat"
EOF
        print_success "事件配置文件创建完成: $event_config"
    fi
}

# 添加通知提供商
add_provider() {
    local provider_name="$1"
    local provider_type="$2"
    
    if [ -z "$provider_name" ] || [ -z "$provider_type" ]; then
        print_error "请指定提供商名称和类型"
        return 1
    fi
    
    local config_file="$NOTIFICATION_CONFIG_DIR/${provider_name}.conf"
    
    if [ -f "$config_file" ]; then
        print_error "提供商已存在: $provider_name"
        return 1
    fi
    
    case "$provider_type" in
        "email")
            create_email_provider_config "$config_file" "$provider_name"
            ;;
        "webhook")
            create_webhook_provider_config "$config_file" "$provider_name"
            ;;
        "slack")
            create_slack_provider_config "$config_file" "$provider_name"
            ;;
        "wechat")
            create_wechat_provider_config "$config_file" "$provider_name"
            ;;
        *)
            print_error "不支持的提供商类型: $provider_type"
            return 1
            ;;
    esac
    
    print_success "通知提供商添加完成: $provider_name ($provider_type)"
    print_info "配置文件: $config_file"
    print_info "请编辑配置文件以完成设置"
}

# 创建邮件提供商配置
create_email_provider_config() {
    local config_file="$1"
    local provider_name="$2"
    
    cat > "$config_file" <<EOF
# 邮件通知提供商配置: $provider_name
PROVIDER_NAME="$provider_name"
PROVIDER_TYPE="email"
ENABLED=true

# SMTP配置
SMTP_HOST="smtp.example.com"
SMTP_PORT="587"
SMTP_USER="your-email@example.com"
SMTP_PASSWORD="your-password"
SMTP_TLS=true
SMTP_AUTH=true

# 发件人设置
FROM_EMAIL="iipe-noreply@example.com"
FROM_NAME="iipe 自动通知"

# 收件人设置（逗号分隔多个邮箱）
TO_EMAILS=""
CC_EMAILS=""
BCC_EMAILS=""

# 邮件设置
EMAIL_TEMPLATE="email-default"
EMAIL_FORMAT="html"
SUBJECT_PREFIX="[iipe]"

# 重试设置
RETRY_COUNT=3
RETRY_INTERVAL=10
TIMEOUT=30
EOF
}

# 创建Webhook提供商配置
create_webhook_provider_config() {
    local config_file="$1"
    local provider_name="$2"
    
    cat > "$config_file" <<EOF
# Webhook通知提供商配置: $provider_name
PROVIDER_NAME="$provider_name"
PROVIDER_TYPE="webhook"
ENABLED=true

# Webhook配置
WEBHOOK_URL=""
WEBHOOK_METHOD="POST"
WEBHOOK_HEADERS="Content-Type:application/json"
WEBHOOK_AUTH_TYPE=""  # none, basic, bearer, api_key
WEBHOOK_AUTH_USER=""
WEBHOOK_AUTH_PASSWORD=""
WEBHOOK_AUTH_TOKEN=""
WEBHOOK_API_KEY=""

# 消息设置
WEBHOOK_TEMPLATE="webhook-default"
WEBHOOK_FORMAT="json"

# 重试设置
RETRY_COUNT=3
RETRY_INTERVAL=10
TIMEOUT=30

# SSL设置
SSL_VERIFY=true
EOF
}

# 创建Slack提供商配置
create_slack_provider_config() {
    local config_file="$1"
    local provider_name="$2"
    
    cat > "$config_file" <<EOF
# Slack通知提供商配置: $provider_name
PROVIDER_NAME="$provider_name"
PROVIDER_TYPE="slack"
ENABLED=true

# Slack配置
SLACK_WEBHOOK_URL=""
SLACK_BOT_TOKEN=""
SLACK_CHANNEL=""
SLACK_USERNAME="iipe-bot"
SLACK_ICON_EMOJI=":gear:"

# 消息设置
SLACK_TEMPLATE="slack-default"
SLACK_FORMAT="json"
MENTION_USERS=""  # 需要@的用户，逗号分隔
MENTION_GROUPS=""  # 需要@的用户组，逗号分隔

# 重试设置
RETRY_COUNT=3
RETRY_INTERVAL=10
TIMEOUT=30
EOF
}

# 创建微信提供商配置
create_wechat_provider_config() {
    local config_file="$1"
    local provider_name="$2"
    
    cat > "$config_file" <<EOF
# 微信通知提供商配置: $provider_name
PROVIDER_NAME="$provider_name"
PROVIDER_TYPE="wechat"
ENABLED=true

# 企业微信机器人配置
WECHAT_WEBHOOK_URL=""
WECHAT_BOT_KEY=""

# 微信公众号配置（可选）
WECHAT_APP_ID=""
WECHAT_APP_SECRET=""
WECHAT_TEMPLATE_ID=""

# 消息设置
WECHAT_TEMPLATE="wechat-default"
WECHAT_FORMAT="json"
MENTION_USERS=""  # 需要@的用户，逗号分隔
MENTION_ALL=false

# 重试设置
RETRY_COUNT=3
RETRY_INTERVAL=10
TIMEOUT=30
EOF
}

# 删除通知提供商
remove_provider() {
    local provider_name="$1"
    
    if [ -z "$provider_name" ]; then
        print_error "请指定要删除的提供商名称"
        return 1
    fi
    
    local config_file="$NOTIFICATION_CONFIG_DIR/${provider_name}.conf"
    
    if [ ! -f "$config_file" ]; then
        print_error "提供商不存在: $provider_name"
        return 1
    fi
    
    rm -f "$config_file"
    print_success "通知提供商删除完成: $provider_name"
}

# 列出通知提供商
list_providers() {
    print_info "当前配置的通知提供商:"
    echo ""
    
    if [ ! -d "$NOTIFICATION_CONFIG_DIR" ] || [ "$(find "$NOTIFICATION_CONFIG_DIR" -name "*.conf" ! -name "main.conf" ! -name "events.conf" | wc -l)" -eq 0 ]; then
        print_warning "没有配置任何通知提供商"
        return 0
    fi
    
    printf "%-15s %-10s %-10s %-30s\n" "名称" "类型" "状态" "配置文件"
    printf "%-15s %-10s %-10s %-30s\n" "----" "----" "----" "--------"
    
    for config_file in "$NOTIFICATION_CONFIG_DIR"/*.conf; do
        if [[ "$(basename "$config_file")" =~ ^(main|events)\.conf$ ]]; then
            continue
        fi
        
        if [ -f "$config_file" ]; then
            source "$config_file"
            local status="启用"
            if [ "${ENABLED:-true}" != "true" ]; then
                status="禁用"
            fi
            
            printf "%-15s %-10s %-10s %-30s\n" \
                "${PROVIDER_NAME:-未知}" \
                "${PROVIDER_TYPE:-未知}" \
                "$status" \
                "$(basename "$config_file")"
        fi
    done
}

# 发送通知
send_notification() {
    local provider_name="$1"
    local message="$2"
    local subject="$3"
    local event_type="${4:-info}"
    local details="$5"
    
    if [ -z "$provider_name" ] || [ -z "$message" ]; then
        print_error "请指定提供商名称和消息内容"
        return 1
    fi
    
    local config_file="$NOTIFICATION_CONFIG_DIR/${provider_name}.conf"
    
    if [ ! -f "$config_file" ]; then
        print_error "提供商配置不存在: $provider_name"
        return 1
    fi
    
    # 加载提供商配置
    source "$config_file"
    
    if [ "${ENABLED:-true}" != "true" ]; then
        print_warning "提供商已禁用: $provider_name"
        return 0
    fi
    
    print_notify "发送通知到: $provider_name ($PROVIDER_TYPE)"
    
    case "$PROVIDER_TYPE" in
        "email")
            send_email_notification "$message" "$subject" "$event_type" "$details"
            ;;
        "webhook")
            send_webhook_notification "$message" "$subject" "$event_type" "$details"
            ;;
        "slack")
            send_slack_notification "$message" "$subject" "$event_type" "$details"
            ;;
        "wechat")
            send_wechat_notification "$message" "$subject" "$event_type" "$details"
            ;;
        *)
            print_error "不支持的提供商类型: $PROVIDER_TYPE"
            return 1
            ;;
    esac
}

# 发送邮件通知
send_email_notification() {
    local message="$1"
    local subject="$2"
    local event_type="$3"
    local details="$4"
    
    # 检查依赖
    if ! command -v sendmail >/dev/null 2>&1 && ! command -v mail >/dev/null 2>&1; then
        print_error "邮件发送工具未安装 (sendmail 或 mail)"
        return 1
    fi
    
    # 处理模板变量
    local email_content="$TEMP_DIR/email_$$.html"
    local template_file="$NOTIFICATION_TEMPLATES_DIR/${EMAIL_TEMPLATE:-email-default}.html"
    
    if [ ! -f "$template_file" ]; then
        print_error "邮件模板不存在: $template_file"
        return 1
    fi
    
    # 替换模板变量
    sed -e "s/{{SUBJECT}}/$subject/g" \
        -e "s/{{MESSAGE}}/$message/g" \
        -e "s/{{TIMESTAMP}}/$(date)/g" \
        -e "s/{{EVENT_TYPE}}/$event_type/g" \
        -e "s/{{EVENT_TYPE_NAME}}/$(get_event_type_name "$event_type")/g" \
        -e "s/{{DETAILS}}/$details/g" \
        -e "s|{{PROJECT_URL}}|$(pwd)|g" \
        "$template_file" > "$email_content"
    
    # 发送邮件
    local retry=0
    while [ $retry -lt "${RETRY_COUNT:-3}" ]; do
        if send_email_via_smtp "$email_content" "$subject"; then
            print_success "邮件发送成功"
            rm -f "$email_content"
            return 0
        else
            retry=$((retry + 1))
            print_warning "邮件发送失败，重试 $retry/${RETRY_COUNT:-3}"
            sleep "${RETRY_INTERVAL:-10}"
        fi
    done
    
    rm -f "$email_content"
    return 1
}

# 通过SMTP发送邮件
send_email_via_smtp() {
    local email_file="$1"
    local subject="$2"
    
    # 这里应该实现SMTP发送逻辑
    # 可以使用 msmtp, ssmtp 或其他SMTP客户端
    print_info "模拟发送邮件: $subject 到 ${TO_EMAILS}"
    
    # 模拟发送
    return 0
}

# 发送Webhook通知
send_webhook_notification() {
    local message="$1"
    local subject="$2"
    local event_type="$3"
    local details="$4"
    
    # 检查依赖
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl 未安装"
        return 1
    fi
    
    # 处理模板
    local webhook_data="$TEMP_DIR/webhook_$$.json"
    local template_file="$NOTIFICATION_TEMPLATES_DIR/${WEBHOOK_TEMPLATE:-webhook-default}.json"
    
    if [ ! -f "$template_file" ]; then
        print_error "Webhook模板不存在: $template_file"
        return 1
    fi
    
    # 替换模板变量
    sed -e "s/{{SUBJECT}}/$subject/g" \
        -e "s/{{MESSAGE}}/$message/g" \
        -e "s/{{TIMESTAMP}}/$(date -Iseconds)/g" \
        -e "s/{{EVENT_TYPE}}/$event_type/g" \
        -e "s/{{DETAILS}}/$details/g" \
        -e "s/{{SEVERITY}}/$(get_event_severity "$event_type")/g" \
        "$template_file" > "$webhook_data"
    
    # 构建curl命令
    local curl_cmd="curl -X ${WEBHOOK_METHOD:-POST}"
    curl_cmd="$curl_cmd --data @$webhook_data"
    curl_cmd="$curl_cmd --max-time ${TIMEOUT:-30}"
    
    # 添加请求头
    if [ -n "$WEBHOOK_HEADERS" ]; then
        IFS=',' read -ra headers <<< "$WEBHOOK_HEADERS"
        for header in "${headers[@]}"; do
            curl_cmd="$curl_cmd -H \"$header\""
        done
    fi
    
    # 添加认证
    case "${WEBHOOK_AUTH_TYPE:-none}" in
        "basic")
            curl_cmd="$curl_cmd -u \"$WEBHOOK_AUTH_USER:$WEBHOOK_AUTH_PASSWORD\""
            ;;
        "bearer")
            curl_cmd="$curl_cmd -H \"Authorization: Bearer $WEBHOOK_AUTH_TOKEN\""
            ;;
        "api_key")
            curl_cmd="$curl_cmd -H \"X-API-Key: $WEBHOOK_API_KEY\""
            ;;
    esac
    
    curl_cmd="$curl_cmd \"$WEBHOOK_URL\""
    
    # 发送请求
    local retry=0
    while [ $retry -lt "${RETRY_COUNT:-3}" ]; do
        if eval "$curl_cmd" >/dev/null 2>&1; then
            print_success "Webhook发送成功"
            rm -f "$webhook_data"
            return 0
        else
            retry=$((retry + 1))
            print_warning "Webhook发送失败，重试 $retry/${RETRY_COUNT:-3}"
            sleep "${RETRY_INTERVAL:-10}"
        fi
    done
    
    rm -f "$webhook_data"
    return 1
}

# 发送Slack通知
send_slack_notification() {
    local message="$1"
    local subject="$2"
    local event_type="$3"
    local details="$4"
    
    # 检查依赖
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl 未安装"
        return 1
    fi
    
    # 处理模板
    local slack_data="$TEMP_DIR/slack_$$.json"
    local template_file="$NOTIFICATION_TEMPLATES_DIR/${SLACK_TEMPLATE:-slack-default}.json"
    
    if [ ! -f "$template_file" ]; then
        print_error "Slack模板不存在: $template_file"
        return 1
    fi
    
    # 替换模板变量
    sed -e "s/{{SUBJECT}}/$subject/g" \
        -e "s/{{MESSAGE}}/$message/g" \
        -e "s/{{TIMESTAMP}}/$(date)/g" \
        -e "s/{{EVENT_TYPE}}/$event_type/g" \
        -e "s/{{EVENT_TYPE_NAME}}/$(get_event_type_name "$event_type")/g" \
        -e "s/{{DETAILS}}/$details/g" \
        "$template_file" > "$slack_data"
    
    # 发送到Slack
    local retry=0
    while [ $retry -lt "${RETRY_COUNT:-3}" ]; do
        if curl -X POST \
            -H "Content-Type: application/json" \
            --data @"$slack_data" \
            --max-time "${TIMEOUT:-30}" \
            "$SLACK_WEBHOOK_URL" >/dev/null 2>&1; then
            print_success "Slack消息发送成功"
            rm -f "$slack_data"
            return 0
        else
            retry=$((retry + 1))
            print_warning "Slack消息发送失败，重试 $retry/${RETRY_COUNT:-3}"
            sleep "${RETRY_INTERVAL:-10}"
        fi
    done
    
    rm -f "$slack_data"
    return 1
}

# 发送微信通知
send_wechat_notification() {
    local message="$1"
    local subject="$2"
    local event_type="$3"
    local details="$4"
    
    # 检查依赖
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl 未安装"
        return 1
    fi
    
    # 处理模板
    local wechat_data="$TEMP_DIR/wechat_$$.json"
    local template_file="$NOTIFICATION_TEMPLATES_DIR/${WECHAT_TEMPLATE:-wechat-default}.json"
    
    if [ ! -f "$template_file" ]; then
        print_error "微信模板不存在: $template_file"
        return 1
    fi
    
    # 替换模板变量
    sed -e "s/{{SUBJECT}}/$subject/g" \
        -e "s/{{MESSAGE}}/$message/g" \
        -e "s/{{TIMESTAMP}}/$(date)/g" \
        -e "s/{{EVENT_TYPE}}/$event_type/g" \
        -e "s/{{EVENT_TYPE_NAME}}/$(get_event_type_name "$event_type")/g" \
        -e "s/{{DETAILS}}/$details/g" \
        "$template_file" > "$wechat_data"
    
    # 发送到企业微信
    local retry=0
    while [ $retry -lt "${RETRY_COUNT:-3}" ]; do
        if curl -X POST \
            -H "Content-Type: application/json" \
            --data @"$wechat_data" \
            --max-time "${TIMEOUT:-30}" \
            "$WECHAT_WEBHOOK_URL" >/dev/null 2>&1; then
            print_success "微信消息发送成功"
            rm -f "$wechat_data"
            return 0
        else
            retry=$((retry + 1))
            print_warning "微信消息发送失败，重试 $retry/${RETRY_COUNT:-3}"
            sleep "${RETRY_INTERVAL:-10}"
        fi
    done
    
    rm -f "$wechat_data"
    return 1
}

# 获取事件类型名称
get_event_type_name() {
    case "$1" in
        "build") echo "构建事件" ;;
        "error") echo "错误事件" ;;
        "warning") echo "警告事件" ;;
        "info") echo "信息事件" ;;
        "system") echo "系统事件" ;;
        "monitor") echo "监控事件" ;;
        *) echo "未知事件" ;;
    esac
}

# 获取事件严重级别
get_event_severity() {
    case "$1" in
        "error") echo "high" ;;
        "warning") echo "medium" ;;
        "build") echo "low" ;;
        "info") echo "low" ;;
        *) echo "medium" ;;
    esac
}

# 测试通知配置
test_notification() {
    local provider_name="$1"
    
    if [ -z "$provider_name" ]; then
        print_error "请指定要测试的提供商名称"
        return 1
    fi
    
    print_info "测试通知配置: $provider_name"
    
    local test_message="这是一条测试消息，用于验证通知配置是否正常工作。"
    local test_subject="iipe 通知测试"
    
    if send_notification "$provider_name" "$test_message" "$test_subject" "info" "测试详细信息"; then
        print_success "通知测试成功: $provider_name"
    else
        print_error "通知测试失败: $provider_name"
        return 1
    fi
}

# 主函数
main() {
    local command=""
    local provider_name=""
    local provider_type=""
    local message=""
    local subject=""
    local event_type="info"
    local recipient=""
    local webhook_url=""
    local api_key=""
    local verbose=false
    local output_format="text"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            setup|add-provider|remove-provider|list-providers|send|test|create-template|list-templates|configure-events|generate-report|monitor)
                command="$1"
                shift
                ;;
            -p|--provider)
                provider_name="$2"
                shift 2
                ;;
            -t|--type)
                provider_type="$2"
                shift 2
                ;;
            -m|--message)
                message="$2"
                shift 2
                ;;
            -s|--subject)
                subject="$2"
                shift 2
                ;;
            -e|--event)
                event_type="$2"
                shift 2
                ;;
            -r|--recipient)
                recipient="$2"
                shift 2
                ;;
            -u|--url)
                webhook_url="$2"
                shift 2
                ;;
            -k|--key)
                api_key="$2"
                shift 2
                ;;
            -f|--format)
                output_format="$2"
                shift 2
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
                print_error "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # 执行命令
    case "$command" in
        "setup")
            init_notification_system
            ;;
        "add-provider")
            add_provider "$provider_name" "$provider_type"
            ;;
        "remove-provider")
            remove_provider "$provider_name"
            ;;
        "list-providers")
            list_providers
            ;;
        "send")
            send_notification "$provider_name" "$message" "$subject" "$event_type"
            ;;
        "test")
            test_notification "$provider_name"
            ;;
        "")
            # 默认列出提供商
            list_providers
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