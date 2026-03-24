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

if [ -n "$FEED_BRANCH" ]; then
    echo "src-git additional_pack https://github.com/SuperKali/openwrt-packages^${FEED_BRANCH}" >> feeds.conf.default
    echo "Added custom feed with branch: ${FEED_BRANCH}"
else
    echo 'src-git additional_pack https://github.com/SuperKali/openwrt-packages' >> feeds.conf.default
    echo "Added custom feed (default branch)"
fi
