#!/bin/bash
#
# custom-repository.sh - Add custom package repository to ImmortalWRT feeds
#
# Usage: custom-repository.sh [IMMORTALWRT_DIR]
#
# Arguments:
#   IMMORTALWRT_DIR  Path to ImmortalWRT directory - default: current directory
#
# Environment variables:
#   CUSTOM_PACKAGES_FEED  Custom feed URL (default: https://github.com/SuperKali/openwrt-packages)
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

Add custom package repository to ImmortalWRT feeds configuration.

Arguments:
  IMMORTALWRT_DIR  Path to ImmortalWRT directory - default: current directory

Options:
  -h, --help       Show this help message

Environment:
  CUSTOM_PACKAGES_FEED  Custom feed URL (default: $CUSTOM_PACKAGES_FEED)
EOF
    exit 0
}

# Check for help flag
case "${1:-}" in
    -h|--help)
        show_help
        ;;
esac

# Main function
main() {
    local feeds_file="${IMMORTALWRT_DIR}/feeds.conf.default"

    # Validate ImmortalWRT directory
    if [[ ! -d "$IMMORTALWRT_DIR" ]]; then
        log_error "ImmortalWRT directory does not exist: $IMMORTALWRT_DIR"
        exit $EXIT_NOT_FOUND
    fi

    # Check if feeds.conf.default exists
    if [[ ! -f "$feeds_file" ]]; then
        log_error "feeds.conf.default not found: $feeds_file"
        log_error "Make sure you're in an ImmortalWRT source directory"
        exit $EXIT_NOT_FOUND
    fi

    local feed_entry="src-git additional_pack ${CUSTOM_PACKAGES_FEED}"

    # Check if feed already exists
    if grep -q "additional_pack" "$feeds_file" 2>/dev/null; then
        log_info "Custom repository already configured in feeds.conf.default"
        exit $EXIT_SUCCESS
    fi

    # Add the feed
    log_info "Adding custom repository: $CUSTOM_PACKAGES_FEED"

    if echo "$feed_entry" >> "$feeds_file"; then
        log_success "Custom repository added successfully"
        log_info "Run './scripts/feeds update -a' to fetch the new feed"
    else
        log_error "Failed to add custom repository"
        exit $EXIT_FAILURE
    fi
}

main "$@"
