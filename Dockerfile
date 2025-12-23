# ==============================================================================
# Redroid Pro Dockerfile
# 使用本地资源构建，无需网络下载
# 注意：Redroid 的 /system 分区是只读的，只能通过 COPY 添加文件
# ==============================================================================

# --- Stage 1: Resource Builder (Ubuntu) ---
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# 安装必要工具
RUN apt-get update && apt-get install -y \
    unzip \
    lzip \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# 复制 OpenGApps 压缩包
COPY opengapps.zip /tmp/opengapps.zip

# 创建输出目录
RUN mkdir -p /output/system/priv-app /output/scripts

# 解压 OpenGApps 并提取 APK
RUN set -ex && \
    # 解压主 ZIP 文件
    unzip -q /tmp/opengapps.zip -d /tmp/gapps && \
    rm /tmp/opengapps.zip && \
    # --- 提取 GmsCore (Google Play Services) ---
    lzip -d /tmp/gapps/Core/gmscore-x86_64.tar.lz && \
    tar -xf /tmp/gapps/Core/gmscore-x86_64.tar -C /tmp/gapps/Core/ && \
    cp -r /tmp/gapps/Core/gmscore-x86_64/nodpi/priv-app/* /output/system/priv-app/ && \
    # --- 提取 GSF (Google Services Framework) ---
    lzip -d /tmp/gapps/Core/gsfcore-all.tar.lz && \
    tar -xf /tmp/gapps/Core/gsfcore-all.tar -C /tmp/gapps/Core/ && \
    cp -r /tmp/gapps/Core/gsfcore-all/nodpi/priv-app/* /output/system/priv-app/ && \
    # --- 提取 Phonesky (Play Store) ---
    lzip -d /tmp/gapps/Core/vending-x86_64.tar.lz && \
    tar -xf /tmp/gapps/Core/vending-x86_64.tar -C /tmp/gapps/Core/ && \
    cp -r /tmp/gapps/Core/vending-x86_64/nodpi/priv-app/* /output/system/priv-app/ && \
    # --- 提取 ConfigUpdater ---
    lzip -d /tmp/gapps/Core/configupdater-all.tar.lz && \
    tar -xf /tmp/gapps/Core/configupdater-all.tar -C /tmp/gapps/Core/ && \
    cp -r /tmp/gapps/Core/configupdater-all/nodpi/priv-app/* /output/system/priv-app/ && \
    # === 设置权限 ===
    chown -R 0:0 /output/system/priv-app/ && \
    find /output/system/priv-app -type d -exec chmod 755 {} \; && \
    find /output/system/priv-app -type f -name "*.apk" -exec chmod 644 {} \; && \
    # 验证结果
    echo "=== 已提取的 APK 文件 ===" && \
    find /output/system/priv-app -name "*.apk" -exec ls -lh {} \; && \
    echo "=========================="

# 复制并修复脚本（CRLF -> LF）
COPY install_gapps.sh /output/scripts/install_gapps.sh
COPY docker-entrypoint.sh /output/scripts/docker-entrypoint.sh
RUN sed -i 's/\r$//' /output/scripts/*.sh && \
    chmod 755 /output/scripts/*.sh && \
    chown 0:0 /output/scripts/*.sh


# --- Stage 2: Final Image (Redroid) ---
# 注意：Redroid 镜像没有 /bin/sh，只能用 COPY 命令添加文件，不能运行脚本
FROM redroid/redroid:11.0.0-latest

# 1. 安装 Libhoudini（从本地仓库复制）
COPY libhoudini/ /

# 2. 安装 GApps（从 builder 复制）
COPY --from=builder /output/system/priv-app /system/priv-app

# 3. 复制配置文件
COPY privapp-permissions-google.xml /system/etc/permissions/privapp-permissions-google.xml

# 注意：Redroid 没有标准 Linux shell (/bin/sh)，使用原生 /init
# 设备指纹通过 docker-compose command 参数传递

