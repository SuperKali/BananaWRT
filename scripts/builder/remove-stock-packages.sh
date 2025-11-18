#!/bin/bash
set -euo pipefail

#
# File name: remove-stock-packages.sh
# Description: BananaWRT remove stock packages from upstream repository
#
# Copyright (c) 2024-2025 SuperKali <hello@superkali.me>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

check_and_remove() {
    path="$1"
    if [ -e "$path" ]; then
        echo "Removing: $path"
        rm -rf "$path"
    else
        echo "Not found: $path"
    fi
}

check_and_remove "package/feeds/packages/lpac"
check_and_remove "package/feeds/luci/luci-app-modemband"
check_and_remove "package/feeds/packages/modemband"
check_and_remove "package/feeds/luci/luci-app-3ginfo-lite"
check_and_remove "feeds/luci/protocols/luci-proto-quectel"
check_and_remove "feeds/packages/net/quectel-cm"

remove_with_glob() {
    pattern="$1"
    shopt -s nullglob
    matches=( $pattern )
    shopt -u nullglob

    if [ ${#matches[@]} -gt 0 ] && [ -e "${matches[0]}" ]; then
        echo "Removing files matching: $pattern"
        for file in "${matches[@]}"; do
            echo " - $file"
            rm -rf "$file"
        done
    else
        echo "No files found matching: $pattern"
    fi
}

remove_with_glob "package/feeds/luci/luci-i18n-modemband-*"
remove_with_glob "package/feeds/luci/luci-app-sms-tool-js*"
