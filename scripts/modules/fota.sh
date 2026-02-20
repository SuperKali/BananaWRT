#!/bin/bash
#
# fota.sh - Full OTA update module for BananaWRT
#
# This module provides functions for downloading and installing
# firmware updates from GitHub releases.
#
# Usage:
#   source "/path/to/lib/common.sh"
#   source "/path/to/lib/network.sh"
#   source "/path/to/modules/fota.sh"
#
#   fota_update --dry-run
#

# Prevent multiple sourcing
[[ -n "${_BANANAWRT_FOTA_LOADED:-}" ]] && return 0
_BANANAWRT_FOTA_LOADED=1

# Ensure dependencies are loaded
if [[ -z "${_BANANAWRT_NETWORK_LOADED:-}" ]]; then
    _modules_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${_modules_dir}/../lib/network.sh"
fi

# Load configuration
if [[ -f "${BANANAWRT_ROOT}/config/bananawrt.conf" ]]; then
    source "${BANANAWRT_ROOT}/config/bananawrt.conf"
fi

# Fetch and display available releases
# Usage: fota_fetch_releases
# Returns: JSON releases on stdout
fota_fetch_releases() {
    require_commands curl jq || return $EXIT_MISSING_DEPS

    local releases_json

    releases_json=$(fetch_github_releases "${BANANAWRT_REPO}")

    if [[ -z "$releases_json" ]] || [[ "$releases_json" == "null" ]]; then
        log_error "Failed to fetch releases from GitHub"
        return $EXIT_NETWORK
    fi

    echo "$releases_json"
    return 0
}

# Display available releases and prompt for selection
# Usage: fota_select_release releases_json
# Returns: Selected index and tag name (sets global variables)
fota_select_release() {
    local json="$1"
    local selection index tag

    echo ""
    echo -e "${BOLD}${MAGENTA}Last 4 available releases:${RESET}"

    for i in 0 1 2 3; do
        tag=$(echo "$json" | jq -r ".[$i].tag_name // empty")
        [[ -z "$tag" ]] && continue

        # Get firmware version from asset name
        local asset fw_version release_type
        asset=$(echo "$json" | jq -r ".[$i].assets[] | select(.name | endswith(\"${ASSET_PRELOADER_SUFFIX}\")) | .name" | head -n 1)
        fw_version=$(echo "$asset" | sed -n 's/^immortalwrt-\(.*\)-mediatek.*$/\1/p')
        [[ -z "$fw_version" ]] && fw_version="N/A"

        # Determine release type from body
        release_type=$(get_release_type "$(echo "$json" | jq ".[$i]")")

        echo -e "${BOLD}${YELLOW}$((i+1)))${RESET} ${BOLD}${CYAN}${tag}${RESET} - ${BOLD}${GREEN}Firmware: ${fw_version}${RESET} - ${BOLD}${MAGENTA}${release_type}${RESET}"
    done

    echo ""
    echo -e "${BOLD}${MAGENTA}Select the release number to install (default 1):${RESET}"
    read -r selection

    [[ -z "$selection" ]] && selection=1
    index=$((selection - 1))

    tag=$(echo "$json" | jq -r ".[$index].tag_name // empty")
    if [[ -z "$tag" ]] || [[ "$tag" == "null" ]]; then
        log_error "Invalid release selected"
        return $EXIT_INVALID_ARGS
    fi

    # Return values via global variables
    FOTA_SELECTED_INDEX="$index"
    FOTA_SELECTED_TAG="$tag"

    log_info "Selected release: $tag"
    return 0
}

# Extract firmware version from release
# Usage: fota_get_firmware_version releases_json index
# Returns: Firmware version string
fota_get_firmware_version() {
    local json="$1"
    local index="$2"

    local asset
    asset=$(echo "$json" | jq -r ".[$index].assets[] | select(.name | endswith(\"${ASSET_PRELOADER_SUFFIX}\")) | .name" | head -n 1)

    if [[ -z "$asset" ]] || [[ "$asset" == "null" ]]; then
        log_error "Unable to determine firmware version from release"
        return $EXIT_FAILURE
    fi

    local version
    version=$(echo "$asset" | sed -n 's/^immortalwrt-\(.*\)-mediatek.*$/\1/p')

    if [[ -z "$version" ]]; then
        log_error "Could not parse firmware version from asset: $asset"
        return $EXIT_FAILURE
    fi

    echo "$version"
    return 0
}

