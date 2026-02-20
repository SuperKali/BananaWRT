#!/bin/bash
#
# network.sh - Network utilities for BananaWRT
#
# This library provides:
# - Curl wrappers with retries and timeout
# - Download with progress/spinner
# - JSON fetching utilities
#
# Usage:
#   source "/path/to/lib/common.sh"
#   source "/path/to/lib/network.sh"
#
#   json=$(fetch_json "https://api.github.com/repos/user/repo/releases")
#   download_with_progress "$url" "$output_file" "Downloading..."
#

# Prevent multiple sourcing
[[ -n "${_BANANAWRT_NETWORK_LOADED:-}" ]] && return 0
_BANANAWRT_NETWORK_LOADED=1

# Ensure common.sh is loaded
if [[ -z "${_BANANAWRT_COMMON_LOADED:-}" ]]; then
    _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${_script_dir}/common.sh"
fi

# Load configuration
if [[ -f "${BANANAWRT_ROOT}/config/bananawrt.conf" ]]; then
    source "${BANANAWRT_ROOT}/config/bananawrt.conf"
fi

# Default values if not set in config
: "${CURL_TIMEOUT:=30}"
: "${CURL_RETRY_COUNT:=3}"
: "${CURL_RETRY_DELAY:=5}"

# Silent curl with retries and timeout
# Usage: curl_silent url [output_file]
# Returns: 0 on success, non-zero on failure
curl_silent() {
    local url="$1"
    local output="${2:-}"

    local curl_args=(
        -s
        -L
        --connect-timeout "$CURL_TIMEOUT"
        --max-time "$((CURL_TIMEOUT * 3))"
        --retry "$CURL_RETRY_COUNT"
        --retry-delay "$CURL_RETRY_DELAY"
        --retry-max-time "$((CURL_RETRY_COUNT * CURL_RETRY_DELAY + CURL_TIMEOUT * 3))"
    )

    if [[ -n "$output" ]]; then
        curl_args+=(-o "$output")
    fi

    log_debug "Fetching: $url"
    curl "${curl_args[@]}" "$url"
}

# Check if a URL is reachable
# Usage: url_reachable url
# Returns: 0 if reachable, 1 otherwise
url_reachable() {
    local url="$1"

    if curl_silent --head "$url" &>/dev/null; then
        return 0
    fi
    return 1
}

# Internal: Spinner animation
_spinner_animation() {
    local pid=$1
    local prefix="$2"
    local spinstr='|/-\'
    local spinner_char

    while kill -0 "$pid" 2>/dev/null; do
        spinner_char="${spinstr:0:1}"
        printf "\r%b [%c]" "$prefix" "$spinner_char"
        spinstr="${spinstr:1}${spinner_char}"
        sleep 0.1 2>/dev/null || sleep 1
    done

    printf "\r%b [OK]\n" "$prefix"
}

# Download a file with spinner progress indicator
# Usage: download_with_progress url output_file [message]
# Returns: 0 on success, 1 on failure
download_with_progress() {
    local url="$1"
    local output="$2"
    local message="${3:-Downloading}"
    local prefix="${BOLD}${YELLOW}${message}...${RESET}"

    log_debug "Downloading: $url -> $output"

    # Start download in background
    (
        curl -s -L \
            --connect-timeout "$CURL_TIMEOUT" \
            --max-time "$((CURL_TIMEOUT * 10))" \
            --retry "$CURL_RETRY_COUNT" \
            --retry-delay "$CURL_RETRY_DELAY" \
            -o "$output" "$url"
    ) &
    local curl_pid=$!

    _spinner_animation "$curl_pid" "$prefix"

    wait "$curl_pid"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Download failed: $url"
        return 1
    fi

    if [[ ! -f "$output" ]] || [[ ! -s "$output" ]]; then
        log_error "Download produced empty or missing file: $output"
        return 1
    fi

    log_debug "Download complete: $(basename "$output")"
    return 0
}

# Fetch JSON from a URL and return it
# Usage: json=$(fetch_json url)
# Returns: JSON string on stdout, exits with error on failure
fetch_json() {
    local url="$1"
    local temp_file

    temp_file=$(create_temp_file)

    if ! curl_silent "$url" "$temp_file"; then
        log_error "Failed to fetch JSON from: $url"
        rm -f "$temp_file"
        return 1
    fi

    if [[ ! -s "$temp_file" ]]; then
        log_error "Empty response from: $url"
        rm -f "$temp_file"
        return 1
    fi

    # Validate JSON if jq is available
    if command -v jq &>/dev/null; then
        if ! jq empty "$temp_file" 2>/dev/null; then
            log_error "Invalid JSON response from: $url"
            rm -f "$temp_file"
            return 1
        fi
    fi

    cat "$temp_file"
    rm -f "$temp_file"
    return 0
}

