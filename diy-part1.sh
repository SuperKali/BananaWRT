#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
# Copyright (c) 2024-2025 SuperKali <hello@superkali.me>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source (Closed source)
if [ "$BANANAWRT_RELEASE" == "nightly" ] && [ "$REPO_BRANCH" == "master" ]; then
  echo 'src-git additional_pack https://github.com/SuperKali/openwrt-packages;apk' >> feeds.conf.default
else
  echo 'src-git additional_pack https://github.com/SuperKali/openwrt-packages' >> feeds.conf.default
fi