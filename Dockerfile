# ==============================================================================
# Redroid Pro Dockerfile
# 使用本地资源构建，无需网络下载
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
RUN mkdir -p /output/system/priv-app

# 解压 OpenGApps 并提取 APK
RUN set -ex && \
    # 解压主 ZIP 文件
    unzip -q /tmp/opengapps.zip -d /tmp/gapps && \
    rm /tmp/opengapps.zip && \
    # 调试：列出可用的 tar.lz 文件
    echo "=== 可用的 tar.lz 文件 ===" && \
    ls -la /tmp/gapps/Core/*.tar.lz && \
    echo "==========================" && \
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
    # 验证结果
    echo "=== 已提取的 APK 文件 ===" && \
    find /output/system/priv-app -name "*.apk" -exec ls -lh {} \; && \
    echo "=========================="

# 复制并修复脚本（CRLF -> LF）
COPY install_gapps.sh /scripts/install_gapps.sh
COPY docker-entrypoint.sh /scripts/docker-entrypoint.sh
RUN sed -i 's/\r$//' /scripts/*.sh && chmod +x /scripts/*.sh


# --- Stage 2: Final Image (Redroid) ---
FROM redroid/redroid:11.0.0-latest

# 1. 安装 Libhoudini（从本地仓库复制）
COPY libhoudini/ /

# 2. 安装 GApps（从 builder 复制）
COPY --from=builder /output/system/priv-app /system/priv-app

# 3. 复制配置和脚本
COPY privapp-permissions-google.xml /system/etc/permissions/privapp-permissions-google.xml
COPY --from=builder /scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY --from=builder /scripts/install_gapps.sh /usr/local/bin/install_gapps.sh

# 4. 设置权限和设备指纹
RUN set -ex && \
    # 验证 priv-app 内容
    echo "=== /system/priv-app 内容 ===" && \
    ls -laR /system/priv-app/ && \
    echo "=============================" && \
    # 设置正确的所有权和权限
    chown -R root:root /system/priv-app/ && \
    find /system/priv-app -type d -exec chmod 755 {} \; && \
    find /system/priv-app -type f -name "*.apk" -exec chmod 644 {} \; && \
    # 脚本权限
    chmod +x /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/install_gapps.sh && \
    # 设置设备指纹（伪装为 Pixel 3 XL）
    echo "ro.product.model=Pixel 3 XL" >> /system/build.prop && \
    echo "ro.product.brand=google" >> /system/build.prop && \
    echo "ro.product.name=crosshatch" >> /system/build.prop && \
    echo "ro.product.device=crosshatch" >> /system/build.prop && \
    echo "ro.product.manufacturer=Google" >> /system/build.prop && \
    echo "ro.build.fingerprint=google/crosshatch/crosshatch:11/RQ3A.211001.001/7641976:user/release-keys" >> /system/build.prop && \
    chmod 644 /system/build.prop

# 设置入口点
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh", "androidboot.hardware=redroid"]
