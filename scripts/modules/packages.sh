#!/bin/bash
#
# packages.sh - Package update module for BananaWRT
#
# This module provides functions for checking and updating
# custom packages from the BananaWRT repository.
#
# Usage:
#   source "/path/to/lib/common.sh"
#   source "/path/to/lib/network.sh"
#   source "/path/to/modules/packages.sh"
#
#   packages_update --dry-run
#

# Prevent multiple sourcing
[[ -n "${_BANANAWRT_PACKAGES_LOADED:-}" ]] && return 0
_BANANAWRT_PACKAGES_LOADED=1

# Ensure dependencies are loaded
if [[ -z "${_BANANAWRT_NETWORK_LOADED:-}" ]]; then
    _modules_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${_modules_dir}/../lib/network.sh"
fi

# Load configuration
if [[ -f "${BANANAWRT_ROOT}/config/bananawrt.conf" ]]; then
    source "${BANANAWRT_ROOT}/config/bananawrt.conf"
fi

# Fetch package index from repository
# Usage: packages_fetch_index version
# Returns: JSON index on stdout
packages_fetch_index() {
    local version="$1"
    local index_url="${CUSTOM_REPO_URL}/releases/${version}/packages/additional_pack/index.json"

    log_info "Fetching package index from ${CUSTOM_REPO_URL}..."

    local temp_file
    temp_file=$(create_temp_file)

    if ! download_with_progress "$index_url" "$temp_file" "Fetching package index"; then
        log_error "Failed to download package index"
        return $EXIT_NETWORK
    fi

    if [[ ! -s "$temp_file" ]]; then
        log_error "Package index is empty"
        return $EXIT_FAILURE
    fi

    cat "$temp_file"
    return 0
}

# Get current firmware version from OpenWRT release
# Usage: packages_get_firmware_version
# Returns: Version string
packages_get_firmware_version() {
    if [[ -f "$OPENWRT_RELEASE_FILE" ]]; then
        grep -o "DISTRIB_RELEASE='.*'" "$OPENWRT_RELEASE_FILE" | cut -d "'" -f 2
    else
        echo ""
    fi
}

# Check for package updates
# Usage: packages_check_updates index_json
# Returns: List of packages needing updates
packages_check_updates() {
    local index_json="$1"
    local temp_list
    temp_list=$(create_temp_file)

    # Extract package names and versions
    echo "$index_json" | jq -r '.packages | to_entries[] | "\(.key)|\(.value)"' > "$temp_list"

    local updates_list
    updates_list=$(create_temp_file)
    local updates_needed=false

    log_info "Checking packages for updates..."

    while IFS='|' read -r pkg_name repo_version; do
        # Skip language packages
        if echo "$pkg_name" | grep -qE "^(${EXCLUDED_PACKAGE_PREFIXES// /|})"; then
            continue
        fi

        # Get local version
        local local_version
        local_version=$(opkg list-installed 2>/dev/null | grep "^${pkg_name} - " | cut -d ' ' -f 3)

        if [[ -z "$local_version" ]]; then
            # Not installed
            echo -e " - ${BOLD}${CYAN}${pkg_name}${RESET}: ${BOLD}${YELLOW}Not installed${RESET} -> ${BOLD}${GREEN}${repo_version}${RESET}" >> "$updates_list"
            updates_needed=true
        elif [[ "$local_version" != "$repo_version" ]]; then
            # Update available
            echo -e " - ${BOLD}${CYAN}${pkg_name}${RESET}: ${BOLD}${YELLOW}${local_version}${RESET} -> ${BOLD}${GREEN}${repo_version}${RESET}" >> "$updates_list"
            updates_needed=true
        fi
    done < "$temp_list"

    if [[ "$updates_needed" == "true" ]]; then
        echo -e "${BOLD}${MAGENTA}Packages available for update:${RESET}"
        cat "$updates_list"
        PACKAGES_UPDATES_NEEDED=true
    else
        PACKAGES_UPDATES_NEEDED=false
    fi

    # Store the temp list for later use
    PACKAGES_TEMP_LIST="$temp_list"

    return 0
}

