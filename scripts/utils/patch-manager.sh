#!/bin/bash
#
# patch-manager.sh - Apply patches to ImmortalWRT source tree
#
# Usage: patch-manager.sh [RELEASE_TYPE] [IMMORTALWRT_DIR]
#
# Arguments:
#   RELEASE_TYPE     Release type (stable, nightly) - default: stable
#   IMMORTALWRT_DIR  Path to ImmortalWRT directory - default: current directory
#
# Environment variables:
#   GITHUB_WORKSPACE  Required when running in GitHub Actions
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BANANAWRT_ROOT="${BANANAWRT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# Source libraries
source "${BANANAWRT_ROOT}/lib/common.sh"
source "${BANANAWRT_ROOT}/lib/logging.sh"
source "${BANANAWRT_ROOT}/lib/validation.sh"

# Default values
RELEASE_TYPE="${1:-stable}"
IMMORTALWRT_DIR="${2:-${PWD}}"

# In CI environment, use GITHUB_WORKSPACE
if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
    PATCH_BASE_DIR="${GITHUB_WORKSPACE}/patch"
else
    PATCH_BASE_DIR="${BANANAWRT_ROOT}/patch"
fi

# Show help
show_help() {
    cat << EOF
Usage: $(get_script_name) [RELEASE_TYPE] [IMMORTALWRT_DIR]

Apply BananaWRT patches to ImmortalWRT source tree.

Arguments:
  RELEASE_TYPE     Release type (stable, nightly) - default: stable
  IMMORTALWRT_DIR  Path to ImmortalWRT directory - default: current directory

Options:
  -h, --help       Show this help message

Examples:
  $(get_script_name) stable /path/to/immortalwrt
  $(get_script_name) nightly
EOF
    exit 0
}

# Check for help flag
case "${1:-}" in
    -h|--help)
        show_help
        ;;
esac

# Apply patches from source directory to destination
# Usage: apply_patches patch_type dest_dir description
apply_patches() {
    local patch_type="$1"
    local dest_dir="$2"
    local description="$3"

    local patch_dir="${PATCH_BASE_DIR}/${patch_type}/${RELEASE_TYPE}"

    # Check if patch directory exists
    if [[ ! -d "$patch_dir" ]]; then
        log_info "No $patch_type patches found for $RELEASE_TYPE release type - skipping"
        return 0
    fi

    # Count files to apply
    local file_count
    file_count=$(find "$patch_dir" -type f | wc -l)

    if [[ "$file_count" -eq 0 ]]; then
        log_info "No files found in $patch_type patches directory - skipping"
        return 0
    fi

    log_section "Applying $description ($file_count files)"

    # Validate destination directory
    if [[ ! -d "$dest_dir" ]]; then
        log_error "Destination directory does not exist: $dest_dir"
        return 1
    fi

    local applied_count=0
    local failed_count=0

    # Process each file
    while IFS= read -r file; do
        local rel_path="${file#$patch_dir/}"
        local dest_file="${dest_dir}/${rel_path}"
        local dest_parent
        dest_parent=$(dirname "$dest_file")

        # Create parent directory if needed
        if [[ ! -d "$dest_parent" ]]; then
            if ! mkdir -p "$dest_parent"; then
                log_error "Failed to create directory: $dest_parent"
                failed_count=$((failed_count + 1))
                continue
            fi
        fi

        # Copy the file
        if cp "$file" "$dest_file"; then
            log_info "Applied: $rel_path"
            applied_count=$((applied_count + 1))
        else
            log_error "Failed to apply: $rel_path"
            failed_count=$((failed_count + 1))
        fi
    done < <(find "$patch_dir" -type f)

    # Report results
    if [[ "$failed_count" -eq 0 ]]; then
        log_success "$description applied successfully ($applied_count files)"
    else
        log_warning "$description completed with $failed_count failures ($applied_count successful)"
    fi

    return "$failed_count"
}

# Validate the environment
validate_environment() {
    if ! validate_release_type "$RELEASE_TYPE"; then
        return 1
    fi

    if ! require_directory "$IMMORTALWRT_DIR" "ImmortalWRT directory does not exist: $IMMORTALWRT_DIR"; then
        return 1
    fi

    if ! require_directory "$PATCH_BASE_DIR" "Patch base directory does not exist: $PATCH_BASE_DIR"; then
        return 1
    fi

    return 0
}

# Main function
main() {
    log_section "BananaWRT Patch Manager"
    log_info "Release Type: $RELEASE_TYPE"
    log_info "ImmortalWRT Directory: $IMMORTALWRT_DIR"
    log_info "Patch Base Directory: $PATCH_BASE_DIR"

    if ! validate_environment; then
        exit $EXIT_INVALID_ARGS
    fi

    local total_failed=0

    # Apply DTS patches
    apply_patches "kernel/dts" "${IMMORTALWRT_DIR}/target/linux/mediatek/dts" "Device Tree Source patches"
    total_failed=$((total_failed + $?))

    # Apply kernel files patches
    apply_patches "kernel/files" "${IMMORTALWRT_DIR}/target/linux/mediatek/files" "Kernel files patches"
    total_failed=$((total_failed + $?))

    echo ""

    if [[ "$total_failed" -eq 0 ]]; then
        log_success "All patches applied successfully!"
        exit $EXIT_SUCCESS
    else
        log_error "Patch application completed with $total_failed total failures"
        exit $EXIT_FAILURE
    fi
}

main "$@"
