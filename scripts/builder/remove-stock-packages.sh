#!/bin/bash
#
# File name: remove-stock-packages.sh
# Description: BananaWRT remove stock packages from upstream repository
#
# Copyright (c) 2024-2025 SuperKali <hello@superkali.me>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# Runs from the ImmortalWRT tree after "feeds install -a". A package that
# the additional_pack feed also provides must come from additional_pack,
# so the stock copy (the link under package/feeds/<feed>/) is removed; the
# config stage then installs additional_pack over it. Deriving the list
# from the feed keeps it right when packages are added there: a fixed list
# missed sms-tool, so images shipped the stock one without our patches.

shopt -s nullglob

removed=0
for dir in feeds/additional_pack/*/; do
    [ -f "$dir/Makefile" ] || continue
    pkg="$(basename "$dir")"
    for link in package/feeds/*/"$pkg"; do
        case "$link" in
            package/feeds/additional_pack/*) continue ;;
        esac
        echo "Removing stock $link (provided by additional_pack)"
        rm -rf "$link"
        removed=$((removed + 1))
    done
done
echo "Stock packages removed: $removed"
