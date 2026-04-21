#!/usr/bin/env bash
#
# File: stages/03-feeds.sh
# Description: Inject the BananaWRT additional_pack feed into feeds.conf.default,
#              then update/install all feeds.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me>
#
# This is free software, licensed under the MIT License.
#

stage_feeds() {
    display_subheader "Configure feeds"

    local repo_script="$BANANAWRT_ROOT/scripts/builder/custom-repository.sh"
    if [[ ! -x "$repo_script" ]]; then
        chmod +x "$repo_script" 2>/dev/null || true
    fi

    substep "Adding additional_pack feed (branch: $BANANAWRT_FEED_BRANCH)"
    if (cd "$BANANAWRT_IMMORTAL_DIR" && \
          "$repo_script" "$BANANAWRT_FEED_BRANCH" >/dev/null 2>&1); then
        substep_done
    else
        substep_fail 'custom-repository.sh failed'
        exit_with_error "Unable to append additional_pack feed"
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
