#!/bin/sh

FIRMWARE_INDEX_URL="https://repo.superkali.me/bananawrt/firmware/firmware-index.json"

print_banner() {
    echo -e "\033[1;36m"
    echo "    ____                               _       ______  ______"
    echo "   / __ )____ _____  ____ _____  ____ | |     / / __ \/_  __/"
    echo "  / __  / __ \`/ __ \/ __ \`/ __ \/ __ \`/ | /| / / /_/ / / /   "
    echo " / /_/ / /_/ / / / / /_/ / / / / /_/ /| |/ |/ / _, _/ / /    "
    echo "/_____/\__,_/_/ /_/\__,_/_/ /_/\__,_/ |__/|__/_/ |_| /_/     "
    echo -e "\033[1;33m          BananaWRT - The Ultimate System Updater          \033[0m"
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

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
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

detect_current_version() {
    # Read from bananawrt_release
    if [ -f /etc/bananawrt_release ]; then
        BANANA_CURRENT_RELEASE=$(grep "BANANAWRT_BUILD_DATE" /etc/bananawrt_release 2>/dev/null | cut -d"'" -f2)
        BANANA_CURRENT_TYPE=$(grep "BANANAWRT_TYPE" /etc/bananawrt_release 2>/dev/null | cut -d"'" -f2)
        BANANA_CURRENT_LINE=$(grep "BANANAWRT_VERSION_LINE" /etc/bananawrt_release 2>/dev/null | cut -d"'" -f2)
        BANANA_CURRENT_IWRT=$(grep "BANANAWRT_IMMORTALWRT_VERSION" /etc/bananawrt_release 2>/dev/null | cut -d"'" -f2)
    fi

    # Fallback for legacy firmware (pre-migration, no VERSION_LINE field)
    if [ -z "$BANANA_CURRENT_LINE" ]; then
        FW_VER=$(grep "DISTRIB_RELEASE" /etc/openwrt_release 2>/dev/null | cut -d"'" -f2)
        if [ -n "$FW_VER" ]; then
            MAJOR_MINOR=$(echo "$FW_VER" | sed -n 's/^\([0-9]*\.[0-9]*\).*/\1/p')
            BANANA_CURRENT_LINE="v${MAJOR_MINOR}"
            BANANA_CURRENT_IWRT="$FW_VER"
        fi
    fi

    # Default track to stable if unknown
    [ -z "$BANANA_CURRENT_TYPE" ] && BANANA_CURRENT_TYPE="stable"
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

    detect_current_version

    [ -n "$BANANA_CURRENT_RELEASE" ] && log_info "Current build: $BANANA_CURRENT_RELEASE"
    [ -n "$BANANA_CURRENT_LINE" ] && log_info "Current version line: $BANANA_CURRENT_LINE ($BANANA_CURRENT_TYPE)"

    log_info "Fetching firmware index from repo.superkali.me..."
    tempfile=$(mktemp)
    ( curl -sf "$FIRMWARE_INDEX_URL" > "$tempfile" ) &
    curl_pid=$!
    spinner_with_prefix $curl_pid "\033[1;33mLoading firmware index...\033[0m"
    wait $curl_pid

    if [ ! -s "$tempfile" ]; then
        log_error "Failed to download firmware index."
        rm -f "$tempfile"
        exit 1
    fi

    INDEX_JSON=$(cat "$tempfile")
    rm -f "$tempfile"

    # Check if current version line is EOL
    CURRENT_STATUS=$(echo "$INDEX_JSON" | jq -r ".versions[\"$BANANA_CURRENT_LINE\"].status // \"unknown\"")
    if [ "$CURRENT_STATUS" = "eol" ]; then
        log_warning "Your version line ($BANANA_CURRENT_LINE) is End-of-Life."
        log_warning "Consider upgrading to a newer version (see cross-version options below)."
        echo ""
    fi

    # Get builds for current version line and track
    BUILDS=$(echo "$INDEX_JSON" | jq -r ".versions[\"$BANANA_CURRENT_LINE\"].tracks[\"$BANANA_CURRENT_TYPE\"].builds // []")
    BUILD_COUNT=$(echo "$BUILDS" | jq 'length')
    DISPLAY_COUNT=4
    [ "$BUILD_COUNT" -lt "$DISPLAY_COUNT" ] && DISPLAY_COUNT="$BUILD_COUNT"

    CROSS_VERSION=false
    TOTAL_OPTIONS=0
    CURRENT_TRACK_END=0

    if [ "$BUILD_COUNT" -gt 0 ]; then
        echo ""
        echo -e "\033[1;35mAvailable releases for $BANANA_CURRENT_LINE ($BANANA_CURRENT_TYPE):\033[0m"
        for i in $(seq 0 $((DISPLAY_COUNT - 1))); do
            tag=$(echo "$BUILDS" | jq -r ".[$i].tag")
            iwrt_ver=$(echo "$BUILDS" | jq -r ".[$i].immortalwrt_version")
            echo -e "\033[1;33m$((i+1)))\033[0m \033[1;36m$tag\033[0m - \033[1;32mFirmware: $iwrt_ver\033[0m - \033[1;35m$BANANA_CURRENT_TYPE\033[0m"
            TOTAL_OPTIONS=$((TOTAL_OPTIONS + 1))
        done
        CURRENT_TRACK_END=$TOTAL_OPTIONS
    else
        echo ""
        log_warning "No builds available for $BANANA_CURRENT_LINE ($BANANA_CURRENT_TYPE)."
    fi

    # Show other tracks for the same version line
    OTHER_TRACKS=$(echo "$INDEX_JSON" | jq -r ".versions[\"$BANANA_CURRENT_LINE\"].tracks | keys[] | select(. != \"$BANANA_CURRENT_TYPE\")")
    OTHER_TRACK_OPTIONS=""
    if [ -n "$OTHER_TRACKS" ]; then
        echo ""
        echo -e "\033[1;35mOther tracks for $BANANA_CURRENT_LINE:\033[0m"
        for track in $OTHER_TRACKS; do
            TRACK_BUILDS=$(echo "$INDEX_JSON" | jq -r ".versions[\"$BANANA_CURRENT_LINE\"].tracks[\"$track\"].builds // []")
            TRACK_COUNT=$(echo "$TRACK_BUILDS" | jq 'length')
            TRACK_DISPLAY=2
            [ "$TRACK_COUNT" -lt "$TRACK_DISPLAY" ] && TRACK_DISPLAY="$TRACK_COUNT"
            for i in $(seq 0 $((TRACK_DISPLAY - 1))); do
                tag=$(echo "$TRACK_BUILDS" | jq -r ".[$i].tag")
                iwrt_ver=$(echo "$TRACK_BUILDS" | jq -r ".[$i].immortalwrt_version")
                TOTAL_OPTIONS=$((TOTAL_OPTIONS + 1))
                OTHER_TRACK_OPTIONS="${OTHER_TRACK_OPTIONS}${TOTAL_OPTIONS}:${BANANA_CURRENT_LINE}:${track}:${i}
"
                echo -e "\033[1;33m${TOTAL_OPTIONS})\033[0m \033[1;36m$tag\033[0m - \033[1;32mFirmware: $iwrt_ver\033[0m - \033[1;35m$track\033[0m"
            done
        done
    fi

    # Show cross-version upgrade options
    OTHER_VERSIONS=$(echo "$INDEX_JSON" | jq -r ".versions | to_entries[] | select(.key != \"$BANANA_CURRENT_LINE\" and .value.status == \"active\") | .key")

    CROSS_OPTIONS=""
    if [ -n "$OTHER_VERSIONS" ]; then
        echo ""
        echo -e "\033[1;35mCross-version upgrades available:\033[0m"
        for ver in $OTHER_VERSIONS; do
            tracks=$(echo "$INDEX_JSON" | jq -r ".versions[\"$ver\"].tracks | keys[]")
            for track in $tracks; do
                latest_tag=$(echo "$INDEX_JSON" | jq -r ".versions[\"$ver\"].tracks[\"$track\"].latest_build")
                iwrt_ver=$(echo "$INDEX_JSON" | jq -r ".versions[\"$ver\"].tracks[\"$track\"].immortalwrt_version")
                TOTAL_OPTIONS=$((TOTAL_OPTIONS + 1))
                CROSS_OPTIONS="${CROSS_OPTIONS}${TOTAL_OPTIONS}:${ver}:${track}
"
                echo -e "\033[1;33m${TOTAL_OPTIONS})\033[0m \033[1;36m$latest_tag\033[0m - \033[1;32mFirmware: $iwrt_ver\033[0m - \033[1;35m$ver $track\033[0m \033[1;31m[CROSS-VERSION]\033[0m"
            done
        done
    fi

    if [ "$TOTAL_OPTIONS" -eq 0 ]; then
        log_error "No releases available."
        exit 1
    fi

    echo ""
    echo -e "\033[1;35mSelect the release number to install (default 1):\033[0m"
    read -r selection
    [ -z "$selection" ] && selection=1

    # Determine selection type
    SELECTED_OTHER_TRACK=$(echo "$OTHER_TRACK_OPTIONS" | grep "^${selection}:")
    SELECTED_CROSS=$(echo "$CROSS_OPTIONS" | grep "^${selection}:")

    if [ -n "$SELECTED_OTHER_TRACK" ]; then
        # Other track of same version selected
        OT_LINE=$(echo "$SELECTED_OTHER_TRACK" | cut -d: -f2)
        OT_TRACK=$(echo "$SELECTED_OTHER_TRACK" | cut -d: -f3)
        OT_IDX=$(echo "$SELECTED_OTHER_TRACK" | cut -d: -f4)
        BUILDS=$(echo "$INDEX_JSON" | jq -r ".versions[\"$OT_LINE\"].tracks[\"$OT_TRACK\"].builds // []")
        index=$OT_IDX
    elif [ -n "$SELECTED_CROSS" ]; then
        # Cross-version upgrade selected
        CROSS_LINE=$(echo "$SELECTED_CROSS" | cut -d: -f2)
        CROSS_TRACK=$(echo "$SELECTED_CROSS" | cut -d: -f3)

        if [ -z "$CROSS_LINE" ]; then
            log_error "Invalid selection."
            exit 1
        fi

        echo ""
        echo -e "\033[1;33m============================================================\033[0m"
        echo -e "\033[1;33m  CROSS-VERSION UPGRADE: $BANANA_CURRENT_LINE -> $CROSS_LINE\033[0m"
        echo -e "\033[1;33m============================================================\033[0m"
        echo ""
        echo -e "\033[1;35mDo you want to preserve configuration? (y/n, default y):\033[0m"
        read -r keep_config
        if [ "$keep_config" = "n" ] || [ "$keep_config" = "N" ]; then
            RESET=1
            log_warning "Configuration will be erased (factory reset)."
        else
            log_info "Configuration will be preserved."
        fi

        CROSS_VERSION=true
        BUILDS=$(echo "$INDEX_JSON" | jq -r ".versions[\"$CROSS_LINE\"].tracks[\"$CROSS_TRACK\"].builds // []")
        index=0
    elif [ "$selection" -le "$CURRENT_TRACK_END" ] 2>/dev/null; then
        index=$((selection - 1))
    else
        log_error "Invalid selection."
        exit 1
    fi

    # Get selected build info
    SELECTED_TAG=$(echo "$BUILDS" | jq -r ".[$index].tag")
    SELECTED_URL=$(echo "$BUILDS" | jq -r ".[$index].url")

    if [ -z "$SELECTED_TAG" ] || [ "$SELECTED_TAG" = "null" ]; then
        log_error "Invalid release selected."
        exit 1
    fi

    log_info "Selected release: $SELECTED_TAG"

    # Download firmware-info.json for the build
    BUILD_INFO=$(curl -sf "${SELECTED_URL}firmware-info.json")
    if [ -z "$BUILD_INFO" ]; then
        log_error "Failed to download build info from ${SELECTED_URL}"
        exit 1
    fi

    FIRMWARE_VERSION=$(echo "$BUILD_INFO" | jq -r '.immortalwrt_version')
    log_info "Firmware Version: $FIRMWARE_VERSION"

    # Download firmware files — forks may omit the version from basenames,
    # so trust the names advertised by firmware-info.json instead of rebuilding them.
    EMMC_PRELOADER=""
    EMMC_BL31_UBOOT=""
    EMMC_INITRAMFS=""
    SYSUPGRADE_IMG=""

    for asset_pattern in "emmc-preloader" "emmc-bl31-uboot" "initramfs-recovery" "squashfs-sysupgrade"; do
        filename=$(echo "$BUILD_INFO" | jq -r ".files | keys[] | select(contains(\"$asset_pattern\"))")

        if [ -z "$filename" ] || [ "$filename" = "null" ]; then
            log_error "File matching '$asset_pattern' not found in build info."
            exit 1
        fi

        download_url="${SELECTED_URL}${filename}"
        prefix="\033[1;36mDownloading $filename...\033[0m"

        if [ "$DRY_RUN" -eq 1 ]; then
            printf "%b\n" "$prefix"
            log_info "DRY-RUN: Simulated download of $filename from $download_url"
            echo ""
        else
            printf "%b " "$prefix"
            ( curl -sf -L -o "/tmp/$filename" "$download_url" ) &
            curl_pid=$!
            spinner_with_prefix $curl_pid "$prefix"
            echo ""
            if ! wait $curl_pid; then
                log_error "Error downloading $filename."
                exit 1
            fi
            log_success "$filename downloaded successfully."
        fi

        case "$asset_pattern" in
            emmc-preloader)      EMMC_PRELOADER="/tmp/$filename" ;;
            emmc-bl31-uboot)     EMMC_BL31_UBOOT="/tmp/$filename" ;;
            initramfs-recovery)  EMMC_INITRAMFS="/tmp/$filename" ;;
            squashfs-sysupgrade) SYSUPGRADE_IMG="/tmp/$filename" ;;
        esac
    done

