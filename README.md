# 🌌 Project CloudVerse (云端平行宇宙)

> **"把梦变真，穷人也能用的云端数字孪生。"**

[![Build Redroid Pro](https://github.com/yourname/redroid-pro/actions/workflows/build.yml/badge.svg)](https://github.com/yourname/redroid-pro/actions/workflows/build.yml)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

**Project CloudVerse** 是一个终极的云手机解决方案，旨在为您提供与物理手机“一模一样”的体验。

## ✨ 核心特性

| 模块 | 功能描述 |
| :--- | :--- |
| **📱 Redroid-Pro** | **原生体验**: 基于 Android 11, 集成 **GApps** (谷歌服务), **Libhoudini** (ARM 兼容), **Magisk** (可选).<br>**Project Victory**: 通过 10 项严苛测试，保证 Youtube/TikTok 完美运行。 |
| **👯 Project Twin** | **数字孪生**: 集成 **Syncthing**。<br>手机拍照 -> 云端秒同步；云端下载 -> 手机秒安装。 |
| **🕸️ Project Portal** | **任意门**: 集成 **Scrcpy-Web** (PWA).<br>无需 App，浏览器访问即玩，支持**原生多点触控**。 |
| **🌠 Project Dream** | **终极普惠**: **Android Go** 模式 (2G内存流畅运行) + **Smart-Net** (零配置自动联网)。 |

---

## 🚀 快速开始 (小白教程)

### 1. ☁️ 云端构建 (使用 GitHub Desktop)

既然你通过 GitHub Desktop 打开了这个项目：

1.  **Publish Repository**: 点击界面右上角的 `Publish repository` 按钮。
    *   *Name*: `redroid-pro`
    *   *Keep this code private*: ✅ (推荐勾选)
    *   点击 `Publish Repository`.
2.  **Trigger Build**:
    *   打开 GitHub 网页版 (点击 `Repository` -> `View on GitHub`).
    *   进入 `Actions` 标签页。
    *   点击左侧的 `Build Redroid Pro`.
    *   点击右侧的 `Run workflow` -> `Run workflow` (绿色按钮).
3.  **Get Image**:
    *   等待构建完成（约 15 分钟）。
    *   你的镜像地址将是: `ghcr.io/你的用户名/redroid-pro:latest`

### 2. 🏠 部署 (NAS 或 本地 PC)

#### 方法 A: 一键部署 (推荐)
只需修改 `docker-compose.yml` 中的镜像地址，然后运行：

```bash
docker-compose up -d
```

#### 方法 B: Windows 本地体验 (Docker Desktop)
双击运行目录下的 `Run-Local-Test.bat`。

---

## 🎮 如何使用

### 1. 浏览器控制 (推荐)
*   **地址**: `http://IP地址:8000`
*   **手机端**: 使用 Chrome/Safari 打开 -> 菜单 -> **添加到主屏幕** (获得全屏 App 体验).

### 2. 文件同步
*   **地址**: `http://IP地址:8384`
*   **配对**: 在你的实体手机上安装 [Syncthing](https://syncthing.net/)，扫描网页上的二维码。

### 3. 连接 ADB
```bash
adb connect IP地址:5555
```

---

## 🔧 技术细节

*   **Smart-Net**: 容器启动时会自动探测 `20171` 端口，自动配置全局代理。
*   **Low-RAM Mode**: 默认开启。如需关闭，在 `docker-compose.yml` 中设置 `ENABLE_LOW_RAM=false`.

---

**Made with ❤️ for the Dreamers.**
