#!/bin/bash
#
# common.sh - Core utilities and initialization for BananaWRT scripts
#
# This library provides:
# - Standard exit codes
# - BANANAWRT_ROOT detection
# - Cleanup trap registration
# - Common utility functions
#
# Usage:
#   source "/path/to/lib/common.sh"
#
# Note: This library sources logging.sh automatically
#

# Prevent multiple sourcing
[[ -n "${_BANANAWRT_COMMON_LOADED:-}" ]] && return 0
_BANANAWRT_COMMON_LOADED=1

# Standard exit codes
declare -g EXIT_SUCCESS=0
declare -g EXIT_FAILURE=1
declare -g EXIT_INVALID_ARGS=2
declare -g EXIT_MISSING_DEPS=3
declare -g EXIT_NOT_FOUND=4
declare -g EXIT_PERMISSION=5
declare -g EXIT_TIMEOUT=6
declare -g EXIT_NETWORK=7
declare -g EXIT_CONFIG=8

# Detect BANANAWRT_ROOT
# Priority: environment variable > script location > current directory
_detect_bananawrt_root() {
    local script_dir=""

    # Check if already set
    if [[ -n "${BANANAWRT_ROOT:-}" ]]; then
        echo "$BANANAWRT_ROOT"
        return 0
    fi

    # Try to detect from BASH_SOURCE
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # Go up one level if we're in lib/ or scripts/
        if [[ "$script_dir" == */lib ]] || [[ "$script_dir" == */scripts ]]; then
            script_dir="$(dirname "$script_dir")"
        fi
        if [[ -f "$script_dir/CLAUDE.md" ]]; then
            echo "$script_dir"
            return 0
        fi
    fi

    # Check GITHUB_WORKSPACE (for CI environment)
    if [[ -n "${GITHUB_WORKSPACE:-}" ]] && [[ -f "${GITHUB_WORKSPACE}/CLAUDE.md" ]]; then
        echo "$GITHUB_WORKSPACE"
        return 0
    fi

    # Fall back to current directory
    echo "$PWD"
}

# Initialize BANANAWRT_ROOT
declare -g BANANAWRT_ROOT="${BANANAWRT_ROOT:-$(_detect_bananawrt_root)}"
export BANANAWRT_ROOT

# Source logging library
if [[ -f "${BANANAWRT_ROOT}/lib/logging.sh" ]]; then
    source "${BANANAWRT_ROOT}/lib/logging.sh"
fi

# Cleanup trap management
declare -ga _BANANAWRT_CLEANUP_FUNCTIONS=()

# Register a cleanup function to be called on exit
# Usage: register_cleanup function_name [arg1] [arg2] ...
register_cleanup() {
    local func="$1"
    shift
    _BANANAWRT_CLEANUP_FUNCTIONS+=("$func $*")
}

# Execute all registered cleanup functions
_execute_cleanup() {
    local exit_code=$?
    for entry in "${_BANANAWRT_CLEANUP_FUNCTIONS[@]}"; do
        eval "$entry" 2>/dev/null || true
    done
    exit $exit_code
}

# Set up the cleanup trap
trap _execute_cleanup EXIT INT TERM

# Common utility functions

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Check if running in CI environment
is_ci() {
    [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]
}

# Check if running in interactive mode
is_interactive() {
    [[ -t 0 ]] && [[ -t 1 ]]
}

# Get current timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Create a temporary file with cleanup
# Usage: temp_file=$(create_temp_file)
create_temp_file() {
    local tmp
    tmp=$(mktemp)
    register_cleanup "rm -f '$tmp'"
    echo "$tmp"
}

# Create a temporary directory with cleanup
# Usage: temp_dir=$(create_temp_dir)
create_temp_dir() {
    local tmp
    tmp=$(mktemp -d)
    register_cleanup "rm -rf '$tmp'"
    echo "$tmp"
}

# Safe file removal with logging
safe_remove() {
    local path="$1"
    if [[ -e "$path" ]]; then
        rm -rf "$path" && log_debug "Removed: $path" || log_warning "Failed to remove: $path"
    fi
}

# Check if a command exists
command_exists() {
    command -v "${1:-}" &>/dev/null
}

# Get script name for messages
get_script_name() {
    basename "${BASH_SOURCE[-1]:-$0}"
}

# Print usage message
print_usage() {
    local script_name
    script_name=$(get_script_name)
    echo "Usage: $script_name $*"
}

# Die with error message and exit code
die() {
    local message="$1"
    local exit_code="${2:-$EXIT_FAILURE}"
    log_error "$message"
    exit "$exit_code"
}

# Ensure script is run as root (for operations requiring privileges)
require_root() {
    if ! is_root; then
        die "This script must be run as root" "$EXIT_PERMISSION"
    fi
}

# Version comparison: returns 0 if $1 > $2, 1 otherwise
version_greater() {
    printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1 | grep -q "^$2$"
}

# Version comparison: returns 0 if $1 >= $2, 1 otherwise
version_ge() {
    [[ "$1" == "$2" ]] || version_greater "$1" "$2"
}

# Get system architecture
get_arch() {
    uname -m
}

# Get OS name
get_os() {
    if [[ -f /etc/openwrt_release ]]; then
        echo "openwrt"
    elif [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "${ID:-unknown}"
    else
        uname -s | tr '[:upper:]' '[:lower:]'
    fi
}

# Export functions
export -f register_cleanup create_temp_file create_temp_dir safe_remove
export -f command_exists is_root is_ci is_interactive get_timestamp
export -f get_script_name print_usage die require_root
export -f version_greater version_ge get_arch get_os
