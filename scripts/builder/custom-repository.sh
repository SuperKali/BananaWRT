#!/bin/bash#!/bin/bash
#
# File name: custom-repository.sh
# Description: Add the BananaWRT additional_pack feed
#

set -euo pipefail

FEED_BRANCH="${1:-}"
FEED_REPO_URL="${BANANAWRT_FEED_URL:-https://github.com/ManiMaran420/openwrt-packages}"

if [[ -n "$FEED_BRANCH" ]]; then
    printf 'src-git additional_pack %s;%s\n' "$FEED_REPO_URL" "$FEED_BRANCH" >> feeds.conf.default
    echo "Added additional_pack feed from $FEED_REPO_URL (branch: $FEED_BRANCH)"
else
    printf 'src-git additional_pack %s\n' "$FEED_REPO_URL" >> feeds.conf.default
    echo "Added additional_pack feed from $FEED_REPO_URL (default branch)"
fi
