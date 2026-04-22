#!/usr/bin/env bash
#
# lib/interactive.sh — dialog(1) picker for version line/track/arch.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me> — MIT.
#

# Sets (when not already): BANANAWRT_VERSION_LINE, BANANAWRT_TRACK, BANANAWRT_ARCH.
interactive_menu() {
    if ! check_dialog; then
        exit_with_error "dialog is not installed; either install it or pass --version-line/--track"
    fi

    local tmpfile
    tmpfile="$(mktemp -t bananawrt-dialog.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -f '$tmpfile'" RETURN

    local -a lines
    local chosen_vl chosen_track chosen_arch

    # 1) Version line
    mapfile -t lines < <(list_version_lines)
    if [[ ${#lines[@]} -eq 0 ]]; then
        exit_with_error "No active version lines found in config/"
    fi
    local -a items=()
    local vl
    for vl in "${lines[@]}"; do
        local branch
        branch="$(jq -r '.branch' "$BANANAWRT_ROOT/config/$vl/version.json")"
        items+=( "$vl" "ImmortalWRT $branch" )
    done
    dialog --clear \
        --backtitle 'BananaWRT Builder' \
        --title ' Step 1/3 — Version line ' \
        --menu 'Select the ImmortalWRT version line to build:' \
        15 70 6 \
        "${items[@]}" 2>"$tmpfile" || exit_with_error "Cancelled by user" 130
    chosen_vl="$(<"$tmpfile")"

    # 2) Track
    mapfile -t lines < <(list_tracks_for "$chosen_vl")
    items=()
    local t
    for t in "${lines[@]}"; do
        local label
        case "$t" in
            stable)  label='Stable release — monthly cadence' ;;
            nightly) label='Nightly release — weekly cadence' ;;
            *)       label='Custom track'                    ;;
        esac
        items+=( "$t" "$label" )
    done
    dialog --clear \
        --backtitle 'BananaWRT Builder' \
        --title ' Step 2/3 — Track ' \
        --menu "Select a track for $chosen_vl:" \
        12 70 4 \
        "${items[@]}" 2>"$tmpfile" || exit_with_error "Cancelled by user" 130
    chosen_track="$(<"$tmpfile")"

    # 3) Architecture
    dialog --clear \
        --backtitle 'BananaWRT Builder' \
        --title ' Step 3/3 — Runner architecture ' \
        --menu 'Which architecture should the build target?' \
        11 70 2 \
        'ARM64' 'Native self-hosted or ubuntu-24.04-arm fallback' \
        'X64'   'GitHub ubuntu-latest or self-hosted x86_64' \
        2>"$tmpfile" || exit_with_error "Cancelled by user" 130
    chosen_arch="$(<"$tmpfile")"

    clear
    BANANAWRT_VERSION_LINE="${BANANAWRT_VERSION_LINE:-$chosen_vl}"
    BANANAWRT_TRACK="${BANANAWRT_TRACK:-$chosen_track}"
    BANANAWRT_ARCH="${BANANAWRT_ARCH:-$chosen_arch}"

    display_alert ok "Configuration selected via interactive menu"
}
