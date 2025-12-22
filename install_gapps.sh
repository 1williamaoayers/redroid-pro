#!/bin/bash
set -e

GAPPS_ZIP="/opengapps.zip"
TMP_DIR="/tmp/gapps"
SYSTEM_DIR="/system"

# 1. Prepare
mkdir -p "$TMP_DIR"
echo "Unzipping OpenGApps..."
unzip -q "$GAPPS_ZIP" -d "$TMP_DIR"

# 2. Function to extract specific module
extract_module() {
    local module_name="$1" # e.g., "google-play-services"
    local priv_app_name="$2" # e.g., "PrebuiltGmsCore" or "GmsCore"
    
    echo "Extracting $module_name..."
    local lz_file=$(find "$TMP_DIR/Core" -name "${module_name}-*.lz" | head -n 1)
    
    if [ -z "$lz_file" ]; then
        echo "Error: Module $module_name not found!"
        return 1
    fi

    lzip -d "$lz_file"
    local tar_file="${lz_file%.lz}"
    
    # Create temp extraction dir for this module
    mkdir -p "$TMP_DIR/extract/$module_name"
    tar -xf "$tar_file" -C "$TMP_DIR/extract/$module_name"
    
    # Find the APK (usually in nodpi/app-name.apk or similar)
    local apk_file=$(find "$TMP_DIR/extract/$module_name" -name "*.apk" | head -n 1)
    
    if [ -z "$apk_file" ]; then
        echo "Error: APK for $module_name not found!"
        return 1
    fi
    
    # Move to system
    echo "Installing to $SYSTEM_DIR/priv-app/$priv_app_name/..."
    mkdir -p "$SYSTEM_DIR/priv-app/$priv_app_name"
    cp "$apk_file" "$SYSTEM_DIR/priv-app/$priv_app_name/$priv_app_name.apk"
}

# 3. Extract Core GApps
# GmsCore (Play Services)
extract_module "google-play-services-x86_64" "PrebuiltGmsCore"
# Gsf (Services Framework)
extract_module "google-services-framework" "GoogleServicesFramework"
# Phonesky (Play Store)
extract_module "vending" "Phonesky"
# ConfigUpdater (Optional but recommended)
extract_module "configupdater" "ConfigUpdater"

# 4. Cleanup
echo "Cleaning up..."
rm -rf "$TMP_DIR"
rm -f "$GAPPS_ZIP"

echo "GApps installation complete."
