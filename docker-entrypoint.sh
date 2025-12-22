#!/bin/bash

# --- 1. Android Go Optimization (Low RAM Mode) ---
if [ "$ENABLE_LOW_RAM" = "true" ]; then
    echo "[Dream] 🚀 Enabling Android Go (Low RAM) optimizations..."
    # Enable Low RAM flag
    echo "ro.config.low_ram=true" >> /system/build.prop
    # Disable heavy features
    echo "config.disable_consumerir=true" >> /system/build.prop
    echo "config.disable_location=true" >> /system/build.prop
fi

# --- 2. Smart Protocol Discovery ---
# Default to provided env or fallback to gateway
PROXY_PORT=${PROXY_PORT:-"20171"}

# Function to get default gateway
get_gateway() {
    ip route show | grep default | awk '{print $3}'
}

# Start background configuration daemon
(
    echo "[Dream] 📡 Waiting for Android system..."
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 2
    done

    DETECTED_IP=""
    
    # Strategy 1: Check Env Var PROXY_HOST first
    if [ ! -z "$PROXY_HOST" ]; then
        echo "[Dream] 🎯 Using configured PROXY_HOST: $PROXY_HOST"
        DETECTED_IP=$PROXY_HOST
    else
        # Strategy 2: Auto-detect Gateway
        GATEWAY_IP=$(get_gateway)
        echo "[Dream] 🛰️ Auto-detected Gateway IP: $GATEWAY_IP"
        
        # Simple connectivity check (requires netcat/nc, usually available or use pure bash)
        # Here we assume blindly it is the host for "Dream" simplicity unless we install nc
        DETECTED_IP=$GATEWAY_IP
    fi

    echo "[Dream] 🔌 Configuring Global Proxy to $DETECTED_IP:$PROXY_PORT..."
    
    # Retry loop to ensure settings provider is ready
    for i in {1..10}; do
        settings put global http_proxy "${DETECTED_IP}:${PROXY_PORT}"
        if [ $? -eq 0 ]; then
            echo "[Dream] ✅ Proxy Configured Successfully!"
            echo "[Dream] 🌍 You are now connected to the world."
            break
        fi
        sleep 3
    done
    
    # Optional: Set Public DNS for reliability
    setprop net.dns1 223.5.5.5
) &

# Exec original init
exec /init "$@"
