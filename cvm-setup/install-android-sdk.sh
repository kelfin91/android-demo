#!/bin/bash
###############################################################################
# Android SDK 命令行工具安装脚本
# 安装到 /opt/android-sdk，供 Jenkins 容器使用
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $(date '+%H:%M:%S') $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') $*"; }

ANDROID_SDK_ROOT="/opt/android-sdk"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

install_java() {
    log_info "========== 安装 Java JDK 17 =========="

    if command -v java &> /dev/null; then
        JAVA_VER=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | cut -d'.' -f1)
        if [ "$JAVA_VER" -ge 17 ]; then
            log_info "Java 已安装: $(java -version 2>&1 | head -1)"
            return 0
        fi
    fi

    if [ -f /etc/redhat-release ]; then
        # CentOS/RHEL - 使用 Amazon Corretto
        rpm --import https://yum.corretto.aws/corretto.key
        curl -L -o /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo
        yum install -y java-17-amazon-corretto-devel
    elif [ -f /etc/debian_version ]; then
        # Ubuntu/Debian
        apt-get update
        apt-get install -y openjdk-17-jdk-headless
    else
        log_warn "无法自动安装 Java，请手动安装 JDK 17+"
        exit 1
    fi

    log_info "Java 安装完成: $(java -version 2>&1 | head -1)"
}

install_android_sdk() {
    log_info "========== 安装 Android SDK =========="

    if [ -f "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
        log_info "Android SDK 已安装在 $ANDROID_SDK_ROOT"
    else
        log_info "下载 Android 命令行工具..."
        mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
        cd /tmp
        curl -o cmdline-tools.zip "$CMDLINE_TOOLS_URL"
        unzip -qo cmdline-tools.zip
        mv cmdline-tools "$ANDROID_SDK_ROOT/cmdline-tools/latest"
        rm -f cmdline-tools.zip
        log_info "Android 命令行工具下载完成"
    fi

    # 设置环境变量
    export ANDROID_HOME="$ANDROID_SDK_ROOT"
    export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
    export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

    # 接受许可协议
    log_info "接受 Android SDK 许可协议..."
    yes | sdkmanager --licenses > /dev/null 2>&1 || true

    # 安装必要的 SDK 组件
    log_info "安装 Android SDK 组件（可能需要几分钟）..."
    sdkmanager --install \
        "platform-tools" \
        "platforms;android-34" \
        "build-tools;34.0.0" \
        "ndk;25.2.9519653" \
        "cmake;3.22.1"

    log_info "Android SDK 安装完成"
}

# 配置环境变量（全局）
setup_env() {
    log_info "========== 配置环境变量 =========="
    cat > /etc/profile.d/android-sdk.sh << 'EOF'
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export PATH=$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH
EOF
    chmod +x /etc/profile.d/android-sdk.sh
    source /etc/profile.d/android-sdk.sh
    log_info "环境变量已配置"
}

install_java
install_android_sdk
setup_env

log_info "✅ Android SDK 环境安装完成"
log_info "   ANDROID_HOME: $ANDROID_SDK_ROOT"
