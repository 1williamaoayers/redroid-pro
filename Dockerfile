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

# 1. Download Libhoudini (Source: casualsnek/waydroid_script -> supremegamers)
# Using the exact commit hash verified in waydroid_script for Android 11
WORKDIR /tmp/libhoudini
RUN curl -L "https://github.com/supremegamers/vendor_intel_proprietary_houdini/archive/81f2a51ef539a35aead396ab7fce2adf89f46e88.zip" -o libhoudini.zip && \
    unzip -q libhoudini.zip && \
    rm libhoudini.zip

# Structure Libhoudini for Final Stage
# The zip extracts to a folder name based on commit hash
# We need to consolidate it into /tmp/libhoudini_final
RUN mkdir -p /tmp/libhoudini_final/system/lib/arm \
    /tmp/libhoudini_final/system/lib64/arm64 \
    /tmp/libhoudini_final/vendor/etc

# Move files (Logic adapted from waydroid_script)
# The repo structure is flat or specific, we assume the houdini files are inside "4081..." folder.
# We move the entire content to appropriate places.
# Since the structure of supremegamers repo matches /system and /vendor overlay:
# Adjusting based on standard android overlay patterns found in the zip.
# Assuming zip content: vendor_intel_proprietary_houdini-<commit>/...
RUN mv vendor_intel_proprietary_houdini-81f2a51ef539a35aead396ab7fce2adf89f46e88 /tmp/houdini_src && \
    # Copy system libs
    cp -r /tmp/houdini_src/system /tmp/libhoudini_final/ && \
    # Copy vendor libs
    cp -r /tmp/houdini_src/vendor /tmp/libhoudini_final/

# 2. Download & Extract OpenGApps
WORKDIR /tmp/gapps
# Note: Using a specific verified download link
RUN curl -L "https://sourceforge.net/projects/opengapps/files/x86_64/20220503/open_gapps-x86_64-11.0-pico-20220503.zip/download" -o opengapps.zip

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

# 1. Install Libhoudini (Restored from Supremegamers)
COPY --from=builder /tmp/libhoudini_final/system /system
COPY --from=builder /tmp/libhoudini_final/vendor /vendor

# 2. Install GApps (Copy from builder)
COPY --from=builder /output/system/priv-app /system/priv-app

# 3. Copy Configs & Scripts (From Builder to ensure LF format)
COPY privapp-permissions-google.xml /system/etc/permissions/privapp-permissions-google.xml
COPY --from=builder /scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY --from=builder /scripts/install_gapps.sh /usr/local/bin/install_gapps.sh

# 4. Final Permissions & Properties
RUN chown -R root:root /system/priv-app/ && \
    chmod 644 /system/priv-app/*/*.apk && \
    # Entrypoint permissions are already set in builder, but ensuring here helps
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
