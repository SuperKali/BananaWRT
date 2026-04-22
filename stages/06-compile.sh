#!/usr/bin/env bash
#
# stages/06-compile.sh — cross-compile firmware; -j1 V=s fallback on failure.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me> — MIT.
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

    # Known OpenWRT race (openwrt#15072): tools/liblzo wraps its compiler
    # through ccache before tools/ccache is installed. Seed it first.
    if grep -q '^CONFIG_CCACHE=y' "$BANANAWRT_IMMORTAL_DIR/.config"; then
        substep "Pre-building tools/ccache (avoid liblzo race)"
        local prelog
        prelog="$(mktemp -t bananawrt-ccache-pre.XXXXXX)"
        if (cd "$BANANAWRT_IMMORTAL_DIR" && make tools/ccache/install -j"$jobs" >"$prelog" 2>&1); then
            substep_done
            rm -f "$prelog"
        else
            substep_fail 'parallel pre-build failed, retrying with -j1 V=s'
            printf '%b---- ccache parallel pre-build tail ----%b\n' "$C_DIM" "$C_RESET"
            tail -n 40 "$prelog"
            printf '%b-----------------------------------------%b\n' "$C_DIM" "$C_RESET"
            rm -f "$prelog"
            # Verbose sequential retry — surfaces the real error
            display_alert info "Re-running: make tools/ccache/install -j1 V=s"
            if ! (cd "$BANANAWRT_IMMORTAL_DIR" && make tools/ccache/install -j1 V=s); then
                exit_with_error "tools/ccache failed to build even with -j1 V=s (check log above)"
            fi
            display_alert ok "tools/ccache built successfully after sequential retry"
        fi
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
