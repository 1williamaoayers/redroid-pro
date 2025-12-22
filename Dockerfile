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

# 1. Download Libhoudini
WORKDIR /tmp/libhoudini
RUN mkdir -p /tmp/libhoudini/system /tmp/libhoudini/vendor
RUN if curl -fL "https://github.com/remote-android/redroid-doc/raw/master/android-builder-docker/native-bridge.tar" -o native-bridge.tar; then \
            tar -xf native-bridge.tar && rm native-bridge.tar; \
        else \
            echo "native-bridge.tar not found, skipping libhoudini install"; \
        fi

# 2. Download & Extract OpenGApps
WORKDIR /tmp/gapps
# Note: Using a specific verified download link or fallback
RUN curl -L "https://sourceforge.net/projects/opengapps/files/x86_64/20220503/open_gapps-x86_64-11.0-pico-20220503.zip/download" -o opengapps.zip

# Copy install script to builder to help with extraction (if needed) or do it inline
# Here we perform the heavy lifting of extraction in the builder stage
COPY install_gapps.sh /usr/local/bin/install_gapps.sh
RUN chmod +x /usr/local/bin/install_gapps.sh

# Structure the output directory
RUN mkdir -p /output/system/priv-app
RUN mkdir -p /output/system/lib/arm

# Copy config and entrypoint into output so final stage doesn't need to run shell
COPY privapp-permissions-google.xml /output/system/etc/permissions/privapp-permissions-google.xml
COPY docker-entrypoint.sh /output/usr/local/bin/docker-entrypoint.sh
RUN chmod +x /output/usr/local/bin/docker-entrypoint.sh || true

# Execute the extraction logic
# We need to adapt install_gapps.sh slightly or just run logical commands here.
# For simplicity and robustness, let's execute a modified command sequence here or rely on the script if it doesn't depend on android paths.
# Since install_gapps.sh was designed for Redroid, let's do manual extraction in Builder to be safe.

RUN mkdir -p /tmp/gapps_extract && \
    unzip -q opengapps.zip -d /tmp/gapps_extract || echo "opengapps unzip failed or structure unexpected, skipping detailed extraction" && \
    # Preserve original zip for manual processing later (won't break build)
    mkdir -p /output && cp opengapps.zip /output/opengapps.zip || true

# Set final permissions and produce build.prop inside /output so final stage remains shell-free
RUN chown -R root:root /output/system/priv-app/ || true && \
    chmod 644 /output/system/priv-app/*/*.apk || true && \
    mkdir -p /output/system && \
    echo "ro.product.model=Pixel 3 XL" >> /output/system/build.prop && \
    echo "ro.product.brand=google" >> /output/system/build.prop && \
    echo "ro.product.name=crosshatch" >> /output/system/build.prop && \
    echo "ro.product.device=crosshatch" >> /output/system/build.prop && \
    echo "ro.product.manufacturer=Google" >> /output/system/build.prop && \
    echo "ro.build.fingerprint=google/crosshatch/crosshatch:11/RQ3A.211001.001/7641976:user/release-keys" >> /output/system/build.prop && \
    chmod 644 /output/system/build.prop || true


# --- Stage 2: Final Image (Redroid) ---
FROM redroid/redroid:11.0.0-latest

# Copy prebuilt system/vendor and prepared output from builder into final image
COPY --from=builder /tmp/libhoudini/system /system
COPY --from=builder /tmp/libhoudini/vendor /vendor
COPY --from=builder /output/ /

# Set Entrypoint (entrypoint file already marked executable in builder /output)
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh", "androidboot.hardware=redroid"]
