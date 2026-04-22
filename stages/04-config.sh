#!/usr/bin/env bash
#
# stages/04-config.sh — remove stock pkgs, drop .config, install additional_pack,
#                       inject metadata, merge upstream diffconfig, make defconfig.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me> — MIT.
#

stage_config() {
    display_subheader "Apply build configuration"

    local stock_script="$BANANAWRT_ROOT/scripts/builder/remove-stock-packages.sh"
    if [[ ! -x "$stock_script" ]]; then
        chmod +x "$stock_script" 2>/dev/null || true
    fi

    # 1) Optional files/ overlay
    substep "Staging files/ overlay (if present)"
    if [[ -d "$BANANAWRT_ROOT/files" ]]; then
        cp -a "$BANANAWRT_ROOT/files" "$BANANAWRT_IMMORTAL_DIR/files"
        substep_done 'copied'
    else
        substep_skip 'no files/ directory'
    fi

    # 2) Drop .config
    substep "Installing .config for $BANANAWRT_VERSION_LINE/$BANANAWRT_TRACK"
    if cp "$BANANAWRT_CONFIG_FILE" "$BANANAWRT_IMMORTAL_DIR/.config"; then
        substep_done
    else
        substep_fail 'copy failed'
        exit_with_error "Unable to install .config"
    fi

    # 3) Remove stock packages that are shadowed by additional_pack
    substep "Removing stock packages that conflict with additional_pack"
    local log
    log="$(mktemp -t bananawrt-stock.XXXXXX)"
    if (cd "$BANANAWRT_IMMORTAL_DIR" && \
          GITHUB_WORKSPACE="$BANANAWRT_ROOT" "$stock_script" >"$log" 2>&1); then
        substep_done
    else
        substep_fail 'remove-stock-packages failed'
        cat "$log"
        rm -f "$log"
        exit_with_error "remove-stock-packages.sh exited non-zero"
    fi
    rm -f "$log"

    # 4) Install additional_pack
    substep "Installing additional_pack feed"
    log="$(mktemp -t bananawrt-addpack.XXXXXX)"
    if (cd "$BANANAWRT_IMMORTAL_DIR" && \
          ./scripts/feeds install -p additional_pack -a >"$log" 2>&1); then
        substep_done
    else
        substep_fail 'feeds install additional_pack failed'
        cat "$log"
        rm -f "$log"
        exit_with_error "./scripts/feeds install -p additional_pack -a exited non-zero"
    fi
    rm -f "$log"

    # 5) Generate build metadata (/etc/bananawrt_release)
    substep "Generating build metadata (/etc/bananawrt_release)"
    local meta_script="$BANANAWRT_ROOT/scripts/utils/metadata-generator.sh"
    chmod +x "$meta_script" 2>/dev/null || true
    log="$(mktemp -t bananawrt-metadata.XXXXXX)"
    if (cd "$BANANAWRT_IMMORTAL_DIR" && \
          RELEASE_DATE="${BANANAWRT_RELEASE_DATE}" \
          GITHUB_SHA="${GITHUB_SHA:-unknown}" \
          GITHUB_REF="${GITHUB_REF:-refs/heads/main}" \
          REPO_BRANCH="$BANANAWRT_IMMORTALWRT_VER" \
          BANANAWRT_RELEASE="$BANANAWRT_TRACK" \
          BANANAWRT_VERSION_LINE="$BANANAWRT_VERSION_LINE" \
          "$meta_script" >"$log" 2>&1); then
        substep_done
    else
        substep_fail 'metadata-generator failed'
        cat "$log"
        rm -f "$log"
        exit_with_error "metadata-generator.sh exited non-zero"
    fi
    rm -f "$log"

    # 6) diffconfig merge. Upstream ImmortalWRT publishes a
    # config.buildinfo we can overlay our diff onto; custom forks (any
    # version.json that sets `repo_url`) don't, so we skip the fetch and
    # keep the shipped .config as base. `version_repo_url` in version.json
    # overrides CONFIG_VERSION_REPO (on-device apk distfeeds.list root).
    local CUSTOM_FORK
    CUSTOM_FORK="$(jq -r '.repo_url // empty' "$BANANAWRT_VERSION_JSON")"
    local BUILDINFO_BASE
    BUILDINFO_BASE="$(jq -r '.buildinfo_base // empty' "$BANANAWRT_VERSION_JSON")"
    [[ -z "$BUILDINFO_BASE" ]] && BUILDINFO_BASE="https://downloads.immortalwrt.org/releases/${BANANAWRT_IMMORTALWRT_VER}"
    local VERSION_REPO
    VERSION_REPO="$(jq -r '.version_repo_url // empty' "$BANANAWRT_VERSION_JSON")"
    [[ -z "$VERSION_REPO" ]] && VERSION_REPO="$BUILDINFO_BASE"

    if [[ -n "$CUSTOM_FORK" ]]; then
        substep "Applying diffconfig over shipped .config (custom fork)"
    else
        substep "Merging diffconfig over upstream config.buildinfo"
    fi
    log="$(mktemp -t bananawrt-diffconfig.XXXXXX)"
    if (
        cd "$BANANAWRT_IMMORTAL_DIR"
        ./scripts/diffconfig.sh > diffconfig
        if [[ -z "$CUSTOM_FORK" ]]; then
            curl -sf "${BUILDINFO_BASE}/targets/mediatek/filogic/config.buildinfo" \
                 -o config.buildinfo || true
        fi
        if [[ ! -s config.buildinfo ]]; then
            cp .config config.buildinfo
        fi
        cat diffconfig >> config.buildinfo
        mv config.buildinfo .config
        sed -i -e "s|^CONFIG_VERSION_REPO=.*|CONFIG_VERSION_REPO=\"${VERSION_REPO}\"|g" .config
    ) >"$log" 2>&1; then
        substep_done
    else
        substep_fail 'diffconfig merge failed'
        cat "$log"
        rm -f "$log"
        exit_with_error "diffconfig step failed"
    fi
    rm -f "$log"

    # 7) Enable CCACHE only when the caller opts in explicitly. The upstream
    # tools/ccache path has a known race (issue #15072) that's tricky to
    # bypass reliably on multi-arch containers, so we keep it off by default.
    # Set BANANAWRT_CCACHE=1 to experiment with it.
    if [[ "${BANANAWRT_CCACHE:-0}" == "1" ]]; then
        substep "Enabling CCACHE in .config (opt-in)"
        mkdir -p "$BANANAWRT_CCACHE_DIR"
        (cd "$BANANAWRT_IMMORTAL_DIR"
         sed -i '/^CONFIG_CCACHE[= ]/d; /^# CONFIG_CCACHE /d' .config
         echo 'CONFIG_CCACHE=y' >> .config)
        substep_done
    else
        substep "CCACHE opt-in (unset BANANAWRT_CCACHE → disabled)"
        substep_skip 'default off'
    fi

    # 8) defconfig to realise the merge
    substep "Normalising .config via make defconfig"
    log="$(mktemp -t bananawrt-defconfig.XXXXXX)"
    if (cd "$BANANAWRT_IMMORTAL_DIR" && make defconfig >"$log" 2>&1); then
        substep_done
    else
        substep_fail 'make defconfig failed'
        cat "$log"
        rm -f "$log"
        exit_with_error "make defconfig exited non-zero"
    fi
    rm -f "$log"
}
