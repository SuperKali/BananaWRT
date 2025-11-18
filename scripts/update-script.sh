#!/bin/sh

print_banner() {
    echo -e "\033[1;36m"
    echo "    ____                               _       ______  ______"
    echo "   / __ )____ _____  ____ _____  ____ | |     / / __ \/_  __/"
    echo "  / __  / __ \`/ __ \/ __ \`/ __ \/ __ \`/ | /| / / /_/ / / /   "
    echo " / /_/ / /_/ / / / / /_/ / / / / /_/ /| |/ |/ / _, _/ / /    "
    echo "/_____/\__,_/_/ /_/\__,_/_/ /_/\__,_/ |__/|__/_/ |_| /_/     "
    echo -e "\033[1;33m          BananaWRT - The Ultimate System Updater 🚀       \033[0m"
    echo ""
}

my_sleep() {
    if command -v usleep >/dev/null 2>&1; then
        usleep 100000
    else
        sleep 1
    fi
}

spinner_with_prefix() {
    local pid=$1
    local prefix="$2"
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r%b [%c]" "$prefix" "${spinstr:0:1}"
        spinstr=${spinstr#?}${spinstr%"$spinstr"}
        my_sleep
    done
    printf "\r%b [✓]\n" "$prefix"
}

log_info() {
    echo -e "\033[1;36m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

usage() {
    echo "Usage: $0 [fota|ota|packages] [--dry-run] [--reset]"
    exit 1
}

version_greater() {
    printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1 | grep -q "^$2$"
}

check_and_update_compat_version() {
    REQUIRED_VERSION="$1"
    CURRENT_VERSION=$(uci get system.@system[0].compat_version 2>/dev/null || echo "0.0")
  
    if version_greater "$REQUIRED_VERSION" "$CURRENT_VERSION"; then
        log_info "Updating compat_version from $CURRENT_VERSION to $REQUIRED_VERSION..."
        uci set system.@system[0].compat_version="$REQUIRED_VERSION"
        uci commit system
        log_success "compat_version updated to $REQUIRED_VERSION."
    else
        log_info "Current compat_version ($CURRENT_VERSION) is already compatible or greater."
    fi
}

MODE=""
DRY_RUN=0
RESET=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        fota|ota|packages)
            if [ -n "$MODE" ]; then
                usage
            fi
            MODE="$1"
            ;;
        --dry-run)
            DRY_RUN=1
            ;;
        --reset)
            RESET=1
            ;;
        *)
            usage
            ;;
    esac
    shift
done

if [ -z "$MODE" ]; then
    usage
fi

print_banner

if [ "$MODE" = "fota" ]; then
    command -v curl >/dev/null 2>&1 || { log_error "curl is not installed. Cannot continue."; exit 1; }
    command -v jq >/dev/null 2>&1 || { log_error "jq is not installed. Cannot continue."; exit 1; }
    BANANA_CURRENT_RELEASE=$(grep -o "BANANAWRT_BUILD_DATE='.*'" /etc/bananawrt_release  | cut -d "'" -f 2)
    [ ! -z "$BANANA_CURRENT_RELEASE" ] && log_info "Current firmware version: $BANANA_CURRENT_RELEASE"
    log_info "Fetching releases from GitHub..."
    tempfile=$(mktemp)
    ( curl -s "https://api.github.com/repos/SuperKali/BananaWRT/releases" > "$tempfile" ) &
    curl_pid=$!
    spinner_with_prefix $curl_pid "\033[1;33mLoading releases...\033[0m"
    wait $curl_pid
    RELEASES_JSON=$(cat "$tempfile")
    rm -f "$tempfile"
    echo ""
    echo -e "\033[1;35mLast 4 available releases:\033[0m"
    for i in 0 1 2 3; do
        tag=$(echo "$RELEASES_JSON" | jq -r ".[$i].tag_name")
        asset=$(echo "$RELEASES_JSON" | jq -r ".[$i].assets[] | select(.name | endswith(\"emmc-preloader.bin\")) | .name" | head -n 1)
        fw=$(echo "$asset" | sed -n 's/^immortalwrt-\(.*\)-mediatek.*$/\1/p')
        [ -z "$fw" ] && fw="N/A"
        body=$(echo "$RELEASES_JSON" | jq -r ".[$i].body")
        if echo "$body" | grep -iq "Stable Release"; then
            rtype="Stable"
        elif echo "$body" | grep -iq "Nightly Release"; then
            rtype="Nightly"
        else
            rtype="Unknown"
        fi
        echo -e "\033[1;33m$((i+1)))\033[0m \033[1;36m$tag\033[0m - \033[1;32mFirmware: $fw\033[0m - \033[1;35m$rtype\033[0m"
    done
    echo ""
    echo -e "\033[1;35mSelect the release number to install (default 1):\033[0m"
    read -r selection
    [ -z "$selection" ] && selection=1

    # Validate selection is a number between 1-4
    if ! [[ "$selection" =~ ^[1-4]$ ]]; then
        log_error "Invalid selection. Must be between 1-4."
        exit 1
    fi

    index=$((selection - 1))
    SELECTED_VERSION=$(echo "$RELEASES_JSON" | jq -r ".[$index].tag_name")
    if [ -z "$SELECTED_VERSION" ] || [ "$SELECTED_VERSION" = "null" ]; then
        log_error "Invalid release selected."
        exit 1
    fi
    log_info "Selected release: $SELECTED_VERSION"
    RELEASE_TAG="$SELECTED_VERSION"
    asset_selected=$(echo "$RELEASES_JSON" | jq -r ".[$index].assets[] | select(.name | endswith(\"emmc-preloader.bin\")) | .name" | head -n 1)
    FIRMWARE_VERSION=$(echo "$asset_selected" | sed -n 's/^immortalwrt-\(.*\)-mediatek.*$/\1/p')
    [ -z "$FIRMWARE_VERSION" ] && { log_error "Unable to determine Firmware Version from the release."; exit 1; }
    log_info "Detected Firmware Version: $FIRMWARE_VERSION"
