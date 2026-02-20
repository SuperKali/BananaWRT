#!/bin/bash
#
# validation.sh - Input validation functions for BananaWRT
#
# This library provides:
# - Command existence checking
# - File/directory validation
# - Release type validation
# - Version format validation
#
# Usage:
#   source "/path/to/lib/common.sh"  # Required for exit codes
#   source "/path/to/lib/validation.sh"
#
#   require_commands curl jq || exit $EXIT_MISSING_DEPS
#   validate_release_type "$type" || exit $EXIT_INVALID_ARGS
#

# Prevent multiple sourcing
[[ -n "${_BANANAWRT_VALIDATION_LOADED:-}" ]] && return 0
_BANANAWRT_VALIDATION_LOADED=1

# Ensure common.sh is loaded
if [[ -z "${_BANANAWRT_COMMON_LOADED:-}" ]]; then
    _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${_script_dir}/common.sh"
fi

# Check if all specified commands exist
# Usage: require_commands cmd1 cmd2 cmd3 ...
# Returns: 0 if all commands exist, 1 otherwise
require_commands() {
    local missing=()

    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        log_error "Please install them and try again."
        return 1
    fi

    return 0
}

# Check if a file exists
# Usage: require_file path [error_message]
# Returns: 0 if file exists, 1 otherwise
require_file() {
    local path="$1"
    local custom_message="${2:-}"

    if [[ ! -f "$path" ]]; then
        if [[ -n "$custom_message" ]]; then
            log_error "$custom_message"
        else
            log_error "Required file not found: $path"
        fi
        return 1
    fi

    return 0
}

# Check if a directory exists
# Usage: require_directory path [error_message]
# Returns: 0 if directory exists, 1 otherwise
require_directory() {
    local path="$1"
    local custom_message="${2:-}"

    if [[ ! -d "$path" ]]; then
        if [[ -n "$custom_message" ]]; then
            log_error "$custom_message"
        else
            log_error "Required directory not found: $path"
        fi
        return 1
    fi

    return 0
}

# Check if a file is readable
# Usage: require_readable path
# Returns: 0 if file is readable, 1 otherwise
require_readable() {
    local path="$1"

    if [[ ! -r "$path" ]]; then
        log_error "File is not readable: $path"
        return 1
    fi

    return 0
}

# Check if a file is executable
# Usage: require_executable path
# Returns: 0 if file is executable, 1 otherwise
require_executable() {
    local path="$1"

    if [[ ! -x "$path" ]]; then
        log_error "File is not executable: $path"
        return 1
    fi

    return 0
}

# Validate release type (stable or nightly)
# Usage: validate_release_type type
# Returns: 0 if valid, 1 otherwise
validate_release_type() {
    local type="$1"

    if [[ -z "$type" ]]; then
        log_error "Release type not specified"
        return 1
    fi

    # Load config if available
    local valid_types="stable nightly"
    if [[ -f "${BANANAWRT_ROOT}/config/bananawrt.conf" ]]; then
        source "${BANANAWRT_ROOT}/config/bananawrt.conf"
        valid_types="${RELEASE_TYPES:-$valid_types}"
    fi

    if [[ ! " $valid_types " =~ " $type " ]]; then
        log_error "Invalid release type: $type"
        log_error "Valid types: $valid_types"
        return 1
    fi

    return 0
}

