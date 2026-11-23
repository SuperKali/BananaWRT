#!/usr/bin/env bash
#
# stages/03-feeds.sh — inject additional_pack feed, then update + install.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me> — MIT.
#

restore_luci_dashboard() {
    local feed="$1" patch_file="$2" applied="$3"
    local previous="$patch_file"

    if [[ -f "$applied" ]]; then
        previous="$applied"
    fi

    if [[ -e "$feed/.git" ]]; then
        # Reverse only the exact unstaged patch; never unwind staged changes.
        if git -C "$feed" apply --cached --check "$previous" >/dev/null 2>&1 &&
           git -C "$feed" apply --reverse --check "$previous" >/dev/null 2>&1; then
            substep "Removing the previous BananaWRT Dashboard patch before updating LuCI"
            if git -C "$feed" apply --reverse "$previous"; then
                substep_done
            else
                substep_fail 'unable to reverse the Dashboard patch'
                exit_with_error "Check the LuCI checkout at $feed before updating feeds"
            fi
        elif [[ -f "$applied" ]] &&
             ! git -C "$feed" apply --check "$previous" >/dev/null 2>&1 &&
             ! git -C "$feed" apply --cached --reverse --check "$previous" >/dev/null 2>&1; then
            exit_with_error "The previous Dashboard patch no longer matches $feed; inspect local changes before updating feeds"
        fi
    fi
    rm -f -- "$applied" || exit_with_error "Unable to clear the previous Dashboard patch record"
}

patch_luci_dashboard() {
    local feed="$1" patch_file="$2" applied="$3"
    local output

    substep "Patching the LuCI Dashboard for OpenWrt 2020"
    if [[ ! -e "$feed/.git" ]]; then
        substep_fail 'LuCI feed checkout missing'
        exit_with_error "Expected a Git checkout at $feed"
    fi

    if output="$(git -C "$feed" apply --check "$patch_file" 2>&1)"; then
        # Keep the exact patch for the next run, even if this file is updated.
        cp -- "$patch_file" "$applied" || exit_with_error "Unable to record the Dashboard patch at $applied"
        if ! git -C "$feed" apply "$applied"; then
            exit_with_error "Unable to apply the Dashboard patch to $feed"
        fi
        substep_done
    elif git -C "$feed" apply --cached --reverse --check "$patch_file" >/dev/null 2>&1; then
        substep_done  # Upstream already contains the patch.
    else
        substep_fail 'LuCI Dashboard patch failed'
        printf '%s\n' "$output" >&2
        exit_with_error "Unable to apply $patch_file to the LuCI feed"
    fi
}

stage_feeds() {
    display_subheader "Configure feeds"

    local repo_script="$BANANAWRT_ROOT/scripts/builder/custom-repository.sh"
    if [[ ! -x "$repo_script" ]]; then
        chmod +x "$repo_script" 2>/dev/null || true
    fi

    local feed_commit="${BANANAWRT_FEED_COMMIT:-}"
    substep "Adding additional_pack feed (${feed_commit:-$BANANAWRT_FEED_BRANCH})"
    if (cd "$BANANAWRT_IMMORTAL_DIR" && \
          "$repo_script" "$BANANAWRT_FEED_BRANCH" "$feed_commit" >/dev/null 2>&1); then
        substep_done
    else
        substep_fail 'custom-repository.sh failed'
        exit_with_error "Unable to append additional_pack feed"
    fi

    local dashboard_patch='' luci_feed='' dashboard_applied=''
    if [[ "$BANANAWRT_VERSION_LINE" == v25.12-mtk-vendor && "$BANANAWRT_TRACK" == mtk-vendor ]]; then
        dashboard_patch="$BANANAWRT_ROOT/patch/feeds/$BANANAWRT_VERSION_LINE/$BANANAWRT_TRACK/luci/010-dashboard-openwrt2020.patch"
        luci_feed="$BANANAWRT_IMMORTAL_DIR/feeds/luci"
        dashboard_applied="$BANANAWRT_IMMORTAL_DIR/feeds/.bananawrt-luci-dashboard.patch"
        restore_luci_dashboard "$luci_feed" "$dashboard_patch" "$dashboard_applied"
    fi

    substep "Updating feeds (may take a while on cold cache)"
    local log
    log="$(mktemp -t bananawrt-feeds-update.XXXXXX)"
    if (cd "$BANANAWRT_IMMORTAL_DIR" && \
          ./scripts/feeds update -a >"$log" 2>&1); then
        substep_done
    else
        substep_fail 'feeds update failed'
        printf '\n%b---- feeds update output ----%b\n' "$C_DIM" "$C_RESET"
        cat "$log"
        printf '%b------------------------------%b\n\n' "$C_DIM" "$C_RESET"
        rm -f "$log"
        exit_with_error "./scripts/feeds update -a exited non-zero"
    fi
    rm -f "$log"

    if [[ -n "$feed_commit" ]]; then
        local actual_commit
        if [[ ! -e "$BANANAWRT_IMMORTAL_DIR/feeds/additional_pack/.git" ]] ||
           ! actual_commit=$(git -C "$BANANAWRT_IMMORTAL_DIR/feeds/additional_pack" rev-parse HEAD) ||
           [[ "$actual_commit" != "$feed_commit" ]]; then
            exit_with_error "additional_pack did not check out the deployed commit $feed_commit"
        fi
    fi

    if [[ -n "$dashboard_patch" ]]; then
        patch_luci_dashboard "$luci_feed" "$dashboard_patch" "$dashboard_applied"
    fi

    substep "Installing feeds"
    log="$(mktemp -t bananawrt-feeds-install.XXXXXX)"
    if (cd "$BANANAWRT_IMMORTAL_DIR" && \
          ./scripts/feeds install -a >"$log" 2>&1); then
        substep_done
    else
        substep_fail 'feeds install failed'
        printf '\n%b---- feeds install output ----%b\n' "$C_DIM" "$C_RESET"
        cat "$log"
        printf '%b-------------------------------%b\n\n' "$C_DIM" "$C_RESET"
        rm -f "$log"
        exit_with_error "./scripts/feeds install -a exited non-zero"
    fi
    rm -f "$log"
}