# Add custom repository to opkg feeds
# Usage: packages_add_repo version
# Returns: 0 on success
packages_add_repo() {
    local version="$1"
    local repo_line="src/gz additional_pack ${CUSTOM_REPO_URL}/releases/${version}/packages/additional_pack"

    if ! grep -q "$repo_line" "${OPKG_CUSTOM_FEEDS_FILE}" 2>/dev/null; then
        log_info "Adding custom repository..."
        echo "$repo_line" >> "${OPKG_CUSTOM_FEEDS_FILE}"
    fi
}

# Install package updates
# Usage: packages_install_updates index_json [dry_run]
# Returns: 0 on success
packages_install_updates() {
    local index_json="$1"
    local dry_run="${2:-false}"

    local temp_list
    temp_list=$(create_temp_file)

    # Extract package names and versions
    echo "$index_json" | jq -r '.packages | to_entries[] | "\(.key)|\(.value)"' > "$temp_list"

    local installed=0
    local failed=0

    while IFS='|' read -r pkg_name repo_version; do
        # Skip language packages
        if echo "$pkg_name" | grep -qE "^(${EXCLUDED_PACKAGE_PREFIXES// /|})"; then
            continue
        fi

        # Get local version
        local local_version
        local_version=$(opkg list-installed 2>/dev/null | grep "^${pkg_name} - " | cut -d ' ' -f 3)

        if [[ -z "$local_version" ]] || [[ "$local_version" != "$repo_version" ]]; then
            log_info "Installing/upgrading ${pkg_name} (${repo_version})..."

            if [[ "$dry_run" == "true" ]]; then
                log_info "DRY-RUN: Would run 'opkg install ${pkg_name}'"
                ((installed++))
            else
                if opkg install "$pkg_name" 2>/dev/null; then
                    ((installed++))
                else
                    log_warning "Failed to install ${pkg_name}"
                    ((failed++))
                fi
            fi
        fi
    done < "$temp_list"

    if [[ "$dry_run" != "true" ]]; then
        if [[ "$failed" -eq 0 ]]; then
            log_success "Installed/updated $installed packages"
        else
            log_warning "Installed $installed packages with $failed failures"
        fi
    fi

    return 0
}

# Perform package update
# Usage: packages_update [--dry-run]
# This is the main entry point for package updates
packages_update() {
    local dry_run=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=true ;;
        esac
        shift
    done

    # Check dependencies
    require_commands curl jq opkg || return $EXIT_MISSING_DEPS

    # Get current firmware version
    local version
    version=$(packages_get_firmware_version)

    if [[ -z "$version" ]]; then
        log_error "Unable to determine current firmware version"
        return $EXIT_FAILURE
    fi

    log_info "Current firmware version: $version"

    # Fetch package index
    local index_json
    index_json=$(packages_fetch_index "$version") || return $?

    # Get architecture
    local arch
    arch=$(echo "$index_json" | jq -r '.architecture // empty')

    if [[ -z "$arch" ]] || [[ "$arch" == "null" ]]; then
        log_error "Architecture not found in package index"
        return $EXIT_FAILURE
    fi

    log_info "Package architecture: $arch"

    # Check for updates
    packages_check_updates "$index_json"

    if [[ "$PACKAGES_UPDATES_NEEDED" != "true" ]]; then
        log_success "All packages are up to date"
        return 0
    fi

    echo ""
    echo -e "${BOLD}${MAGENTA}Do you want to proceed with updating these packages? (y/n):${RESET}"
    read -r proceed

    if [[ "$proceed" != "y" ]] && [[ "$proceed" != "Y" ]]; then
        log_info "Update cancelled"
        return 0
    fi

    # Add repository
    if [[ "$dry_run" == "true" ]]; then
        log_info "DRY-RUN: Would add repository to ${OPKG_CUSTOM_FEEDS_FILE}"
        log_info "DRY-RUN: Would run 'opkg update'"
    else
        packages_add_repo "$version"
        log_info "Updating package lists..."
        opkg update
    fi

    # Install updates
    packages_install_updates "$index_json" "$dry_run"

    log_success "Package updates completed"
    return 0
}

# Export functions
export -f packages_fetch_index packages_get_firmware_version packages_check_updates
export -f packages_add_repo packages_install_updates packages_update