# Validate version format (e.g., 24.10.0, 24.10.0-rc4, v1.2.3)
# Usage: validate_version version
# Returns: 0 if valid, 1 otherwise
validate_version() {
    local version="$1"

    if [[ -z "$version" ]]; then
        log_error "Version not specified"
        return 1
    fi

    # Match version patterns:
    # - 24.10.0
    # - 24.10.0-rc1
    # - v1.2.3
    # - 2024.01.15
    if [[ "$version" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
        return 0
    fi

    log_error "Invalid version format: $version"
    log_error "Expected format: X.Y.Z or X.Y.Z-suffix (e.g., 24.10.0 or 24.10.0-rc1)"
    return 1
}

# Validate firmware version and ensure required files exist
# Usage: validate_firmware_files version [temp_dir]
# Returns: 0 if all files exist, 1 otherwise
validate_firmware_files() {
    local version="$1"
    local temp_dir="${2:-/tmp}"

    # Load config for file patterns
    source "${BANANAWRT_ROOT}/config/bananawrt.conf"

    local FIRMWARE_VERSION="$version"
    local target="${TARGET_SUBTARGET}"
    local vendor="${TARGET_VENDOR}"
    local device="${TARGET_DEVICE}"

    # Build expected file paths
    local prefix="immortalwrt-${FIRMWARE_VERSION}-${target}-${vendor}_${device}"

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
        log_error "Missing firmware files:"
        for f in "${missing[@]}"; do
            log_error "  - $f"
        done
        return 1
    fi

    return 0
}

# Validate environment for CI/CD operations
# Usage: validate_ci_environment
# Returns: 0 if running in CI with required variables, 1 otherwise
validate_ci_environment() {
    if [[ -z "${GITHUB_WORKSPACE:-}" ]]; then
        log_error "GITHUB_WORKSPACE not set - this script must run in GitHub Actions"
        return 1
    fi

    if [[ ! -d "$GITHUB_WORKSPACE" ]]; then
        log_error "GITHUB_WORKSPACE directory does not exist: $GITHUB_WORKSPACE"
        return 1
    fi

    return 0
}

# Validate JSON from a file
# Usage: validate_json file_path
# Returns: 0 if valid JSON, 1 otherwise
validate_json() {
    local file="$1"

    if ! command -v jq &>/dev/null; then
        log_error "jq is required for JSON validation"
        return 1
    fi

    if [[ ! -f "$file" ]]; then
        log_error "JSON file not found: $file"
        return 1
    fi

    if ! jq empty "$file" 2>/dev/null; then
        log_error "Invalid JSON in file: $file"
        return 1
    fi

    return 0
}

# Validate URL format
# Usage: validate_url url
# Returns: 0 if valid URL format, 1 otherwise
validate_url() {
    local url="$1"

    if [[ -z "$url" ]]; then
        log_error "URL not specified"
        return 1
    fi

    # Basic URL validation regex
    if [[ "$url" =~ ^https?://[a-zA-Z0-9.-]+(/[^\s]*)?$ ]]; then
        return 0
    fi

    log_error "Invalid URL format: $url"
    return 1
}

# Validate device block partition
# Usage: validate_partition device
# Returns: 0 if partition exists, 1 otherwise
validate_partition() {
    local partition="$1"

    if [[ ! -b "$partition" ]]; then
        log_error "Block device not found: $partition"
        return 1
    fi

    return 0
}

# Validate that we're running on supported hardware
# Usage: validate_target_hardware
# Returns: 0 if running on Banana Pi R3 Mini, 1 otherwise
validate_target_hardware() {
    # Check for OpenWrt release file
    if [[ ! -f "/etc/openwrt_release" ]]; then
        log_error "Not running on OpenWrt"
        return 1
    fi

    # Source the release file to get device info
    source "/etc/openwrt_release"

    # Check for Banana Pi R3 Mini
    local expected_board="Banana Pi BPI-R3 Mini"

    # Try to get board name from different sources
    local board_name=""
    if [[ -f "/tmp/sysinfo/board_name" ]]; then
        board_name=$(cat /tmp/sysinfo/board_name)
    elif [[ -n "${DISTRIB_TARGET:-}" ]]; then
        board_name="$DISTRIB_TARGET"
    fi

    if [[ "$board_name" != *"bpi-r3-mini"* ]] && [[ "$board_name" != *"bananapi"* ]]; then
        log_warning "Running on non-target hardware: $board_name"
        log_warning "This script is designed for Banana Pi R3 Mini"
    fi

    return 0
}

# Export functions
export -f require_commands require_file require_directory require_readable require_executable
export -f validate_release_type validate_version validate_firmware_files
export -f validate_ci_environment validate_json validate_url validate_partition
export -f validate_target_hardware
