#!/usr/bin/env bash
#
# lib/interactive.sh — dialog(1) picker for version line/track/arch/docker.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me> — MIT.
#

# Sets (when not already): BANANAWRT_VERSION_LINE, BANANAWRT_TRACK,
# BANANAWRT_ARCH, BANANAWRT_USE_DOCKER.
interactive_menu() {
    if ! check_dialog; then
        exit_with_error "dialog is not installed; either install it or pass --version-line/--track"
    fi

    local tmpfile
    tmpfile="$(mktemp -t bananawrt-dialog.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -f '$tmpfile'" RETURN

    local -a lines
    local chosen_vl chosen_track chosen_arch chosen_docker

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
        --title ' Step 1/4 — Version line ' \
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
        --title ' Step 2/4 — Track ' \
        --menu "Select a track for $chosen_vl:" \
        12 70 4 \
        "${items[@]}" 2>"$tmpfile" || exit_with_error "Cancelled by user" 130
    chosen_track="$(<"$tmpfile")"

    # 3) Architecture
    dialog --clear \
        --backtitle 'BananaWRT Builder' \
        --title ' Step 3/4 — Runner architecture ' \
        --menu 'Which architecture should the build target?' \
        11 70 2 \
        'ARM64' 'Native self-hosted or ubuntu-24.04-arm fallback' \
        'X64'   'GitHub ubuntu-latest or self-hosted x86_64' \
        2>"$tmpfile" || exit_with_error "Cancelled by user" 130
    chosen_arch="$(<"$tmpfile")"

    # 4) Docker
    dialog --clear \
        --backtitle 'BananaWRT Builder' \
        --title ' Step 4/4 — Build environment ' \
        --menu 'Run the build inside the BananaWRT container?' \
        11 70 2 \
        'docker'    'Use ghcr.io/superkali/bananawrt-builder (recommended)' \
        'host'      'Use the local environment (requires deps installed)' \
        2>"$tmpfile" || exit_with_error "Cancelled by user" 130
    chosen_docker="$(<"$tmpfile")"

    clear
    BANANAWRT_VERSION_LINE="${BANANAWRT_VERSION_LINE:-$chosen_vl}"
    BANANAWRT_TRACK="${BANANAWRT_TRACK:-$chosen_track}"
    BANANAWRT_ARCH="${BANANAWRT_ARCH:-$chosen_arch}"
    if [[ -z "${BANANAWRT_USE_DOCKER+x}" ]]; then
        if [[ "$chosen_docker" == "docker" ]]; then
            BANANAWRT_USE_DOCKER=1
        else
            BANANAWRT_USE_DOCKER=0
        fi
    fi

    display_alert ok "Configuration selected via interactive menu"
}