elif [ "$MODE" = "ota" ]; then
    echo ""
    echo -e "\033[1;35mOTA Mode:\033[0m Enter the Firmware Version of the files in /tmp (e.g., 24.10.0 or 24.10.0-rc4):"
    read -r FIRMWARE_VERSION
    [ -z "$FIRMWARE_VERSION" ] && { log_error "Firmware Version not specified. Cannot continue."; exit 1; }

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

if [ "$MODE" = "ota" ]; then
    EMMC_PRELOADER="/tmp/immortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-emmc-preloader.bin"
    EMMC_BL31_UBOOT="/tmp/immortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-emmc-bl31-uboot.fip"
    EMMC_INITRAMFS="/tmp/immortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-initramfs-recovery.itb"
    SYSUPGRADE_IMG="/tmp/immortalwrt-${FIRMWARE_VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-squashfs-sysupgrade.itb"
fi

echo ""

if [ "$MODE" = "ota" ]; then
    echo -e "\033[1;35mEnsure the following files are present in \033[1;31m/tmp\033[0;35m:\033[0m"
else
    echo -e "\033[1;35mThe following files have been downloaded to \033[1;31m/tmp\033[0;35m:\033[0m"
fi

for f in "$EMMC_PRELOADER" "$EMMC_BL31_UBOOT" "$EMMC_INITRAMFS" "$SYSUPGRADE_IMG"; do
    echo -e " - \033[1;36m$(basename "$f")\033[0m"
done
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
