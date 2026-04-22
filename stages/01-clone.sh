#!/usr/bin/env bash
#
# stages/01-clone.sh — materialise ImmortalWRT tree at pinned ref.
#
# Uses `git init` + `git fetch --depth 1` + `git checkout` instead of `git
# clone` because actions/cache restores (dl/, .ccache/, feeds/, staging_dir/)
# populate the target dir before this stage runs, and clone refuses non-empty
# destinations.
#
# Version-line level overrides (read from config/<vl>/version.json):
#   .repo_url  — git URL to clone (default: immortalwrt upstream)
#   .ref_type  — "tag" (default) or "branch"
#   .ref       — explicit git ref; defaults to v${branch} (tag) or ${branch}
#                (branch) when absent
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me> — MIT.
#

: "${BANANAWRT_IMMORTAL_URL_DEFAULT:=https://github.com/immortalwrt/immortalwrt}"

# _fetch_ref <ref_type:tag|branch> <ref>
_fetch_ref() {
    local kind="$1" ref="$2"
    case "$kind" in
        tag)
            git fetch --quiet --depth 1 --tags origin "refs/tags/${ref}:refs/tags/${ref}"
            ;;
        branch)
            git fetch --quiet --depth 1 origin "refs/heads/${ref}:refs/remotes/origin/${ref}"
            ;;
        *)
            return 1
            ;;
    esac
}

# _checkout_ref <ref_type:tag|branch> <ref>
_checkout_ref() {
    local kind="$1" ref="$2"
    case "$kind" in
        tag)    git checkout --quiet --force "refs/tags/${ref}" ;;
        branch) git checkout --quiet --force -B "${ref}" "refs/remotes/origin/${ref}" ;;
    esac
}

_init_tree() {
    local kind="$1" ref="$2"
    (
        cd "$BANANAWRT_IMMORTAL_DIR"
        rm -rf .git 2>/dev/null
        git init --quiet
        git remote remove origin 2>/dev/null || true
        git remote add origin "$BANANAWRT_IMMORTAL_URL"
        _fetch_ref "$kind" "$ref"
        _checkout_ref "$kind" "$ref"
    )
}

_refresh_tree() {
    local kind="$1" ref="$2"
    (
        cd "$BANANAWRT_IMMORTAL_DIR"
        git remote set-url origin "$BANANAWRT_IMMORTAL_URL" 2>/dev/null \
            || git remote add origin "$BANANAWRT_IMMORTAL_URL"
        _fetch_ref "$kind" "$ref"
        _checkout_ref "$kind" "$ref"
    )
}

# Resolve repo URL, ref kind, and ref from the version.json plus defaults.
_resolve_source() {
    local vjson="$BANANAWRT_VERSION_JSON"
    BANANAWRT_IMMORTAL_URL="$(jq -r '.repo_url // empty' "$vjson")"
    BANANAWRT_REF_TYPE="$(jq -r '.ref_type // "tag"' "$vjson")"
    BANANAWRT_REF="$(jq -r '.ref // empty' "$vjson")"

    [[ -z "$BANANAWRT_IMMORTAL_URL" ]] && BANANAWRT_IMMORTAL_URL="$BANANAWRT_IMMORTAL_URL_DEFAULT"

    if [[ -z "$BANANAWRT_REF" ]]; then
        case "$BANANAWRT_REF_TYPE" in
            tag)    BANANAWRT_REF="v${BANANAWRT_IMMORTALWRT_VER}" ;;
            branch) BANANAWRT_REF="${BANANAWRT_IMMORTALWRT_VER}"   ;;
        esac
    fi
}

stage_clone() {
    display_subheader "Clone source tree"

    _resolve_source
    local url="$BANANAWRT_IMMORTAL_URL"
    local kind="$BANANAWRT_REF_TYPE"
    local ref="$BANANAWRT_REF"

    mkdir -p "$BANANAWRT_IMMORTAL_DIR"

    # ── Case 1: existing git repo at destination ─────────────────────────
    if [[ -d "$BANANAWRT_IMMORTAL_DIR/.git" ]]; then
        local current
        if [[ "$kind" == "tag" ]]; then
            current="$(git -C "$BANANAWRT_IMMORTAL_DIR" describe --tags --always 2>/dev/null || echo '')"
        else
            current="$(git -C "$BANANAWRT_IMMORTAL_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
        fi
        if [[ "$current" == "$ref" ]]; then
            substep "Existing tree already at $kind/$ref"
            substep_done
            return 0
        fi
        substep "Updating tree (${current:-unknown} → $kind/$ref)"
        if _refresh_tree "$kind" "$ref" >/dev/null 2>&1; then
            substep_done
            return 0
        fi
        substep_fail 'fetch/checkout failed — re-initialising'
        # fall through to re-init
    fi

    # ── Case 2: directory exists but is not a git repo (cache-only) ──────
    substep "Initialising source tree @ $kind/$ref from $url"
    local log
    log="$(mktemp -t bananawrt-clone.XXXXXX)"
    if _init_tree "$kind" "$ref" >"$log" 2>&1; then
        substep_done
    else
        substep_fail 'git init+fetch+checkout failed'
        printf '\n%b---- git output ----%b\n' "$C_DIM" "$C_RESET"
        cat "$log"
        printf '%b--------------------%b\n\n' "$C_DIM" "$C_RESET"
        rm -f "$log"
        exit_with_error "Unable to materialise $url @ $kind/$ref at $BANANAWRT_IMMORTAL_DIR"
    fi
    rm -f "$log"

    # Sanity check: the tree must contain the expected Makefile
    if [[ ! -f "$BANANAWRT_IMMORTAL_DIR/Makefile" ]]; then
        exit_with_error "Source tree is incomplete (no Makefile at $BANANAWRT_IMMORTAL_DIR)"
    fi
}
