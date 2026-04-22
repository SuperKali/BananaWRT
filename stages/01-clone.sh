#!/usr/bin/env bash
#
# stages/01-clone.sh — materialise ImmortalWRT tree at pinned tag.
#
# Uses `git init` + `git fetch --depth 1` + `git checkout` instead of `git
# clone` because actions/cache restores (dl/, .ccache/, feeds/, staging_dir/)
# populate the target dir before this stage runs, and clone refuses non-empty
# destinations.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me> — MIT.
#
# This is free software, licensed under the MIT License.
#

: "${BANANAWRT_IMMORTAL_URL:=https://github.com/immortalwrt/immortalwrt}"

# Fetch the ref, creating/updating the local tag pointer.
_fetch_tag() {
    local tag="$1"
    # --tags is required alongside --depth 1 so the tag object is resolvable.
    git fetch --quiet --depth 1 --tags origin "refs/tags/${tag}:refs/tags/${tag}"
}

_init_tree() {
    local tag="$1"
    (
        cd "$BANANAWRT_IMMORTAL_DIR"
        rm -rf .git 2>/dev/null
        git init --quiet
        git remote remove origin 2>/dev/null || true
        git remote add origin "$BANANAWRT_IMMORTAL_URL"
        _fetch_tag "$tag"
        git checkout --quiet --force "refs/tags/${tag}"
    )
}

_refresh_tree() {
    local tag="$1"
    (
        cd "$BANANAWRT_IMMORTAL_DIR"
        git remote set-url origin "$BANANAWRT_IMMORTAL_URL" 2>/dev/null \
            || git remote add origin "$BANANAWRT_IMMORTAL_URL"
        _fetch_tag "$tag"
        git checkout --quiet --force "refs/tags/${tag}"
    )
}

stage_clone() {
    display_subheader "Clone source tree"

    local tag="v$BANANAWRT_IMMORTALWRT_VER"

    mkdir -p "$BANANAWRT_IMMORTAL_DIR"

    # ── Case 1: existing git repo at destination ─────────────────────────
    if [[ -d "$BANANAWRT_IMMORTAL_DIR/.git" ]]; then
        local current
        current="$(git -C "$BANANAWRT_IMMORTAL_DIR" describe --tags --always 2>/dev/null || echo '')"
        if [[ "$current" == "$tag" ]]; then
            substep "Existing tree already at $tag"
            substep_done
            return 0
        fi
        substep "Updating tree (${current:-unknown} → $tag)"
        if _refresh_tree "$tag" >/dev/null 2>&1; then
            substep_done
            return 0
        fi
        substep_fail 'fetch/checkout failed — re-initialising'
        # fall through to re-init
    fi

    # ── Case 2: directory exists but is not a git repo (cache-only) ──────
    substep "Initialising source tree @ $tag"
    local log
    log="$(mktemp -t bananawrt-clone.XXXXXX)"
    if _init_tree "$tag" >"$log" 2>&1; then
        substep_done
    else
        substep_fail 'git init+fetch+checkout failed'
        printf '\n%b---- git output ----%b\n' "$C_DIM" "$C_RESET"
        cat "$log"
        printf '%b--------------------%b\n\n' "$C_DIM" "$C_RESET"
        rm -f "$log"
        exit_with_error "Unable to materialise $BANANAWRT_IMMORTAL_URL @ $tag at $BANANAWRT_IMMORTAL_DIR"
    fi
    rm -f "$log"

    # Sanity check: the tree must contain the expected Makefile
    if [[ ! -f "$BANANAWRT_IMMORTAL_DIR/Makefile" ]]; then
        exit_with_error "Source tree is incomplete (no Makefile at $BANANAWRT_IMMORTAL_DIR)"
    fi
}
