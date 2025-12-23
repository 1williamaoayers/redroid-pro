# 🌌 Redroid Pro 完整部署教程（小白版）

> **一份从零开始的云手机部署指南，让你在 NAS 上运行完整的 Android 11 系统**

---

## 📋 目录

1. [准备工作](#1-准备工作)
2. [在 NAS 上部署 Redroid](#2-在-nas-上部署-redroid)
3. [部署 Scrcpy-Web（浏览器控制）](#3-部署-scrcpy-web浏览器控制)
4. [电脑端连接云手机](#4-电脑端连接云手机)
5. [注册 Google Play（解决认证问题）](#5-注册-google-play解决认证问题)
6. [常见问题](#6-常见问题)

---

## 1. 准备工作

### 硬件要求

| 项目 | 要求 |
|------|------|
| NAS/服务器 | x86_64 架构（Intel/AMD），支持 KVM 虚拟化 |
| 内存 | 至少 4GB |
| 存储 | 至少 10GB 可用空间 |

### 软件要求

- Docker 已安装
- Docker Compose 已安装
- SSH 客户端（用于连接 NAS）

### 检查 KVM 支持

SSH 连接到你的 NAS，执行：
```bash
ls -la /dev/kvm
```
如果显示 `/dev/kvm` 文件存在，说明支持 KVM ✅

---

## 2. 在 NAS 上部署 Redroid

### 步骤 2.1：创建工作目录

```bash
mkdir -p /opt/redroid-pro
cd /opt/redroid-pro
```

### 步骤 2.2：拉取镜像

**如果可以直接访问 GitHub：**
```bash
docker pull ghcr.io/1williamaoayers/redroid-pro:latest
```

**如果在中国大陆，使用南大镜像加速：**
```bash
docker pull ghcr.nju.edu.cn/1williamaoayers/redroid-pro:latest
# 拉取后重新打标签
docker tag ghcr.nju.edu.cn/1williamaoayers/redroid-pro:latest ghcr.io/1williamaoayers/redroid-pro:latest
```

**如果需要代理：**
```bash
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
docker pull ghcr.io/1williamaoayers/redroid-pro:latest
```

### 步骤 2.3：创建 docker-compose.yml

```bash
cat > docker-compose.yml << 'EOF'
services:
  redroid:
    container_name: redroid-pro
    image: ghcr.io/1williamaoayers/redroid-pro:latest
    stdin_open: true
    tty: true
    privileged: true
    ports:
      - "5555:5555"
    volumes:
      - redroid-data:/data
    environment:
      - ENABLE_LOW_RAM=true
    command:
      - androidboot.redroid_width=720
      - androidboot.redroid_height=1280
      - androidboot.redroid_dpi=320
      - androidboot.redroid_fps=30
    restart: unless-stopped

volumes:
  redroid-data:
EOF
```

### 步骤 2.4：启动容器

```bash
docker compose up -d
```

### 步骤 2.5：验证启动成功

```bash
# 查看容器状态
docker ps | grep redroid

# 查看日志（应该看到 /system/bin/sh 提示）
docker logs redroid-pro
```

### 步骤 2.6：测试 ADB 连接

```bash
adb connect 127.0.0.1:5555
adb devices
adb shell getprop ro.build.version.release
# 应该显示 "11"
```

---

## 3. 部署 Scrcpy-Web（浏览器控制）

Scrcpy-Web 让你用浏览器控制云手机，无需安装任何软件。

### 步骤 3.1：部署 Scrcpy-Web 容器

```bash
docker run -d \
  --name scrcpy-web \
  --network redroid-pro_default \
  --restart unless-stopped \
  -p 5800:8000 \
  -e ANDROID_IP=redroid-pro \
  -e ANDROID_PORT=5555 \
  emptysuns/scrcpy-web:v0.1
```

### 步骤 3.2：连接 ADB

```bash
docker exec scrcpy-web adb connect redroid-pro:5555
```

### 步骤 3.3：访问网页

打开浏览器访问：**http://你的NAS_IP:5800**

例如：`http://192.168.3.134:5800`

点击设备列表中的 **H264 Converter** 就能看到并控制云手机！

---

## 4. 电脑端连接云手机

### 方法 A：浏览器（最简单）

直接访问 `http://你的NAS_IP:5800`

### 方法 B：scrcpy 软件（更流畅）

1. **下载 scrcpy**：https://github.com/Genymobile/scrcpy/releases
   - 下载 `scrcpy-win64-v*.zip` 并解压

2. **连接并投屏**：
```bash
adb connect 你的NAS_IP:5555
scrcpy --no-audio
```

### 操作说明

| 操作 | 方法 |
|------|------|
| 点击 | 鼠标左键 |
| 滑动 | 按住左键拖动 |
| 返回 | 底部 ◀ 按钮 或 ESC 键 |
| 主页 | 底部 ● 按钮 |
| 最近应用 | 底部 ■ 按钮 |
| 打字 | 直接键盘输入 |

---

## 5. 注册 Google Play（解决认证问题）

首次打开 Google Play 会提示 "设备未通过 Play Protect 认证"，需要手动注册。

### 步骤 5.1：获取 GSF ID

```bash
adb root
adb shell "sqlite3 /data/data/com.google.android.gsf/databases/gservices.db 'select * from main where name=\"android_id\";'"
```

输出类似：`android_id|4348501509765417325`

记下 `|` 后面的数字（如 `4348501509765417325`）

### 步骤 5.2：注册设备

1. 打开：https://www.google.com/android/uncertified/
2. 登录 Google 账号
3. 输入上一步获取的数字（19位）
4. 点击 **Register**

### 步骤 5.3：等待并重启

等待 10-30 分钟后，重启容器：
```bash
docker restart redroid-pro
```

之后 Google Play 就能正常使用了！

---

## 6. 常见问题

### Q1：容器启动失败，提示 "no such file or directory"
**原因**：自定义脚本不兼容
**解决**：使用最新版本的镜像，已修复此问题

### Q2：拉取镜像超时
**解决**：使用代理或镜像加速
```bash
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
docker pull ghcr.io/1williamaoayers/redroid-pro:latest
```

### Q3：scrcpy 报错 "audio encoder" 相关
**解决**：禁用音频
```bash
scrcpy --no-audio
```

### Q4：Scrcpy-Web 无法显示设备
**解决**：手动连接 ADB
```bash
docker exec scrcpy-web adb connect redroid-pro:5555
```
然后刷新浏览器页面

### Q5：时区不正确
1. 打开 Settings → System → Date & Time
2. 关闭自动时区
3. 手动选择时区
4. 重启容器：`docker restart redroid-pro`

---

## 🎉 完成！

现在你拥有了：
- ✅ 运行在 NAS 上的 Android 11 云手机
- ✅ 完整的 Google Play 服务
- ✅ ARM 应用兼容（通过 Libhoudini）
- ✅ 浏览器远程控制
- ✅ 数据持久化存储

**享受你的云手机吧！** 🚀
