
#!/bin/bash
#
# File name: metadata-generator.sh
# Description: Script to inject BananaWRT metadata into the build
#
# Copyright (c) 2024-2025 SuperKali <hello@superkali.me>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

source "$GITHUB_WORKSPACE/.github/scripts/functions/formatter.sh"

# Check if RELEASE_DATE is set
if [ -z "$RELEASE_DATE" ]; then
    echo "Error: RELEASE_DATE is not set!"
    exit 1
fi

# Get other variables from environment
BUILD_DATE="$RELEASE_DATE"
GITHUB_SHA="${GITHUB_SHA:-unknown}"
SHORT_SHA="${GITHUB_SHA:0:7}"
GITHUB_REF="${GITHUB_REF:-unknown}"
BRANCH="${GITHUB_REF##*/}"
RELEASE_TYPE="${BANANAWRT_RELEASE:-stable}"
IMMORTALWRT_VERSION="${REPO_BRANCH:-unknown}"
VERSION_LINE="v$(echo "$IMMORTALWRT_VERSION" | grep -oP '^\d+\.\d+')"

# Create the BananaWRT release file
cat > package/base-files/files/etc/bananawrt_release << EOF
# BananaWRT Release Information
BANANAWRT_BUILD_DATE='${BUILD_DATE}'
BANANAWRT_COMMIT='${GITHUB_SHA}'
BANANAWRT_COMMIT_SHORT='${SHORT_SHA}'
BANANAWRT_BRANCH='${BRANCH}'
BANANAWRT_TYPE='${RELEASE_TYPE}'
BANANAWRT_IMMORTALWRT_VERSION='${IMMORTALWRT_VERSION}'
BANANAWRT_VERSION_LINE='${VERSION_LINE}'
EOF

section "BananaWRT metadata injected successfully!"
info "Release Tag: ${RELEASE_DATE}"
info "Build Type: ${RELEASE_TYPE}"
info "ImmortalWRT Version: ${IMMORTALWRT_VERSION}"
info "Version Line: ${VERSION_LINE}"
info "Git Commit: ${SHORT_SHA}"