# Fetch JSON with spinner progress
# Usage: json=$(fetch_json_with_progress url [message])
# Returns: JSON string on stdout
fetch_json_with_progress() {
    local url="$1"
    local message="${2:-Fetching data}"
    local temp_file
    local prefix="${BOLD}${YELLOW}${message}...${RESET}"

    temp_file=$(mktemp)

    # Start download in background
    (
        curl_silent "$url" "$temp_file"
    ) &
    local curl_pid=$!

    _spinner_animation "$curl_pid" "$prefix"

    wait "$curl_pid"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]] || [[ ! -s "$temp_file" ]]; then
        log_error "Failed to fetch: $url"
        rm -f "$temp_file"
        return 1
    fi

    # Validate JSON if jq is available
    if command -v jq &>/dev/null; then
        if ! jq empty "$temp_file" 2>/dev/null; then
            log_error "Invalid JSON response"
            rm -f "$temp_file"
            return 1
        fi
    fi

    cat "$temp_file"
    rm -f "$temp_file"
    return 0
}

# Fetch GitHub releases for a repository
# Usage: releases=$(fetch_github_releases [owner/repo])
# Returns: JSON array of releases
fetch_github_releases() {
    local repo="${1:-${BANANAWRT_REPO}}"
    local url="${GITHUB_API_URL}/${repo}/releases"

    log_info "Fetching releases from GitHub..."
    fetch_json_with_progress "$url" "Loading releases"
}

# Get asset download URL from release JSON
# Usage: url=$(get_release_asset_url release_json asset_name)
# Returns: Download URL or empty string if not found
get_release_asset_url() {
    local json="$1"
    local asset_name="$2"

    if ! command -v jq &>/dev/null; then
        log_error "jq is required for parsing release assets"
        return 1
    fi

    echo "$json" | jq -r --arg name "$asset_name" \
        '.assets[] | select(.name == $name) | .browser_download_url' | head -n 1
}

# Get all assets matching a pattern from release JSON
# Usage: get_release_assets release_json pattern
# Returns: List of asset names
get_release_assets_by_pattern() {
    local json="$1"
    local pattern="$2"

    if ! command -v jq &>/dev/null; then
        log_error "jq is required for parsing release assets"
        return 1
    fi

    echo "$json" | jq -r --arg pattern "$pattern" \
        '.assets[] | select(.name | endswith($pattern)) | .name'
}

# Get release tag name at index
# Usage: tag=$(get_release_tag releases_json index)
# Returns: Tag name or "null" if not found
get_release_tag() {
    local json="$1"
    local index="${2:-0}"

    if ! command -v jq &>/dev/null; then
        log_error "jq is required for parsing releases"
        return 1
    fi

    echo "$json" | jq -r ".[$index].tag_name"
}

# Parse release type from release body
# Usage: type=$(get_release_type release_json)
# Returns: "Stable", "Nightly", or "Unknown"
get_release_type() {
    local json="$1"
    local body

    if ! command -v jq &>/dev/null; then
        log_error "jq is required for parsing releases"
        echo "Unknown"
        return 1
    fi

    body=$(echo "$json" | jq -r '.body // empty')

    if echo "$body" | grep -iq "Stable Release"; then
        echo "Stable"
    elif echo "$body" | grep -iq "Nightly Release"; then
        echo "Nightly"
    else
        echo "Unknown"
    fi
}

# Download firmware assets from GitHub release
# Usage: download_firmware_assets release_json index version [temp_dir]
# Returns: 0 on success, 1 on failure
download_firmware_assets() {
    local json="$1"
    local index="$2"
    local version="$3"
    local temp_dir="${4:-/tmp}"
    local dry_run="${5:-false}"

    source "${BANANAWRT_ROOT}/config/bananawrt.conf"

    local target="${TARGET_SUBTARGET}"
    local vendor="${TARGET_VENDOR}"
    local device="${TARGET_DEVICE}"
    local prefix="immortalwrt-${version}-${target}-${vendor}_${device}"

    local assets=(
        "${prefix}-${ASSET_PRELOADER_SUFFIX}"
        "${prefix}-${ASSET_BL31_UBOOT_SUFFIX}"
        "${prefix}-${ASSET_INITRAMFS_SUFFIX}"
        "${prefix}-${ASSET_SYSUPGRADE_SUFFIX}"
    )

    for asset in "${assets[@]}"; do
        local url
        url=$(echo "$json" | jq -r --arg name "$asset" \
            ".[$index].assets[] | select(.name == \$name) | .browser_download_url" | head -n 1)

        if [[ -z "$url" ]] || [[ "$url" == "null" ]]; then
            log_error "Asset not found: $asset"
            return 1
        fi

        local output="${temp_dir}/${asset}"

        if [[ "$dry_run" == "true" ]]; then
            log_info "DRY-RUN: Would download $asset from $url"
            touch "$output"
        else
            log_info "Downloading $asset..."
            if ! download_with_progress "$url" "$output" "Fetching $asset"; then
                log_error "Failed to download: $asset"
                return 1
            fi
            log_success "Downloaded: $asset"
        fi
    done

    return 0
}

# Export functions
export -f curl_silent url_reachable download_with_progress
export -f fetch_json fetch_json_with_progress
export -f fetch_github_releases get_release_asset_url get_release_assets_by_pattern
export -f get_release_tag get_release_type download_firmware_assets
