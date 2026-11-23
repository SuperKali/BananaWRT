#!/bin/bash
#
# File name: custom-repository.sh
# Description: BananaWRT add custom repository
#
# Copyright (c) 2024-2025 SuperKali <hello@superkali.me>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

FEED_BRANCH="${1:-}"
FEED_COMMIT="${2:-}"

if [ -n "$FEED_COMMIT" ]; then
    if [[ ! "$FEED_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
        printf '%s\n' 'Invalid additional_pack commit' >&2
        exit 1
    fi
    printf 'src-git additional_pack https://github.com/SuperKali/openwrt-packages^%s\n' \
        "$FEED_COMMIT" >> feeds.conf.default
    echo "Added custom feed at commit: ${FEED_COMMIT}"
elif [ -n "$FEED_BRANCH" ]; then
    echo "src-git additional_pack https://github.com/SuperKali/openwrt-packages;${FEED_BRANCH}" >> feeds.conf.default
    echo "Added custom feed with branch: ${FEED_BRANCH}"
else
    echo 'src-git additional_pack https://github.com/SuperKali/openwrt-packages' >> feeds.conf.default
    echo "Added custom feed (default branch)"
fi
