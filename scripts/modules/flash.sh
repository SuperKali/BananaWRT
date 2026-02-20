#!/bin/bash
#
# flash.sh - Flash partition operations for BananaWRT
#
# This module provides functions for flashing firmware to eMMC partitions.
#
# Usage:
#   source "/path/to/lib/common.sh"
#   source "/path/to/modules/flash.sh"
#
#   enable_boot0_write || exit $EXIT_FAILURE
#   flash_partition "/dev/mmcblk0boot0" "$preloader_file"
#

# Prevent multiple sourcing
[[ -n "${_BANANAWRT_FLASH_LOADED:-}" ]] && return 0
_BANANAWRT_FLASH_LOADED=1

# Load configuration
if [[ -f "${BANANAWRT_ROOT}/config/bananawrt.conf" ]]; then
    source "${BANANAWRT_ROOT}/config/bananawrt.conf"
fi

# Enable write access to boot0 partition
# Usage: enable_boot0_write
# Returns: 0 on success, 1 on failure
enable_boot0_write() {
    local boot0_sysfs="/sys/block/mmcblk0boot0/force_ro"

    log_info "Enabling write access to ${PARTITION_BOOT0}..."

    if [[ ! -f "$boot0_sysfs" ]]; then
        log_error "Boot0 sysfs file not found: $boot0_sysfs"
        return 1
    fi

    if echo 0 > "$boot0_sysfs" 2>/dev/null; then
        log_success "Write access enabled"
        return 0
    else
        log_error "Unable to enable write access to ${PARTITION_BOOT0}"
        return 1
    fi
}

# Flash an image to a partition
# Usage: flash_partition partition image_file [dry_run]
# Returns: 0 on success, 1 on failure
flash_partition() {
    local partition="$1"
    local image="$2"
    local dry_run="${3:-false}"

    if [[ "$dry_run" == "true" ]]; then
        log_info "DRY-RUN: Simulated erasing partition $partition"
        log_info "DRY-RUN: Simulated flashing $image to $partition"
        return 0
    fi

    # Validate inputs
    if [[ ! -b "$partition" ]]; then
        log_error "Partition not found: $partition"
        return 1
    fi

    if [[ ! -f "$image" ]]; then
        log_error "Image file not found: $image"
        return 1
    fi

    # Erase partition
    log_info "Erasing partition $partition..."
    if ! dd if=/dev/zero of="$partition" bs=1M count=4 2>/dev/null; then
        log_error "Error erasing partition $partition"
        return 1
    fi

    # Flash image
    log_info "Flashing $(basename "$image") to $partition..."
    if ! dd if="$image" of="$partition" bs=1M 2>/dev/null; then
        log_error "Error flashing $image to $partition"
        return 1
    fi

    log_success "Flashed successfully to $partition"
    return 0
}

# Flash all firmware partitions
# Usage: flash_all_partitions preloader bl31_uboot initramfs [dry_run]
# Returns: 0 on success, 1 on failure
flash_all_partitions() {
    local preloader="$1"
    local bl31_uboot="$2"
    local initramfs="$3"
    local dry_run="${4:-false}"

    log_section "Flashing firmware partitions"

    local failed=0

    # Flash preloader to boot0
    flash_partition "${PARTITION_BOOT0}" "$preloader" "$dry_run" || ((failed++))

    # Flash BL31/UBOOT to partition 3
    flash_partition "${PARTITION_BL31}" "$bl31_uboot" "$dry_run" || ((failed++))

    # Flash initramfs to partition 4
    flash_partition "${PARTITION_INITRAMFS}" "$initramfs" "$dry_run" || ((failed++))

    # Sync changes
    if [[ "$dry_run" == "true" ]]; then
        log_info "DRY-RUN: Simulated sync"
    else
        sync
    fi

    if [[ "$failed" -eq 0 ]]; then
        log_success "All partitions flashed successfully"
        return 0
    else
        log_error "Failed to flash $failed partition(s)"
        return 1
    fi
}

# Verify sysupgrade image
# Usage: verify_sysupgrade image_path
# Returns: 0 if valid, 1 if invalid
verify_sysupgrade() {
    local image="$1"
    local dry_run="${2:-false}"

    log_info "Verifying sysupgrade image..."

    if [[ "$dry_run" == "true" ]]; then
        log_info "DRY-RUN: Simulated sysupgrade verification"
        return 0
    fi

    if [[ ! -f "$image" ]]; then
        log_error "Sysupgrade image not found: $image"
        return 1
    fi

    local verify_output
    verify_output=$(sysupgrade -T "$image" 2>&1)

    if echo "$verify_output" | grep -q "Image checksum '.*' not valid"; then
        log_error "Sysupgrade image verification failed: checksum invalid"
        return 1
    fi

    log_success "Sysupgrade image verified"
    echo "$verify_output"
    return 0
}

# Check and update compat_version if needed
# Usage: check_and_update_compat_version required_version
# Returns: 0 on success, 1 on failure
check_and_update_compat_version() {
    local required_version="$1"
    local current_version

    current_version=$(uci get system.@system[0].compat_version 2>/dev/null || echo "0.0")

    if version_greater "$required_version" "$current_version"; then
        log_info "Updating compat_version from $current_version to $required_version..."
        uci set system.@system[0].compat_version="$required_version"
        uci commit system
        log_success "compat_version updated to $required_version"
    else
        log_info "Current compat_version ($current_version) is already compatible or greater"
    fi
}

# Perform sysupgrade
# Usage: perform_sysupgrade image_path [reset] [dry_run]
# Returns: 0 if started successfully (doesn't return on actual upgrade)
perform_sysupgrade() {
    local image="$1"
    local reset="${2:-false}"
    local dry_run="${3:-false}"

    local sysupgrade_cmd

    if [[ "$reset" == "true" ]]; then
        log_info "Starting sysupgrade without preserving configuration..."
        sysupgrade_cmd="sysupgrade -n"
    else
        log_info "Starting sysupgrade with configuration preserved..."
        sysupgrade_cmd="sysupgrade -k"
    fi

    log_info "Executing: $sysupgrade_cmd $(basename "$image")"
    sleep 2

    if [[ "$dry_run" == "true" ]]; then
        log_info "DRY-RUN: Simulated sysupgrade execution"
        return 0
    fi

    local output
    output=$($sysupgrade_cmd "$image" 2>&1)

    if echo "$output" | grep -iq "closing"; then
        log_success "Sysupgrade process started successfully"
        log_success "The device is rebooting..."
    else
        log_error "Sysupgrade failed or unexpected behavior:"
        echo "$output"
        return 1
    fi
}

# Export functions
export -f enable_boot0_write flash_partition flash_all_partitions
export -f verify_sysupgrade check_and_update_compat_version perform_sysupgrade
