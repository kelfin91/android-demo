#!/bin/bash
###############################################################################
# CVM 一键部署总入口脚本
# 用法: chmod +x setup.sh && sudo ./setup.sh
# 适用: CentOS 7+ / Ubuntu 20.04+ / Debian 10+
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/cvm-setup-$(date +%Y%m%d-%H%M%S).log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC}  $(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $*" | tee -a "$LOG_FILE"; }

###############################################################################
# 0. 环境检查
###############################################################################
preflight_check() {
    log_info "========== 环境检查 =========="

    # 检查是否为 root
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 权限运行: sudo ./setup.sh"
        exit 1
    fi

    # 检查系统架构
    ARCH=$(uname -m)
    log_info "系统架构: $ARCH"

    # 检查系统版本
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "操作系统: $NAME $VERSION"
    fi
}

###############################################################################
# 主流程
###############################################################################
main() {
    echo ""
    echo "=============================================="
    echo "   腾讯云 CVM - Android CI/CD 环境部署"
    echo "=============================================="
    echo ""
    log_info "部署日志: $LOG_FILE"
    echo ""

    preflight_check

    log_info "开始安装 Docker 环境..."
    bash "$SCRIPT_DIR/install-docker.sh"

    log_info "开始安装 Android SDK..."
    bash "$SCRIPT_DIR/install-android-sdk.sh"

    log_info "开始安装 Nginx..."
    bash "$SCRIPT_DIR/install-nginx.sh"

    log_info "========== 启动 Jenkins 容器 =========="
    cd "$SCRIPT_DIR/../jenkins"
    docker-compose up -d
    log_info "Jenkins 容器已启动"

    # 获取 Jenkins 初始密码
    sleep 5
    JENKINS_PASSWORD=$(docker exec jenkins-android cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "请手动查看")
    log_info "Jenkins 初始密码: $JENKINS_PASSWORD"

    echo ""
    echo "=============================================="
    log_info "✅ 部署完成！"
    echo "=============================================="
    echo ""
    echo "  访问地址:"
    echo "    Jenkins:  http://$(curl -s ifconfig.me 2>/dev/null || echo '<CVM-IP>'):8080"
    echo "    APK 下载: http://$(curl -s ifconfig.me 2>/dev/null || echo '<CVM-IP>')/apk/"
    echo ""
    echo "  后续步骤:"
    echo "    1. 访问 Jenkins，输入初始密码完成初始化"
    echo "    2. 安装推荐插件（参考 jenkins/plugins.txt）"
    echo "    3. 配置凭据: android-keystore, keystore-password, key-alias, key-password"
    echo "    4. 创建 Pipeline Job，指向 Jenkinsfile"
    echo "    5. 配置 Git 仓库地址和 Webhook"
    echo "    6. 详见 README.md"
    echo ""
    log_info "完整日志: $LOG_FILE"
}

main "$@"
