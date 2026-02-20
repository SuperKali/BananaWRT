#!/bin/bash
#
# ota.sh - Local OTA update module for BananaWRT
#
# This module provides functions for installing firmware updates
# from local files in /tmp.
#
# Usage:
#   source "/path/to/lib/common.sh"
#   source "/path/to/modules/ota.sh"
#
#   ota_update
#

# Prevent multiple sourcing
[[ -n "${_BANANAWRT_OTA_LOADED:-}" ]] && return 0
_BANANAWRT_OTA_LOADED=1

# Load configuration
if [[ -f "${BANANAWRT_ROOT}/config/bananawrt.conf" ]]; then
    source "${BANANAWRT_ROOT}/config/bananawrt.conf"
fi

# Prompt user for firmware version
# Usage: ota_prompt_version
# Returns: Firmware version via OTA_FIRMWARE_VERSION global
ota_prompt_version() {
    local version

    echo ""
    echo -e "${BOLD}${MAGENTA}OTA Mode:${RESET} Enter the Firmware Version of the files in /tmp (e.g., 24.10.0 or 24.10.0-rc4):"
    read -r version

    if [[ -z "$version" ]]; then
        log_error "Firmware Version not specified"
        return $EXIT_INVALID_ARGS
    fi

    if ! validate_version "$version"; then
        log_error "Invalid version format: $version"
        return $EXIT_INVALID_ARGS
    fi

    OTA_FIRMWARE_VERSION="$version"
    return 0
}

# Verify OTA files exist in /tmp
# Usage: ota_verify_files version
# Returns: 0 if all files exist, 1 otherwise
ota_verify_files() {
    local version="$1"
    local temp_dir="${FIRMWARE_TMP_DIR}"

    log_info "Checking required files..."

    local prefix="immortalwrt-${version}-${TARGET_SUBTARGET}-${TARGET_VENDOR}_${TARGET_DEVICE}"

    local files=(
        "${temp_dir}/${prefix}-${ASSET_PRELOADER_SUFFIX}"
        "${temp_dir}/${prefix}-${ASSET_BL31_UBOOT_SUFFIX}"
        "${temp_dir}/${prefix}-${ASSET_INITRAMFS_SUFFIX}"
        "${temp_dir}/${prefix}-${ASSET_SYSUPGRADE_SUFFIX}"
    )

    local missing=()
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing+=("$(basename "$file")")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Required files not found:"
        for f in "${missing[@]}"; do
            log_error "  - $f"
        done
        return $EXIT_NOT_FOUND
    fi

    log_success "All required files are present"
    return 0
}

# Perform OTA update from local files
# Usage: ota_update [--dry-run]
# This is the main entry point for OTA updates
ota_update() {
    local dry_run=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=true ;;
        esac
        shift
    done

    # Prompt for version
    ota_prompt_version || return $?

    local version="$OTA_FIRMWARE_VERSION"

    # Show required files
    echo ""
    fota_show_required_files "$version" "ota"
    echo ""

    # Wait for user confirmation
    echo -e "${BOLD}${MAGENTA}Press Enter to continue or CTRL+C to abort...${RESET}"
    read -r

    # Verify files exist
    ota_verify_files "$version" || return $?

    # Set global for main script
    OTA_FIRMWARE_VERSION="$version"

    return 0
}

# Export functions
export -f ota_prompt_version ota_verify_files ota_update
