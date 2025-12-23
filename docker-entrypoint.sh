#!/system/bin/sh

# ==============================================================================
# Redroid Pro 启动脚本
# 在容器运行时配置设备指纹和网络
# ==============================================================================

# --- 1. 设置设备指纹（伪装为 Pixel 3 XL）---
# 使用 setprop 命令（在运行时设置系统属性）
echo "[CloudVerse] 📱 Setting device fingerprint..."
setprop ro.product.model "Pixel 3 XL"
setprop ro.product.brand "google"
setprop ro.product.name "crosshatch"
setprop ro.product.device "crosshatch"
setprop ro.product.manufacturer "Google"
setprop ro.build.fingerprint "google/crosshatch/crosshatch:11/RQ3A.211001.001/7641976:user/release-keys"

# --- 2. Android Go Optimization (Low RAM Mode) ---
if [ "$ENABLE_LOW_RAM" = "true" ]; then
    echo "[CloudVerse] 🚀 Enabling Android Go (Low RAM) optimizations..."
    setprop ro.config.low_ram true
    setprop config.disable_consumerir true
fi

# --- 3. Smart Network Configuration ---
PROXY_PORT=${PROXY_PORT:-"20171"}

get_gateway() {
    ip route show 2>/dev/null | grep default | awk '{print $3}'
}

# 后台配置网络（等待 Android 完全启动）
(
    echo "[CloudVerse] 📡 Waiting for Android system to boot..."
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 2
    done

    DETECTED_IP=""
    
    if [ ! -z "$PROXY_HOST" ]; then
        echo "[CloudVerse] 🎯 Using configured PROXY_HOST: $PROXY_HOST"
        DETECTED_IP=$PROXY_HOST
    else
        GATEWAY_IP=$(get_gateway)
        echo "[CloudVerse] 🛰️ Auto-detected Gateway IP: $GATEWAY_IP"
        DETECTED_IP=$GATEWAY_IP
    fi

    if [ ! -z "$DETECTED_IP" ]; then
        echo "[CloudVerse] 🔌 Configuring Global Proxy to $DETECTED_IP:$PROXY_PORT..."
        for i in 1 2 3 4 5; do
            settings put global http_proxy "${DETECTED_IP}:${PROXY_PORT}" 2>/dev/null && break
            sleep 3
        done
        echo "[CloudVerse] ✅ Proxy Configured!"
    fi
    
    # 设置 DNS
    setprop net.dns1 223.5.5.5
    echo "[CloudVerse] 🌍 Network configuration complete!"
) &

# --- 4. 启动 Android 系统 ---
echo "[CloudVerse] 🚀 Starting Android..."
exec /init "$@"
