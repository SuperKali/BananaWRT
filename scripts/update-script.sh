#!/bin/bash
#
# update-script.sh - BananaWRT System Updater
#
# This is the main entry point for firmware and package updates on BananaWRT.
#
# Usage: update-script.sh [fota|ota|packages] [--dry-run] [--reset]
#
# Modes:
#   fota     - Full OTA update from GitHub releases
#   ota      - Update from local files in /tmp
#   packages - Update only custom packages from repository
#
# Options:
#   --dry-run  Simulate operations without making changes
#   --reset    Reset configuration during sysupgrade (fota/ota modes only)
#   --help     Show this help message
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BANANAWRT_ROOT="${BANANAWRT_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# Source libraries
source "${BANANAWRT_ROOT}/lib/common.sh"
source "${BANANAWRT_ROOT}/lib/logging.sh"
source "${BANANAWRT_ROOT}/lib/validation.sh"
source "${BANANAWRT_ROOT}/lib/network.sh"

# Source modules
source "${SCRIPT_DIR}/modules/flash.sh"
source "${SCRIPT_DIR}/modules/fota.sh"
source "${SCRIPT_DIR}/modules/ota.sh"
source "${SCRIPT_DIR}/modules/packages.sh"

# Load configuration
source "${BANANAWRT_ROOT}/config/bananawrt.conf"

# Global variables
MODE=""
DRY_RUN=false
RESET=false

# Show usage information
usage() {
    cat << EOF
Usage: $(get_script_name) [fota|ota|packages] [--dry-run] [--reset]

BananaWRT System Updater - Update firmware and packages

Modes:
  fota      Full OTA update from GitHub releases
            Downloads and installs complete firmware from GitHub
  ota       Update from local files
            Use firmware files already present in /tmp
  packages  Update custom packages only
            Updates packages from the BananaWRT repository

Options:
  --dry-run   Simulate operations without making changes
  --reset     Reset configuration during sysupgrade (not available for packages)
  -h, --help  Show this help message

Examples:
  $(get_script_name) fota                    # Full update from GitHub
  $(get_script_name) fota --reset            # Full update, reset config
  $(get_script_name) ota                     # Update from /tmp files
  $(get_script_name) packages                # Update packages only
  $(get_script_name) packages --dry-run      # Check for package updates

EOF
    exit $EXIT_INVALID_ARGS
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            fota|ota|packages)
                if [[ -n "$MODE" ]]; then
                    log_error "Mode already specified: $MODE"
                    usage
                fi
                MODE="$1"
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --reset)
                RESET=true
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
        shift
    done

    if [[ -z "$MODE" ]]; then
        log_error "No mode specified"
        usage
    fi
}

# Build firmware file paths
# Sets global variables for firmware files
build_firmware_paths() {
    local version="$1"
    local temp_dir="${FIRMWARE_TMP_DIR}"
    local prefix="immortalwrt-${version}-${TARGET_SUBTARGET}-${TARGET_VENDOR}_${TARGET_DEVICE}"

    EMMC_PRELOADER="${temp_dir}/${prefix}-${ASSET_PRELOADER_SUFFIX}"
    EMMC_BL31_UBOOT="${temp_dir}/${prefix}-${ASSET_BL31_UBOOT_SUFFIX}"
    EMMC_INITRAMFS="${temp_dir}/${prefix}-${ASSET_INITRAMFS_SUFFIX}"
    SYSUPGRADE_IMG="${temp_dir}/${prefix}-${ASSET_SYSUPGRADE_SUFFIX}"
}

# Run firmware update (common for fota and ota modes)
run_firmware_update() {
    local version="$1"

    # Build file paths
    build_firmware_paths "$version"

    # Show files and wait for confirmation
    echo ""
    fota_show_required_files "$version" "ota"
    echo ""
    echo -e "${BOLD}${MAGENTA}Press Enter to continue or CTRL+C to abort...${RESET}"
    read -r

    # Verify files exist
    log_info "Checking required files..."
    for file in "$EMMC_PRELOADER" "$EMMC_BL31_UBOOT" "$EMMC_INITRAMFS" "$SYSUPGRADE_IMG"; do
        if [[ ! -f "$file" ]]; then
            log_error "Required file not found: $file"
            exit $EXIT_NOT_FOUND
        fi
    done
    log_success "All required files are present"

    # Enable write access to boot0
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY-RUN: Simulated enabling write access to ${PARTITION_BOOT0}"
    else
        enable_boot0_write || exit $EXIT_FAILURE
    fi

    # Flash partitions
    flash_all_partitions "$EMMC_PRELOADER" "$EMMC_BL31_UBOOT" "$EMMC_INITRAMFS" "$DRY_RUN" || exit $EXIT_FAILURE

    log_success "Flashing completed successfully"

    # Verify and handle sysupgrade
    log_info "Verifying sysupgrade with file $(basename "$SYSUPGRADE_IMG")..."

    local verify_output
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY-RUN: Simulated sysupgrade verification"
        verify_output=""
    else
        verify_output=$(verify_sysupgrade "$SYSUPGRADE_IMG") || exit $EXIT_FAILURE
    fi

    # Check for compat_version update
    if echo "$verify_output" | grep -q "The device is supported, but the config is incompatible"; then
        local required_version
        required_version=$(echo "$verify_output" | grep "incompatible" | awk -F'->' '{print $2}' | awk -F')' '{print $1}' | tr -d '[:space:]')

        if [[ -n "$required_version" ]]; then
            log_info "Required compat_version detected: $required_version"
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "DRY-RUN: Would update compat_version to $required_version"
            else
                check_and_update_compat_version "$required_version" || exit $EXIT_FAILURE
            fi
        else
            log_error "Unable to detect required compat_version"
            exit $EXIT_FAILURE
        fi
    fi

    # Perform sysupgrade
    perform_sysupgrade "$SYSUPGRADE_IMG" "$RESET" "$DRY_RUN" || exit $EXIT_FAILURE
}

# Main function
main() {
    # Parse arguments
    parse_args "$@"

    # Print banner
    print_banner

    case "$MODE" in
        fota)
            # Run FOTA update
            fota_update --dry-run=$DRY_RUN || exit $EXIT_FAILURE

            # Get firmware version from module
            FIRMWARE_VERSION="$FOTA_FIRMWARE_VERSION"

            # Run firmware flashing and sysupgrade
            run_firmware_update "$FIRMWARE_VERSION"
            ;;

        ota)
            # Run OTA update
            ota_update --dry-run=$DRY_RUN || exit $EXIT_FAILURE

            # Get firmware version from module
            FIRMWARE_VERSION="$OTA_FIRMWARE_VERSION"

            # Run firmware flashing and sysupgrade
            run_firmware_update "$FIRMWARE_VERSION"
            ;;

        packages)
            # Run package update
            packages_update --dry-run=$DRY_RUN
            exit $?
            ;;

        *)
            log_error "Unknown mode: $MODE"
            usage
            ;;
    esac
}

main "$@"
