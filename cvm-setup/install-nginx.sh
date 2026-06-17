#!/bin/bash
###############################################################################
# Nginx 安装及 APK 下载站点配置脚本
###############################################################################

set -e

GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $(date '+%H:%M:%S') $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK_WEB_ROOT="/var/www/apk"
NGINX_CONF_DIR="/etc/nginx"

install_nginx() {
    log_info "========== 安装 Nginx =========="

    if command -v nginx &> /dev/null; then
        log_info "Nginx 已安装: $(nginx -v 2>&1)"
    else
        if [ -f /etc/redhat-release ]; then
            yum install -y epel-release
            yum install -y nginx
        elif [ -f /etc/debian_version ]; then
            apt-get update
            apt-get install -y nginx
        else
            log_info "请手动安装 Nginx"
            exit 1
        fi
        log_info "Nginx 安装完成"
    fi
}

configure_nginx() {
    log_info "========== 配置 Nginx APK 下载站点 =========="

    # 创建 APK 发布目录
    mkdir -p "$APK_WEB_ROOT"
    chmod 755 "$APK_WEB_ROOT"

    # 复制 Nginx 配置文件
    if [ -d "$NGINX_CONF_DIR/conf.d" ]; then
        cp "$SCRIPT_DIR/nginx-apk.conf" "$NGINX_CONF_DIR/conf.d/apk.conf"
    elif [ -d "$NGINX_CONF_DIR/sites-available" ]; then
        cp "$SCRIPT_DIR/nginx-apk.conf" "$NGINX_CONF_DIR/sites-available/apk"
        ln -sf "$NGINX_CONF_DIR/sites-available/apk" "$NGINX_CONF_DIR/sites-enabled/apk" 2>/dev/null || true
    fi

    log_info "Nginx 配置已复制"
}

start_nginx() {
    log_info "========== 启动 Nginx =========="

    # 测试配置
    nginx -t

    # 启动服务
    systemctl enable nginx
    systemctl restart nginx
    log_info "Nginx 已启动"
}

verify() {
    log_info "========== 验证部署 =========="

    # 创建测试页面
    cat > "$APK_WEB_ROOT/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>APK 下载服务</title>
    <style>
        body { font-family: -apple-system, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }
        .card { background: #fff; border-radius: 12px; padding: 30px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        h1 { color: #1976D2; }
        p { color: #666; }
        code { background: #f0f0f0; padding: 2px 6px; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="card">
        <h1>APK 下载服务已就绪</h1>
        <p>构建完成后，APK 文件将自动发布到此目录。</p>
        <p>访问 <code>http://&lt;CVM-IP&gt;/apk/</code> 即可下载最新版本。</p>
    </div>
</body>
</html>
EOF

    # 验证 HTTP 访问
    if curl -s -o /dev/null -w "%{http_code}" http://localhost/apk/ | grep -q 200; then
        log_info "✅ Nginx APK 站点验证通过"
    else
        log_info "⚠️  Nginx 响应异常，请检查防火墙/安全组是否开放 80 端口"
    fi
}

install_nginx
configure_nginx
start_nginx
verify

log_info "✅ Nginx 安装配置完成"
log_info "   APK 下载地址: http://$(curl -s ifconfig.me 2>/dev/null || echo '<CVM-IP>')/apk/"
