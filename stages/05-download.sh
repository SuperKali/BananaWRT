#!/usr/bin/env bash
#
# File: stages/05-download.sh
# Description: Populate dl/ with upstream sources via `make download`.
#              Reports cache hit/miss ratio based on files present before vs.
#              after the step.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me>
#
# This is free software, licensed under the MIT License.
#

stage_download() {
    display_subheader "Download upstream sources"

    mkdir -p "$BANANAWRT_DL_DIR"

    # Count dl entries before the run so we can report cache coverage
    local before_files before_size
    before_files="$(find "$BANANAWRT_DL_DIR" -type f 2>/dev/null | wc -l)"
    before_size="$(du -sb "$BANANAWRT_DL_DIR" 2>/dev/null | awk '{print $1}')"
    before_size="${before_size:-0}"

    local jobs="${BANANAWRT_JOBS:-$(nproc)}"

    substep "make download -j$jobs (existing: $before_files files, $(format_bytes "$before_size"))"
    local log
    log="$(mktemp -t bananawrt-download.XXXXXX)"
    if (cd "$BANANAWRT_IMMORTAL_DIR" && make "download" -j"$jobs" >"$log" 2>&1); then
        # Remove stubs < 1 KiB that indicate a broken download
        find "$BANANAWRT_DL_DIR" -size -1024c -type f -print -delete >>"$log" 2>&1 || true
        local after_files after_size
        after_files="$(find "$BANANAWRT_DL_DIR" -type f 2>/dev/null | wc -l)"
        after_size="$(du -sb "$BANANAWRT_DL_DIR" 2>/dev/null | awk '{print $1}')"
        after_size="${after_size:-0}"
        local new=$(( after_files - before_files ))
        (( new < 0 )) && new=0
        local hit_pct=0
        if (( after_files > 0 )); then
            hit_pct=$(( 100 * before_files / after_files ))
        fi
        substep_done "cache $hit_pct%, +$new files → $(format_bytes "$after_size")"
    else
        substep_fail 'make download failed'
        printf '\n%b---- make download output (tail) ----%b\n' "$C_DIM" "$C_RESET"
        tail -n 80 "$log"
        printf '%b--------------------------------------%b\n\n' "$C_DIM" "$C_RESET"
        rm -f "$log"
        exit_with_error "make download exited non-zero"
    fi
    rm -f "$log"
}