# Download all firmware files for a release
# Usage: fota_download_firmware releases_json index version temp_dir [dry_run]
# Returns: 0 on success, non-zero on failure
fota_download_firmware() {
    local json="$1"
    local index="$2"
    local version="$3"
    local temp_dir="${4:-${FIRMWARE_TMP_DIR}}"
    local dry_run="${5:-false}"

    if [[ "$dry_run" == "true" ]]; then
        download_firmware_assets "$json" "$index" "$version" "$temp_dir" "true"
    else
        download_firmware_assets "$json" "$index" "$version" "$temp_dir" "false"
    fi
}

# Display required firmware files
# Usage: fota_show_required_files version [mode]
fota_show_required_files() {
    local version="$1"
    local mode="${2:-fota}"

    if [[ "$mode" == "ota" ]]; then
        echo -e "${BOLD}${MAGENTA}Ensure the following files are present in ${BOLD}${RED}/tmp${RESET}${BOLD}${MAGENTA}:${RESET}"
    else
        echo -e "${BOLD}${MAGENTA}The following files have been downloaded to ${BOLD}${RED}/tmp${RESET}${BOLD}${MAGENTA}:${RESET}"
    fi

    local prefix="immortalwrt-${version}-${TARGET_SUBTARGET}-${TARGET_VENDOR}_${TARGET_DEVICE}"

    echo -e " - ${BOLD}${CYAN}${prefix}-${ASSET_PRELOADER_SUFFIX}${RESET}"
    echo -e " - ${BOLD}${CYAN}${prefix}-${ASSET_BL31_UBOOT_SUFFIX}${RESET}"
    echo -e " - ${BOLD}${CYAN}${prefix}-${ASSET_INITRAMFS_SUFFIX}${RESET}"
    echo -e " - ${BOLD}${CYAN}${prefix}-${ASSET_SYSUPGRADE_SUFFIX}${RESET}"
}

# Get current firmware version
# Usage: fota_get_current_version
# Returns: Current firmware build date
fota_get_current_version() {
    if [[ -f "$RELEASE_INFO_FILE" ]]; then
        grep -o "BANANAWRT_BUILD_DATE='.*'" "$RELEASE_INFO_FILE" | cut -d "'" -f 2
    else
        echo "unknown"
    fi
}

# Perform full FOTA update
# Usage: fota_update [--dry-run] [--reset]
# This is the main entry point for FOTA updates
fota_update() {
    local dry_run=false
    local reset=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=true ;;
            --reset) reset=true ;;
        esac
        shift
    done

    # Check dependencies
    require_commands curl jq || return $EXIT_MISSING_DEPS

    # Show current version
    local current_version
    current_version=$(fota_get_current_version)
    [[ -n "$current_version" ]] && log_info "Current firmware version: $current_version"

    # Fetch releases
    local releases_json
    releases_json=$(fota_fetch_releases) || return $?

    # Select release
    fota_select_release "$releases_json" || return $?

    # Get firmware version
    local firmware_version
    firmware_version=$(fota_get_firmware_version "$releases_json" "$FOTA_SELECTED_INDEX") || return $?
    log_info "Detected Firmware Version: $firmware_version"

    # Download firmware files
    log_section "Downloading firmware files"
    fota_download_firmware "$releases_json" "$FOTA_SELECTED_INDEX" "$firmware_version" "/tmp" "$dry_run" || return $?

    # Show files
    echo ""
    fota_show_required_files "$firmware_version" "fota"

    # Set global variables for main script
    FOTA_FIRMWARE_VERSION="$firmware_version"
    FOTA_RELEASE_TAG="$FOTA_SELECTED_TAG"
    FOTA_RELEASES_JSON="$releases_json"

    return 0
}

# Export functions and variables
export -f fota_fetch_releases fota_select_release fota_get_firmware_version
export -f fota_download_firmware fota_show_required_files fota_get_current_version fota_update
