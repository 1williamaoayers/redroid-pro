# --- Stage 1: Resource Builder (Ubuntu) ---
# We use Ubuntu to download and extract files reliably
FROM ubuntu:22.04 AS builder

# Install tools
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    unzip \
    lzip \
    tar \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# 1. Download Libhoudini (REMOVED - Using Local Resources)
# The user has locally extracted the files to ./libhoudini/
# We will COPY them directly in the final stage.

# 2. Extract OpenGApps (Pre-downloaded by GitHub Actions)
WORKDIR /tmp/gapps
# Strategy: File is downloaded in the Workflow (build.yml) and passed to Docker context.
COPY opengapps.zip /tmp/opengapps.zip
RUN ls -lh /tmp/opengapps.zip

# --- SANITIZATION ZONE ---
# ... (scripts copy remains same) ...

# --- SANITIZATION ZONE ---
# Copy scripts here first to fix Windows Line Endings (CRLF -> LF)
COPY install_gapps.sh /scripts/install_gapps.sh
COPY docker-entrypoint.sh /scripts/docker-entrypoint.sh
# Use sed to remove carriage returns (\r) and make executable
RUN sed -i 's/\r$//' /scripts/install_gapps.sh && \
    sed -i 's/\r$//' /scripts/docker-entrypoint.sh && \
    chmod +x /scripts/install_gapps.sh /scripts/docker-entrypoint.sh

# Structure the output directory
RUN mkdir -p /output/system/priv-app && \
    mkdir -p /output/system/lib/arm

# Execute the extraction logic
RUN mkdir -p /tmp/gapps_extract && \
    unzip -q /tmp/opengapps.zip -d /tmp/gapps_extract && \
    rm /tmp/opengapps.zip && \
    # Debug: List available files
    echo "=== Available .tar.lz files ===" && \
    find /tmp/gapps_extract -name "*.tar.lz" && \
    echo "===============================" && \
    # Extract GmsCore (Play Services)
    lzip -d /tmp/gapps_extract/Core/gmscore-x86_64.tar.lz && \
    tar -xf /tmp/gapps_extract/Core/gmscore-x86_64.tar -C /tmp/gapps_extract/Core/ && \
    mkdir -p /output/system/priv-app/PrebuiltGmsCore && \
    cp $(find /tmp/gapps_extract/Core -path "*gmscore*" -name "*.apk" | head -n 1) /output/system/priv-app/PrebuiltGmsCore/PrebuiltGmsCore.apk && \
    # Extract GSF (Google Services Framework)
    lzip -d /tmp/gapps_extract/Core/gsfcore-all.tar.lz && \
    tar -xf /tmp/gapps_extract/Core/gsfcore-all.tar -C /tmp/gapps_extract/Core/ && \
    mkdir -p /output/system/priv-app/GoogleServicesFramework && \
    cp $(find /tmp/gapps_extract/Core -path "*gsfcore*" -name "*.apk" | head -n 1) /output/system/priv-app/GoogleServicesFramework/GoogleServicesFramework.apk && \
    # Extract Phonesky (Play Store)
    lzip -d /tmp/gapps_extract/Core/vending-x86_64.tar.lz && \
    tar -xf /tmp/gapps_extract/Core/vending-x86_64.tar -C /tmp/gapps_extract/Core/ && \
    mkdir -p /output/system/priv-app/Phonesky && \
    cp $(find /tmp/gapps_extract/Core -path "*vending*" -name "*.apk" | head -n 1) /output/system/priv-app/Phonesky/Phonesky.apk && \
    # Extract ConfigUpdater
    lzip -d /tmp/gapps_extract/Core/configupdater-all.tar.lz && \
    tar -xf /tmp/gapps_extract/Core/configupdater-all.tar -C /tmp/gapps_extract/Core/ && \
    mkdir -p /output/system/priv-app/ConfigUpdater && \
    cp $(find /tmp/gapps_extract/Core -path "*configupdater*" -name "*.apk" | head -n 1) /output/system/priv-app/ConfigUpdater/ConfigUpdater.apk


# --- Stage 2: Final Image (Redroid) ---
FROM redroid/redroid:11.0.0-latest

# 1. Install Libhoudini (Copy from Local Repo)
# We copy the entire folder content to root, effectively overlaying /system and /vendor
COPY libhoudini/ /

# 2. Install GApps (Copy from builder)
COPY --from=builder /output/system/priv-app /system/priv-app

# 3. Copy Configs & Scripts (From Builder to ensure LF format)
COPY privapp-permissions-google.xml /system/etc/permissions/privapp-permissions-google.xml
COPY --from=builder /scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY --from=builder /scripts/install_gapps.sh /usr/local/bin/install_gapps.sh

# 4. Final Permissions & Properties
RUN echo "=== Debug: Listing /system/priv-app contents ===" && \
    ls -laR /system/priv-app/ || echo "priv-app directory may be empty" && \
    echo "================================================" && \
    # Set ownership
    chown -R root:root /system/priv-app/ && \
    # Use find instead of glob to avoid "no match" errors
    find /system/priv-app -name "*.apk" -exec chmod 644 {} \; && \
    # Entrypoint permissions
    chmod +x /usr/local/bin/docker-entrypoint.sh && \
    # Fingerprint
    echo "ro.product.model=Pixel 3 XL" >> /system/build.prop && \
    echo "ro.product.brand=google" >> /system/build.prop && \
    echo "ro.product.name=crosshatch" >> /system/build.prop && \
    echo "ro.product.device=crosshatch" >> /system/build.prop && \
    echo "ro.product.manufacturer=Google" >> /system/build.prop && \
    echo "ro.build.fingerprint=google/crosshatch/crosshatch:11/RQ3A.211001.001/7641976:user/release-keys" >> /system/build.prop && \
    chmod 644 /system/build.prop

# Set Entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh", "androidboot.hardware=redroid"]
