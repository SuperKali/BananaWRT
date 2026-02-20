#!/bin/bash
#
# remove-stock-packages.sh - Remove stock packages from upstream repository
#
# This script removes packages that are replaced by custom versions
# in the BananaWRT distribution.
#
# Usage: remove-stock-packages.sh [IMMORTALWRT_DIR]
#
# Arguments:
#   IMMORTALWRT_DIR  Path to ImmortalWRT directory - default: current directory
#
# Environment variables:
#   STOCK_PACKAGES_TO_REMOVE  Space-separated list of packages to remove
#   STOCK_PACKAGES_GLOBS      Space-separated list of glob patterns
#
# Copyright (c) 2024-2025 SuperKali <hello@superkali.me>
# Licensed under the MIT License.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BANANAWRT_ROOT="${BANANAWRT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# Source libraries
source "${BANANAWRT_ROOT}/lib/common.sh"
source "${BANANAWRT_ROOT}/lib/logging.sh"

# Load configuration
source "${BANANAWRT_ROOT}/config/bananawrt.conf"

# Arguments
IMMORTALWRT_DIR="${1:-${PWD}}"

# Show help
show_help() {
    cat << EOF
Usage: $(get_script_name) [IMMORTALWRT_DIR]

Remove stock packages from upstream repository that are replaced by custom versions.

Arguments:
  IMMORTALWRT_DIR  Path to ImmortalWRT directory - default: current directory

Options:
  -h, --help       Show this help message

Environment:
  STOCK_PACKAGES_TO_REMOVE  Packages to remove (default: $STOCK_PACKAGES_TO_REMOVE)
  STOCK_PACKAGES_GLOBS      Glob patterns to match (default: set in config)
EOF
    exit 0
}

# Check for help flag
case "${1:-}" in
    -h|--help)
        show_help
        ;;
esac

# Packages to remove (paths relative to IMMORTALWRT_DIR)
declare -A PACKAGE_PATHS=(
    ["lpac"]="package/feeds/packages/lpac"
    ["luci-app-modemband"]="package/feeds/luci/luci-app-modemband"
    ["modemband"]="package/feeds/packages/modemband"
    ["luci-app-3ginfo-lite"]="package/feeds/luci/luci-app-3ginfo-lite"
    ["luci-proto-quectel"]="feeds/luci/protocols/luci-proto-quectel"
    ["quectel-cm"]="feeds/packages/net/quectel-cm"
)

# Remove a single package directory
# Usage: remove_package package_name
remove_package() {
    local package="$1"
    local path="${PACKAGE_PATHS[$package]:-$package}"

    # Prepend IMMORTALWRT_DIR if path is relative
    if [[ "$path" != /* ]]; then
        path="${IMMORTALWRT_DIR}/${path}"
    fi

    if [[ -e "$path" ]]; then
        log_info "Removing: $package ($path)"
        if rm -rf "$path"; then
            log_debug "Removed: $path"
            return 0
        else
            log_warning "Failed to remove: $path"
            return 1
        fi
    else
        log_debug "Not found: $path"
        return 0
    fi
}

# Remove packages matching glob patterns
# Usage: remove_packages_by_glob pattern
remove_packages_by_glob() {
    local pattern="$1"
    local full_pattern="${IMMORTALWRT_DIR}/${pattern}"

    # Use shopt for glob expansion
    shopt -s nullglob
    local matches=($full_pattern)
    shopt -u nullglob

    if [[ ${#matches[@]} -eq 0 ]]; then
        log_debug "No files matching: $pattern"
        return 0
    fi

    log_info "Removing files matching: $pattern"
    for file in "${matches[@]}"; do
        log_debug "  - $(basename "$file")"
        rm -rf "$file"
    done
}

# Main function
main() {
    log_section "Removing stock packages"

    # Validate ImmortalWRT directory
    if [[ ! -d "$IMMORTALWRT_DIR" ]]; then
        log_error "ImmortalWRT directory does not exist: $IMMORTALWRT_DIR"
        exit $EXIT_NOT_FOUND
    fi

    local removed_count=0
    local failed_count=0

    # Remove specific packages
    for package in $STOCK_PACKAGES_TO_REMOVE; do
        if remove_package "$package"; then
            ((removed_count++))
        else
            ((failed_count++))
        fi
    done

    # Remove packages by glob patterns
    for pattern in $STOCK_PACKAGES_GLOBS; do
        remove_packages_by_glob "$pattern"
    done

    # Summary
    if [[ "$failed_count" -eq 0 ]]; then
        log_success "Removed $removed_count stock packages"
    else
        log_warning "Removed $removed_count packages with $failed_count failures"
    fi
}

main "$@"
