#!/bin/bash
#
# metadata-generator.sh - Generate BananaWRT metadata for firmware builds
#
# This script creates the /etc/bananawrt_release file containing
# build metadata that will be included in the firmware image.
#
# Usage: metadata-generator.sh
#
# Environment variables:
#   RELEASE_DATE     - Release date/tag (required)
#   GITHUB_SHA       - Full git commit SHA
#   GITHUB_REF       - Git ref (branch/tag)
#   BANANAWRT_RELEASE - Release type (stable/nightly)
#
# Copyright (c) 2024-2025 SuperKali <hello@superkali.me>
# Licensed under the MIT License.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BANANAWRT_ROOT="${BANANAWRT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# In CI environment, prefer GITHUB_WORKSPACE
if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
    BANANAWRT_ROOT="$GITHUB_WORKSPACE"
fi

# Source libraries
source "${BANANAWRT_ROOT}/lib/common.sh"
source "${BANANAWRT_ROOT}/lib/logging.sh"

# Show help
show_help() {
    cat << EOF
Usage: $(get_script_name)

Generate BananaWRT metadata file for firmware builds.

This script creates /etc/bananawrt_release in the firmware image
containing build metadata.

Required environment variables:
  RELEASE_DATE      Release date/tag

Optional environment variables:
  GITHUB_SHA        Full git commit SHA (default: unknown)
  GITHUB_REF        Git reference (default: unknown)
  BANANAWRT_RELEASE Release type: stable or nightly (default: stable)

Options:
  -h, --help        Show this help message
EOF
    exit 0
}

# Check for help flag
case "${1:-}" in
    -h|--help)
        show_help
        ;;
esac

# Validate required environment variables
if [[ -z "${RELEASE_DATE:-}" ]]; then
    log_error "RELEASE_DATE is not set"
    log_error "Set RELEASE_DATE before running this script"
    exit $EXIT_CONFIG
fi

# Get variables from environment with defaults
BUILD_DATE="$RELEASE_DATE"
GITHUB_SHA="${GITHUB_SHA:-unknown}"
SHORT_SHA="${GITHUB_SHA:0:7}"
GITHUB_REF="${GITHUB_REF:-unknown}"
BRANCH="${GITHUB_REF##*/}"
RELEASE_TYPE="${BANANAWRT_RELEASE:-stable}"

# Validate release type
if ! validate_release_type "$RELEASE_TYPE"; then
    log_warning "Invalid release type: $RELEASE_TYPE, defaulting to stable"
    RELEASE_TYPE="stable"
fi

# Target file path (relative to ImmortalWRT build directory)
METADATA_FILE="package/base-files/files/etc/bananawrt_release"

# Create parent directory if needed
mkdir -p "$(dirname "$METADATA_FILE")"

# Generate the metadata file
log_section "Generating BananaWRT metadata"

cat > "$METADATA_FILE" << EOF
# BananaWRT Release Information
# Generated on $(date '+%Y-%m-%d %H:%M:%S')
BANANAWRT_BUILD_DATE='${BUILD_DATE}'
BANANAWRT_COMMIT='${GITHUB_SHA}'
BANANAWRT_COMMIT_SHORT='${SHORT_SHA}'
BANANAWRT_BRANCH='${BRANCH}'
BANANAWRT_TYPE='${RELEASE_TYPE}'
EOF

# Verify the file was created
if [[ -f "$METADATA_FILE" ]]; then
    log_success "Metadata file created: $METADATA_FILE"
else
    log_error "Failed to create metadata file"
    exit $EXIT_FAILURE
fi

# Display the generated metadata
log_info "Release Tag: ${BUILD_DATE}"
log_info "Build Type: ${RELEASE_TYPE}"
log_info "Git Commit: ${SHORT_SHA}"
log_info "Branch: ${BRANCH}"

exit $EXIT_SUCCESS
