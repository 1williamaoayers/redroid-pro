FROM redroid/redroid:11.0.0-latest

# Install tools
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    lzip \
    tar \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# --- Layer 1: Libhoudini (ARM Compatibility) ---
RUN curl -L "https://github.com/remote-android/redroid-doc/raw/master/android-builder-docker/native-bridge.tar" -o /native-bridge.tar && \
    tar -xf /native-bridge.tar -C / && \
    rm /native-bridge.tar

# --- Layer 2: OpenGApps (GMS) ---
RUN curl -L "https://sourceforge.net/projects/opengapps/files/x86_64/20220503/open_gapps-x86_64-11.0-pico-20220503.zip/download" -o /opengapps.zip

# Copy scripts and permissions
COPY install_gapps.sh /usr/local/bin/install_gapps.sh
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY privapp-permissions-google.xml /system/etc/permissions/privapp-permissions-google.xml

# Execute GApps installation & Setup Entrypoint
RUN chmod +x /usr/local/bin/install_gapps.sh /usr/local/bin/docker-entrypoint.sh && \
    /usr/local/bin/install_gapps.sh && \
    chown -R root:root /system/priv-app/

# --- Layer 3: Fingerprint & Properties ---
RUN echo "ro.product.model=Pixel 3 XL" >> /system/build.prop && \
    echo "ro.product.brand=google" >> /system/build.prop && \
    echo "ro.product.name=crosshatch" >> /system/build.prop && \
    echo "ro.product.device=crosshatch" >> /system/build.prop && \
    echo "ro.product.manufacturer=Google" >> /system/build.prop && \
    echo "ro.build.fingerprint=google/crosshatch/crosshatch:11/RQ3A.211001.001/7641976:user/release-keys" >> /system/build.prop && \
    chmod 644 /system/build.prop

# Set custom entrypoint for auto-proxy config
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh", "androidboot.hardware=redroid"]
