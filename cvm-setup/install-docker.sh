#!/bin/bash
###############################################################################
# Docker & Docker Compose 安装脚本
# 支持: CentOS 7+, Ubuntu 20.04+, Debian 10+
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup.sh" 2>/dev/null || true

GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $(date '+%H:%M:%S') $*"; }

install_docker() {
    log_info "========== 安装 Docker Engine =========="

    if command -v docker &> /dev/null; then
        log_info "Docker 已安装: $(docker --version)"
        return 0
    fi

    if [ -f /etc/redhat-release ]; then
        # CentOS / RHEL
        log_info "检测到 CentOS/RHEL 系统"
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io
    elif [ -f /etc/debian_version ]; then
        # Debian / Ubuntu
        log_info "检测到 Debian/Ubuntu 系统"
        apt-get update
        apt-get install -y ca-certificates curl gnupg lsb-release
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    else
        log_info "无法识别系统，请手动安装 Docker"
        echo "参考: https://docs.docker.com/engine/install/"
        exit 1
    fi

    # 启动 Docker
    systemctl enable docker
    systemctl start docker
    log_info "Docker 安装完成: $(docker --version)"
}

install_docker_compose() {
    log_info "========== 安装 Docker Compose =========="

    if command -v docker-compose &> /dev/null; then
        log_info "docker-compose 已安装: $(docker-compose --version)"
    else
        log_info "安装 docker-compose (standalone)..."
        COMPOSE_VERSION="v2.24.0"
        curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        log_info "docker-compose 安装完成"
    fi
}

install_docker
install_docker_compose

log_info "✅ Docker 环境安装完成"