elif [ "$MODE" = "ota" ]; then
    echo ""
    echo -e "\033[1;35mOTA Mode:\033[0m Enter the Firmware Version of the files in /tmp (e.g., 24.10.0 or 24.10.0-rc4):"
    read -r FIRMWARE_VERSION
    [ -z "$FIRMWARE_VERSION" ] && { log_error "Firmware Version not specified. Cannot continue."; exit 1; }

    # Validate firmware version format (basic semver check)
    if ! [[ "$FIRMWARE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
        log_error "Invalid firmware version format. Expected format: X.Y.Z or X.Y.Z-rcN"
        exit 1
    fi
elif [ "$MODE" = "packages" ]; then
    command -v curl >/dev/null 2>&1 || { log_error "curl is not installed. Cannot continue."; exit 1; }
    command -v jq >/dev/null 2>&1 || { log_error "jq is not installed. Cannot continue."; exit 1; }
    command -v opkg >/dev/null 2>&1 || { log_error "opkg is not installed. Cannot continue."; exit 1; }
    
    FIRMWARE_VERSION=$(grep -o "DISTRIB_RELEASE='.*'" /etc/openwrt_release | cut -d "'" -f 2)
    [ -z "$FIRMWARE_VERSION" ] && { log_error "Unable to determine current firmware version."; exit 1; }
    log_info "Current firmware version: $FIRMWARE_VERSION"
    
    REPO_URL="https://repo.superkali.me/releases/$FIRMWARE_VERSION/packages/additional_pack/index.json"
    log_info "Fetching package index from $REPO_URL..."
    tempfile=$(mktemp)
    ( curl -s "$REPO_URL" > "$tempfile" ) &
    curl_pid=$!
    spinner_with_prefix $curl_pid "\033[1;33mFetching package index...\033[0m"
    wait $curl_pid
    
    if [ ! -s "$tempfile" ]; then
        log_error "Failed to download package index or file is empty."
        rm -f "$tempfile"
        exit 1
    fi
    
    ARCH=$(jq -r '.architecture' "$tempfile")
    [ -z "$ARCH" ] || [ "$ARCH" = "null" ] && { log_error "Architecture not found in package index."; rm -f "$tempfile"; exit 1; }
    log_info "Package architecture: $ARCH"
    
    packages_update_list=$(mktemp)
    
    log_info "Checking packages for updates..."
    
    jq -r '.packages | to_entries[] | "\(.key)|\(.value)"' "$tempfile" > "$packages_update_list"
    
    updates_needed=0
    updates_list=$(mktemp)
    
    while IFS='|' read -r pkg_name repo_version; do
        if echo "$pkg_name" | grep -q "^luci-i18n-"; then
            continue
        fi
        
        local_version=$(opkg list-installed | grep "^$pkg_name - " | cut -d ' ' -f 3)
        
        if [ -z "$local_version" ]; then
            echo -e " - \033[1;36m$pkg_name\033[0m: \033[1;33mNot installed\033[0m -> \033[1;32m$repo_version\033[0m" >> "$updates_list"
            updates_needed=1
        elif [ "$local_version" != "$repo_version" ]; then
            echo -e " - \033[1;36m$pkg_name\033[0m: \033[1;33m$local_version\033[0m -> \033[1;32m$repo_version\033[0m" >> "$updates_list"
            updates_needed=1
        fi
    done < "$packages_update_list"
    
    if [ "$updates_needed" -eq 1 ]; then
        echo -e "\033[1;35mPackages available for update:\033[0m"
        cat "$updates_list"
        echo ""
        echo -e "\033[1;35mDo you want to proceed with updating these packages? (y/n):\033[0m"
        read -r proceed
        
        if [ "$proceed" != "y" ] && [ "$proceed" != "Y" ]; then
            log_info "Update cancelled."
            rm -f "$tempfile" "$packages_update_list" "$updates_list"
            exit 0
        fi
        
        REPO_CONF="/etc/opkg/customfeeds.conf"
        REPO_LINE="src/gz additional_pack https://repo.superkali.me/releases/$FIRMWARE_VERSION/packages/additional_pack"
        
        if ! grep -q "$REPO_LINE" "$REPO_CONF" 2>/dev/null; then
            log_info "Adding custom repository..."
            if [ "$DRY_RUN" -eq 1 ]; then
                log_info "DRY-RUN: Would add repository: $REPO_LINE"
            else
                echo "$REPO_LINE" >> "$REPO_CONF"
            fi
        fi
        
        log_info "Updating package lists..."
        if [ "$DRY_RUN" -eq 1 ]; then
            log_info "DRY-RUN: Would run 'opkg update'"
        else
            opkg update
        fi
        
        while IFS='|' read -r pkg_name repo_version; do
            if echo "$pkg_name" | grep -q "^luci-i18n-"; then
                continue
            fi
            
            local_version=$(opkg list-installed | grep "^$pkg_name - " | cut -d ' ' -f 3)
            
            if [ -z "$local_version" ] || [ "$local_version" != "$repo_version" ]; then
                log_info "Installing/upgrading $pkg_name ($repo_version)..."
                if [ "$DRY_RUN" -eq 1 ]; then
                    log_info "DRY-RUN: Would run 'opkg install $pkg_name'"
                else
                    opkg install "$pkg_name"
                fi
            fi
        done < "$packages_update_list"
        
        log_success "Package updates completed."
    else
        log_success "All packages are up to date."
    fi
    
    rm -f "$tempfile" "$packages_update_list" "$updates_list"
    exit 0
fi

EMMC_PRELOADER="/tmp/immortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-emmc-preloader.bin"
EMMC_BL31_UBOOT="/tmp/immortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-emmc-bl31-uboot.fip"
EMMC_INITRAMFS="/tmp/immortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-initramfs-recovery.itb"
SYSUPGRADE_IMG="/tmp/immortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-squashfs-sysupgrade.itb"

if [ "$MODE" = "fota" ]; then
    for asset in "emmc-preloader" "emmc-bl31-uboot" "initramfs-recovery" "squashfs-sysupgrade"; do
        case "$asset" in
            emmc-preloader)
                filename="immortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-emmc-preloader.bin"
                ;;
            emmc-bl31-uboot)
                filename="immortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-emmc-bl31-uboot.fip"
                ;;
            initramfs-recovery)
                filename="immortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-initramfs-recovery.itb"
                ;;
            squashfs-sysupgrade)
                filename="immortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-squashfs-sysupgrade.itb"
                ;;
        esac
        prefix="\033[1;36mDownloading $filename...\033[0m"
        asset_url=$(echo "$RELEASES_JSON" | jq -r ".[$index].assets[] | select(.name==\"$filename\") | .browser_download_url")
        [ -z "$asset_url" ] || [ "$asset_url" = "null" ] && { log_error "Asset $filename not found for release $RELEASE_TAG."; exit 1; }

        if [ "$DRY_RUN" -eq 1 ]; then
            printf "%b\n" "$prefix"
            log_info "DRY-RUN: Simulated download of $filename from $asset_url"
            touch "/tmp/$filename"
            echo ""
        else
            printf "%b " "$prefix"
            ( curl -s -L -o "/tmp/$filename" "$asset_url" ) &
            curl_pid=$!
            spinner_with_prefix $curl_pid "$prefix"
            echo ""
            if ! wait $curl_pid; then
                log_error "Error downloading $filename."
                exit 1
            fi
            log_success "$filename downloaded successfully."
        fi
    done
