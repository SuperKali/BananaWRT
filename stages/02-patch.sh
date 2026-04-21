#!/usr/bin/env bash
#
# File: stages/02-patch.sh
# Description: Apply BananaWRT patches onto the ImmortalWRT tree. Delegates the
#              actual file copy / patch application to scripts/utils/patch-manager.sh
#              which already supports kernel/dts, kernel/files and tree patches.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me>
#
# This is free software, licensed under the MIT License.
#

stage_patch() {
    display_subheader "Apply BananaWRT patches"

    local patch_manager="$BANANAWRT_ROOT/scripts/utils/patch-manager.sh"
    if [[ ! -x "$patch_manager" ]]; then
        chmod +x "$patch_manager" 2>/dev/null || true
    fi

    substep "Running patch-manager (dts/files/tree)"
    local log
    log="$(mktemp -t bananawrt-patches.XXXXXX)"
    if GITHUB_WORKSPACE="$BANANAWRT_ROOT" \
        "$patch_manager" \
            "$BANANAWRT_IMMORTALWRT_VER" \
            "$BANANAWRT_TRACK" \
            "$BANANAWRT_IMMORTAL_DIR" \
            >"$log" 2>&1; then
        substep_done
        if [[ "${BANANAWRT_DEBUG:-0}" == "1" ]]; then
            sed 's/^/    /' "$log"
        fi
    else
        substep_fail 'patch-manager failed'
        printf '\n%b---- patch-manager output ----%b\n' "$C_DIM" "$C_RESET"
        cat "$log"
        printf '%b-------------------------------%b\n\n' "$C_DIM" "$C_RESET"
        rm -f "$log"
        exit_with_error "patch-manager reported errors"
    fi
    rm -f "$log"
}
