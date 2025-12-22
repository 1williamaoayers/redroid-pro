# --- Stage 1: Resource Builder (Ubuntu) ---
# We use Ubuntu to download and extract files reliably
FROM ubuntu:22.04 AS builder

# Install tools
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    lzip \
    tar \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# 1. Download Libhoudini
WORKDIR /tmp/libhoudini
RUN curl -L "https://github.com/remote-android/redroid-doc/raw/master/android-builder-docker/native-bridge.tar" -o native-bridge.tar && \
    tar -xf native-bridge.tar && \
    rm native-bridge.tar

# 2. Download & Extract OpenGApps
WORKDIR /tmp/gapps
# Note: Using a specific verified download link or fallback
RUN curl -L "https://sourceforge.net/projects/opengapps/files/x86_64/20220503/open_gapps-x86_64-11.0-pico-20220503.zip/download" -o opengapps.zip

# Copy install script to builder to help with extraction (if needed) or do it inline
# Here we perform the heavy lifting of extraction in the builder stage
COPY install_gapps.sh /usr/local/bin/install_gapps.sh
RUN chmod +x /usr/local/bin/install_gapps.sh

# Structure the output directory
mkdir -p /output/system/priv-app
mkdir -p /output/system/lib/arm

# Execute the extraction logic
# We need to adapt install_gapps.sh slightly or just run logical commands here.
# For simplicity and robustness, let's execute a modified command sequence here or rely on the script if it doesn't depend on android paths.
# Since install_gapps.sh was designed for Redroid, let's do manual extraction in Builder to be safe.

RUN mkdir -p /tmp/gapps_extract && \
    unzip -q opengapps.zip -d /tmp/gapps_extract && \
    # Extract GmsCore
    lzip -d /tmp/gapps_extract/Core/google-play-services-x86_64-nodpi.tar.lz && \
    tar -xf /tmp/gapps_extract/Core/google-play-services-x86_64-nodpi.tar -C /tmp/gapps_extract/Core/ && \
    mkdir -p /output/system/priv-app/PrebuiltGmsCore && \
    cp $(find /tmp/gapps_extract/Core/google-play-services-x86_64-nodpi -name "*.apk" | head -n 1) /output/system/priv-app/PrebuiltGmsCore/PrebuiltGmsCore.apk && \
    # Extract Gsf
    lzip -d /tmp/gapps_extract/Core/google-services-framework.tar.lz && \
    tar -xf /tmp/gapps_extract/Core/google-services-framework.tar -C /tmp/gapps_extract/Core/ && \
    mkdir -p /output/system/priv-app/GoogleServicesFramework && \
    cp $(find /tmp/gapps_extract/Core/google-services-framework -name "*.apk" | head -n 1) /output/system/priv-app/GoogleServicesFramework/GoogleServicesFramework.apk && \
    # Extract Phonesky
    lzip -d /tmp/gapps_extract/Core/vending.tar.lz && \
    tar -xf /tmp/gapps_extract/Core/vending.tar -C /tmp/gapps_extract/Core/ && \
    mkdir -p /output/system/priv-app/Phonesky && \
    cp $(find /tmp/gapps_extract/Core/vending -name "*.apk" | head -n 1) /output/system/priv-app/Phonesky/Phonesky.apk && \
    # Extract ConfigUpdater
    lzip -d /tmp/gapps_extract/Core/configupdater.tar.lz && \
    tar -xf /tmp/gapps_extract/Core/configupdater.tar -C /tmp/gapps_extract/Core/ && \
    mkdir -p /output/system/priv-app/ConfigUpdater && \
    cp $(find /tmp/gapps_extract/Core/configupdater -name "*.apk" | head -n 1) /output/system/priv-app/ConfigUpdater/ConfigUpdater.apk


# --- Stage 2: Final Image (Redroid) ---
FROM redroid/redroid:11.0.0-latest

# 1. Install Libhoudini (Copy from builder)
COPY --from=builder /tmp/libhoudini/system /system
COPY --from=builder /tmp/libhoudini/vendor /vendor

# 2. Install GApps (Copy from builder)
COPY --from=builder /output/system/priv-app /system/priv-app

# 3. Copy Configs & Scripts
COPY privapp-permissions-google.xml /system/etc/permissions/privapp-permissions-google.xml
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# 4. Final Permissions & Properties
RUN chown -R root:root /system/priv-app/ && \
    chmod 644 /system/priv-app/*/*.apk && \
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
