#!/bin/bash
set -euo pipefail

#
# File name: custom-repository.sh
# Description: BananaWRT add custom repository
#
# Copyright (c) 2024-2025 SuperKali <hello@superkali.me>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Add a feed source (Closed source)
echo 'src-git additional_pack https://github.com/SuperKali/openwrt-packages' >> feeds.conf.default