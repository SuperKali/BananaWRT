#!/usr/bin/env bash
#
# File: stages/01-clone.sh
# Description: Clone or refresh the ImmortalWRT source tree at the pinned tag
#              specified by BANANAWRT_IMMORTALWRT_VER.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me>
#
# This is free software, licensed under the MIT License.
#

: "${BANANAWRT_IMMORTAL_URL:=https://github.com/immortalwrt/immortalwrt}"

stage_clone() {
    display_subheader "Clone source tree"

    local tag="v$BANANAWRT_IMMORTALWRT_VER"

    if [[ -d "$BANANAWRT_IMMORTAL_DIR/.git" ]]; then
        local current
        current="$(git -C "$BANANAWRT_IMMORTAL_DIR" describe --tags --always 2>/dev/null || echo 'unknown')"
        if [[ "$current" == "$tag" ]]; then
            substep "Existing tree matches $tag, reusing"
            substep_done
            return 0
        fi
        substep "Existing tree at $current — removing"
        if rm -rf "$BANANAWRT_IMMORTAL_DIR"; then
            substep_done
        else
            substep_fail 'unable to remove'
            exit_with_error "Could not remove stale tree at $BANANAWRT_IMMORTAL_DIR"
        fi
    fi

    substep "Cloning immortalwrt @ $tag"
    if git clone --depth 1 --branch "$tag" --single-branch \
            "$BANANAWRT_IMMORTAL_URL" "$BANANAWRT_IMMORTAL_DIR" \
            >/dev/null 2>&1; then
        substep_done
    else
        substep_fail 'git clone failed'
        exit_with_error "Unable to clone $BANANAWRT_IMMORTAL_URL @ $tag"
    fi

    # Sanity check: tree must contain the expected Makefile
    if [[ ! -f "$BANANAWRT_IMMORTAL_DIR/Makefile" ]]; then
        exit_with_error "Cloned tree is incomplete (no Makefile)"
    fi
}