fi

echo ""

if [ "$MODE" = "ota" ]; then
    echo -e "\033[1;35mEnsure the following files are present in \033[1;31m/tmp\033[0;35m:\033[0m"
else
    echo -e "\033[1;35mThe following files have been downloaded to \033[1;31m/tmp\033[0;35m:\033[0m"
fi

echo -e " - \033[1;36mimmortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-emmc-preloader.bin\033[0m"
echo -e " - \033[1;36mimmortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-emmc-bl31-uboot.fip\033[0m"
echo -e " - \033[1;36mimmortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-initramfs-recovery.itb\033[0m"
echo -e " - \033[1;36mimmortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-squashfs-sysupgrade.itb\033[0m"
echo ""
echo -e "\033[1;35mPress Enter to continue or CTRL+C to abort...\033[0m"
read -r dummy

log_info "Checking required files..."
for file in "$EMMC_PRELOADER" "$EMMC_BL31_UBOOT" "$EMMC_INITRAMFS" "$SYSUPGRADE_IMG"; do
    if [ ! -f "$file" ]; then
        log_error "Required file not found: $file"
        exit 1
    fi
done
log_success "All required files are present."

log_info "Enabling write access to /dev/mmcblk0boot0..."
if [ "$DRY_RUN" -eq 1 ]; then
    log_info "DRY-RUN: Simulated enabling write access to /dev/mmcblk0boot0."
