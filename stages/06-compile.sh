#!/usr/bin/env bash
#
# File: stages/06-compile.sh
# Description: Run the long-running ImmortalWRT cross compilation. Falls back to
#              `make -j1 V=s` on error and reports ccache stats if available.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me>
#
# This is free software, licensed under the MIT License.
#

stage_compile() {
    display_subheader "Compile firmware"

    local jobs="${BANANAWRT_JOBS:-$(nproc)}"

    # Point ccache at our persistent directory when the package is installed.
    if command -v ccache >/dev/null 2>&1; then
        export CCACHE_DIR="$BANANAWRT_CCACHE_DIR"
        mkdir -p "$CCACHE_DIR"
        # Cap at a reasonable size to avoid unbounded growth
        ccache -M "${BANANAWRT_CCACHE_MAX:-8G}" >/dev/null 2>&1 || true
        local ccache_before_hits ccache_before_miss
        ccache_before_hits="$(ccache -s 2>/dev/null | awk -F: '/cache hit/ && !/direct/ && !/preprocessed/ {gsub(/ /,""); print $2; exit}')"
        ccache_before_miss="$(ccache -s 2>/dev/null | awk -F: '/cache miss/ {gsub(/ /,""); print $2; exit}')"
        ccache_before_hits="${ccache_before_hits:-0}"
        ccache_before_miss="${ccache_before_miss:-0}"
    fi

    # When CONFIG_CCACHE=y the upstream tools/Makefile has a known race:
    # tools/liblzo (and friends) try to wrap their compiler through the
    # not-yet-installed ccache binary, which fails. Build tools/ccache
    # explicitly first to seed staging_dir/host/bin/ccache.
    #   Ref: https://github.com/openwrt/openwrt/issues/15072
    #   Ref: https://forum.openwrt.org/t/ccache-build-error-with-21-02-0-rc1-which-fix-is-likely/95238
    if grep -q '^CONFIG_CCACHE=y' "$BANANAWRT_IMMORTAL_DIR/.config"; then
        substep "Pre-building tools/ccache (avoid liblzo race)"
        local prelog
        prelog="$(mktemp -t bananawrt-ccache-pre.XXXXXX)"
        if (cd "$BANANAWRT_IMMORTAL_DIR" && make tools/ccache/install -j"$jobs" >"$prelog" 2>&1); then
            substep_done
        else
            substep_fail 'tools/ccache pre-build failed'
            tail -n 40 "$prelog"
            rm -f "$prelog"
            exit_with_error "Unable to pre-build tools/ccache"
        fi
        rm -f "$prelog"
    fi

    display_alert info "Starting make -j$jobs (this is the long one — grab a coffee)"

    local start_ts end_ts duration
    start_ts="$(date +%s)"

    local rc=0
    if ! (cd "$BANANAWRT_IMMORTAL_DIR" && make -j"$jobs") ; then
        display_alert warn "Parallel build failed — retrying with -j1 V=s for a readable log"
        (cd "$BANANAWRT_IMMORTAL_DIR" && make -j1 V=s)
        rc=$?
    fi

    end_ts="$(date +%s)"
    duration=$(( end_ts - start_ts ))

    if (( rc != 0 )); then
        exit_with_error "make returned $rc"
    fi

    display_alert ok "Compilation finished in $(human_duration "$duration")"

    # ccache stats (delta since stage start)
    if command -v ccache >/dev/null 2>&1; then
        local hits miss delta_hit delta_miss hit_pct=0
        hits="$(ccache -s 2>/dev/null | awk -F: '/cache hit/ && !/direct/ && !/preprocessed/ {gsub(/ /,""); print $2; exit}')"
        miss="$(ccache -s 2>/dev/null | awk -F: '/cache miss/ {gsub(/ /,""); print $2; exit}')"
        hits="${hits:-0}"; miss="${miss:-0}"
        delta_hit=$(( hits - ccache_before_hits ))
        delta_miss=$(( miss - ccache_before_miss ))
        local total=$(( delta_hit + delta_miss ))
        if (( total > 0 )); then
            hit_pct=$(( 100 * delta_hit / total ))
        fi
        display_alert info "ccache — hits: $delta_hit, misses: $delta_miss ($hit_pct%)"
    fi

    # Record DEVICE_NAME for downstream stages
    (cd "$BANANAWRT_IMMORTAL_DIR" && \
        grep '^CONFIG_TARGET.*DEVICE.*=y' .config \
        | sed -r 's/.*DEVICE_(.*)=y/\1/' > DEVICE_NAME)
}
