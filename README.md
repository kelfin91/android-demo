# Android CI/CD - Jenkins + 腾讯云 CVM 自动化构建部署方案

## 📋 目录

- [架构概览](#架构概览)
- [前置条件](#前置条件)
- [快速开始](#快速开始)
- [详细部署步骤](#详细部署步骤)
- [Jenkins 配置指南](#jenkins-配置指南)
- [签名密钥管理](#签名密钥管理)
- [流水线触发机制](#流水线触发机制)
- [APK 下载验证](#apk-下载验证)
- [常见问题](#常见问题)
- [目录结构](#目录结构)

---

## 架构概览

```
┌──────────┐    git push     ┌──────────────┐    webhook     ┌─────────────────────┐
│  开发者   │ ──────────────→ │ GitHub/GitLab │ ─────────────→ │    腾讯云 CVM        │
└──────────┘                 └──────────────┘                │                     │
                                                             │  ┌───────────────┐  │
                                                             │  │ Docker        │  │
                                                             │  │  ┌─────────┐  │  │
                                                             │  │  │ Jenkins │  │  │
                                                             │  │  │ :8080   │  │  │
                                                             │  │  └────┬────┘  │  │
                                                             │  └───────┼───────┘  │
                                                             │          │ 构建     │
                                                             │          ▼          │
                                                             │  ┌───────────────┐  │
                                                             │  │ Android SDK   │  │
                                                             │  │ + Gradle      │  │
                                                             │  └───────┬───────┘  │
                                                             │          │ APK      │
                                                             │          ▼          │
                                                             │  ┌───────────────┐  │
                                                             │  │ Nginx :80     │  │
                                                             │  │ /apk/app.apk  │  │
                                                             │  └───────────────┘  │
                                                             └─────────────────────┘
```

## 前置条件

| 资源 | 要求 |
|------|------|
| **腾讯云 CVM** | 建议 ≥ 4核8GB，50GB 系统盘 + 100GB 数据盘 |
| **操作系统** | CentOS 7+ / Ubuntu 20.04+ / Debian 10+ |
| **安全组规则** | 开放 22 (SSH)、80 (Nginx)、8080 (Jenkins) 端口 |
| **域名 (可选)** | 如不使用 IP 直接访问 |
| **Git 仓库** | GitHub / GitLab，需配置 SSH Key 或 Access Token |

---

## 快速开始

### 第一步：上传项目到 CVM

```bash
# 将整个项目目录上传到 CVM
scp -r ./ root@<CVM-IP>:/root/android-cicd/

# SSH 登录 CVM
ssh root@<CVM-IP>
```

### 第二步：运行一键部署脚本

```bash
cd /root/android-cicd/cvm-setup

# 给脚本执行权限
chmod +x *.sh

# 一键部署 (需要 root 权限)
sudo ./setup.sh
```

部署过程自动完成：
1. ✅ 系统环境检查
2. ✅ Docker & Docker Compose 安装
3. ✅ Java JDK 17 安装
4. ✅ Android SDK (platform-tools, build-tools, platforms) 安装
5. ✅ Nginx 安装及 APK 下载站点配置
6. ✅ Jenkins 容器启动

### 第三步：初始化 Jenkins

```bash
# 查看 Jenkins 初始密码
docker exec jenkins-android cat /var/jenkins_home/secrets/initialAdminPassword
```

浏览器访问 `http://<CVM-IP>:8080`，输入初始密码完成初始化。

---

## 详细部署步骤

### 1. CVM 环境准备

#### 1.1 创建 CVM 实例

在腾讯云控制台创建 CVM：
- **实例规格**: ≥ 4核8GB (如 S5.MEDIUM4)
- **系统盘**: 50GB 云硬盘
- **数据盘**: 100GB 云硬盘 (挂载到 `/data`)
- **操作系统**: Ubuntu 22.04 LTS
- **安全组**: 开放 22, 80, 8080 端口

#### 1.2 挂载数据盘

```bash
# 查看数据盘
fdisk -l

# 格式化并挂载
mkfs.ext4 /dev/vdb
mkdir -p /data
mount /dev/vdb /data
echo "/dev/vdb /data ext4 defaults 0 0" >> /etc/fstab
```

### 2. Android SDK 安装 (手动)

如果脚本安装失败，可手动安装：

```bash
export ANDROID_SDK_ROOT=/opt/android-sdk
mkdir -p $ANDROID_SDK_ROOT/cmdline-tools
cd /tmp
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-11076708_latest.zip
mv cmdline-tools $ANDROID_SDK_ROOT/cmdline-tools/latest

# 安装组件
export PATH=$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH
yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

### 3. Jenkins 容器管理

```bash
# 启动
cd /root/android-cicd/jenkins
docker-compose up -d

# 查看日志
docker logs -f jenkins-android

# 停止
docker-compose down

# 重启
docker-compose restart
```

### 4. Nginx 配置

配置文件位于 `cvm-setup/nginx-apk.conf`，核心配置：

```nginx
server {
    listen 80;
    server_name _;

    location /apk/ {
        alias /var/www/apk/;
        autoindex on;
        types {
            application/vnd.android.package-archive apk;
        }
    }
}
```

---

## Jenkins 配置指南

### 1. 安装插件

访问 **Manage Jenkins → Plugins → Available plugins**，搜索并安装 `jenkins/plugins.txt` 中的推荐插件。

核心插件：
- `git` / `github` / `gitlab-plugin`
- `workflow-aggregator`
- `credentials-binding`

### 2. 配置凭据 (Credentials)

进入 **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**：

| Credentials ID | 类型 | 说明 |
|----------------|------|------|
| `android-keystore` | Secret file | 上传 `demo.jks` 签名文件 |
| `keystore-password` | Secret text | 密钥库密码 |
| `key-alias` | Secret text | 密钥别名 |
| `key-password` | Secret text | 密钥密码 |
| `git-credentials` | Username with password | Git 仓库访问凭据 |

### 3. 创建 Pipeline Job

1. **新建 Item** → 输入名称 → 选择 **Pipeline**
2. **Pipeline 配置**:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: 你的 Git 仓库地址
   - Credentials: 选择 `git-credentials`
   - Branches to build: `*/main`
   - Script Path: `jenkins/Jenkinsfile`

### 4. 配置 Gradle Wrapper

首次构建前需要将 `gradle-wrapper.jar` 放入项目。在 Android 项目目录中执行：

```bash
# 如果本地已安装 Gradle
gradle wrapper --gradle-version 8.5

# 或者从已有的 Android 项目复制
cp ~/AndroidStudioProjects/YourProject/gradle/wrapper/gradle-wrapper.jar ./android-demo/gradle/wrapper/
```

---

## 签名密钥管理

### 生成签名密钥

```bash
keytool -genkey -v \
  -keystore demo.jks \
  -alias demo \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass your_password \
  -keypass your_password \
  -dname "CN=Your Name, OU=Dev, O=Company, L=City, S=State, C=CN"
```

### 安全注意事项

- ⚠️ **绝对不要将 `.jks` 文件提交到 Git 仓库！**
- ✅ 密钥文件通过 Jenkins Secret file 凭据管理
- ✅ 密码通过 Jenkins Secret text 凭据管理
- ✅ Pipeline 通过 `withCredentials` 在构建时注入
- ✅ `android-demo/.gitignore` 已配置忽略 keystore 文件

---

## 流水线触发机制

### 方式一：手动触发

在 Jenkins Job 页面点击 **Build Now** 或 **Build with Parameters**。

### 方式二：定时构建

在 Jenkins Job 配置中勾选 **Poll SCM**：

```
# 每10分钟检查一次代码变更
H/10 * * * *
```

### 方式三：GitHub/GitLab Webhook (推荐)

#### GitHub Webhook

1. GitHub 仓库 → **Settings → Webhooks → Add webhook**
2. Payload URL: `http://<CVM-IP>:8080/github-webhook/`
3. Content type: `application/json`
4. Events: `Just the push event`

#### GitLab Webhook

1. GitLab 仓库 → **Settings → Webhooks**
2. URL: `http://<CVM-IP>:8080/gitlab-webhook/`
3. Trigger: `Push events`

---

## APK 下载验证

### 查看 APK 目录

```bash
ls -lh /var/www/apk/
```

### 浏览器访问

```
http://<CVM-IP>/apk/
```

### curl 测试

```bash
# 查看目录
curl http://<CVM-IP>/apk/

# 下载 APK
curl -O http://<CVM-IP>/apk/app-release.apk

# 验证 APK 完整性
aapt dump badging app-release.apk
```

---

## 常见问题

### Q: Gradle 构建失败，提示 `gradle-wrapper.jar not found`

```bash
# 在 android-demo 目录执行
gradle wrapper --gradle-version 8.5
```

### Q: Android SDK 找不到

```bash
# 检查环境变量
echo $ANDROID_HOME

# 重新加载环境变量
source /etc/profile.d/android-sdk.sh
```

### Q: Jenkins 无法访问 Docker socket

```bash
# 确保 docker-compose.yml 中挂载了 docker.sock
# 并设置 user: root
docker-compose down && docker-compose up -d
```

### Q: Nginx 端口被占用

```bash
# 检查端口占用
lsof -i :80

# 停止其他 Web 服务
systemctl stop apache2   # or httpd
```

### Q: 安全组未开放端口

在腾讯云控制台 → CVM → 安全组 → 添加规则：
- 端口 80 (HTTP) - 0.0.0.0/0
- 端口 8080 (Jenkins) - 建议限制公司 IP 或 0.0.0.0/0

---

## 目录结构

```
android-cicd/
├── README.md                              # 本文件
├── android-demo/                          # Demo Android 工程
│   ├── app/
│   │   ├── build.gradle.kts               # 模块构建配置 (含签名配置)
│   │   ├── proguard-rules.pro             # 混淆规则
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── java/com/example/demo/
│   │       │   └── MainActivity.kt        # 主 Activity
│   │       └── res/
│   │           ├── layout/activity_main.xml
│   │           ├── values/strings.xml
│   │           ├── values/themes.xml
│   │           └── values/colors.xml
│   ├── build.gradle.kts                   # 根项目配置
│   ├── settings.gradle.kts
│   ├── gradle.properties
│   ├── gradlew                            # Gradle Wrapper
│   ├── gradle/wrapper/
│   │   └── gradle-wrapper.properties
│   ├── keystore/
│   │   └── .gitkeep                       # 签名密钥占位
│   └── .gitignore
├── jenkins/                               # Jenkins 配置
│   ├── Jenkinsfile                        # CI/CD Pipeline 定义
│   ├── docker-compose.yml                 # Docker 容器编排
│   └── plugins.txt                        # 推荐插件列表
└── cvm-setup/                             # CVM 部署脚本
    ├── setup.sh                           # 总入口脚本
    ├── install-docker.sh                  # Docker 安装
    ├── install-android-sdk.sh             # Android SDK 安装
    ├── install-nginx.sh                   # Nginx 安装配置
    └── nginx-apk.conf                     # Nginx 站点配置
```

---

## 许可证

MIT