else
    echo 0 > /sys/block/mmcblk0boot0/force_ro
    [ $? -ne 0 ] && { log_error "Unable to enable write access to /dev/mmcblk0boot0."; exit 1; }
fi
log_success "Write access enabled."

flash_partition() {
    PARTITION="$1"
    IMAGE="$2"

    if [ "$DRY_RUN" -eq 1 ]; then
        log_info "DRY-RUN: Simulated erasing partition $PARTITION (dd if=/dev/zero ...)."
        log_info "DRY-RUN: Simulated flashing $IMAGE to $PARTITION (dd if=$IMAGE ...)."
        return 0
    fi

    # Validate partition is a block device
    if [ ! -b "$PARTITION" ]; then
        log_error "Partition $PARTITION is not a valid block device."
        exit 1
    fi

    # Validate image file exists
    if [ ! -f "$IMAGE" ]; then
        log_error "Image file $IMAGE does not exist."
        exit 1
    fi

    # Check image file is not empty
    if [ ! -s "$IMAGE" ]; then
        log_error "Image file $IMAGE is empty."
        exit 1
    fi

    log_info "Erasing partition $PARTITION..."
    dd if=/dev/zero of="$PARTITION" bs=1M count=4
    [ $? -ne 0 ] && { log_error "Error erasing partition $PARTITION."; exit 1; }
    log_info "Flashing $IMAGE to $PARTITION..."
    dd if="$IMAGE" of="$PARTITION" bs=1M
    [ $? -ne 0 ] && { log_error "Error flashing $IMAGE to $PARTITION."; exit 1; }
    log_success "$IMAGE flashed successfully to $PARTITION."
}

flash_partition /dev/mmcblk0boot0 "$EMMC_PRELOADER"
flash_partition /dev/mmcblk0p3 "$EMMC_BL31_UBOOT"
flash_partition /dev/mmcblk0p4 "$EMMC_INITRAMFS"

if [ "$DRY_RUN" -eq 1 ]; then
    log_info "DRY-RUN: Simulated sync call."
else
    sync
fi

log_success "Flashing completed successfully."

log_info "Verifying sysupgrade with file $SYSUPGRADE_IMG..."
if [ "$DRY_RUN" -eq 1 ]; then
    log_info "DRY-RUN: Simulated sysupgrade test for file $SYSUPGRADE_IMG."
    SYSUPGRADE_LOG="Simulated sysupgrade test - closing"
else
    SYSUPGRADE_LOG=$(sysupgrade -T "$SYSUPGRADE_IMG" 2>&1)
fi

if echo "$SYSUPGRADE_LOG" | grep -q "The device is supported, but the config is incompatible"; then
    REQUIRED_VERSION=$(echo "$SYSUPGRADE_LOG" | grep "incompatible" | awk -F'->' '{print $2}' | awk -F')' '{print $1}' | tr -d '[:space:]')
    if [ -n "$REQUIRED_VERSION" ]; then
        log_info "Required compat_version detected: $REQUIRED_VERSION"
        check_and_update_compat_version "$REQUIRED_VERSION"
    else
        log_error "Unable to detect compat_version. Exiting."
        exit 1
    fi
fi

if [ "$RESET" -eq 1 ]; then
    log_info "Starting sysupgrade without preserving configuration..."
    sysupgrade_cmd="sysupgrade -n"
else
    log_info "Starting sysupgrade with configuration preserved..."
    sysupgrade_cmd="sysupgrade -k"
fi

log_info "Starting sysupgrade with file $SYSUPGRADE_IMG..."
sleep 2
if [ "$DRY_RUN" -eq 1 ]; then
    log_info "DRY-RUN: Simulated sysupgrade execution with $SYSUPGRADE_IMG."
    SYSUPGRADE_OUTPUT="Simulated sysupgrade - closing"
else
    SYSUPGRADE_OUTPUT=$($sysupgrade_cmd "$SYSUPGRADE_IMG" 2>&1)
fi

if echo "$SYSUPGRADE_OUTPUT" | grep -iq "closing"; then
    log_success "Sysupgrade process started successfully."
else
    log_error "Sysupgrade failed or unexpected behavior:"
    echo "$SYSUPGRADE_OUTPUT"
    exit 1
fi

log_success "Sysupgrade successfully initiated. The device is rebooting..."