#!/usr/bin/env bash
#
# compile.sh — BananaWRT firmware build orchestrator.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me>
# MIT License — see /LICENSE.
#

set -Eeuo pipefail

BANANAWRT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BANANAWRT_ROOT

# shellcheck source=lib/functions.sh
source "$BANANAWRT_ROOT/lib/functions.sh"
# shellcheck source=lib/banner.sh
source "$BANANAWRT_ROOT/lib/banner.sh"
# shellcheck source=lib/config.sh
source "$BANANAWRT_ROOT/lib/config.sh"
# shellcheck source=lib/prereqs.sh
source "$BANANAWRT_ROOT/lib/prereqs.sh"
# shellcheck source=lib/interactive.sh
source "$BANANAWRT_ROOT/lib/interactive.sh"

install_traps

BANANAWRT_VERSION_LINE="${BANANAWRT_VERSION_LINE:-}"
BANANAWRT_TRACK="${BANANAWRT_TRACK:-}"
BANANAWRT_ARCH="${BANANAWRT_ARCH:-ARM64}"
BANANAWRT_IMMORTALWRT_VER="${BANANAWRT_IMMORTALWRT_VER:-}"
BANANAWRT_JOBS="${BANANAWRT_JOBS:-}"
BANANAWRT_STAGE="${BANANAWRT_STAGE:-}"
BANANAWRT_KEEP_SOURCE="${BANANAWRT_KEEP_SOURCE:-0}"
BANANAWRT_CLEAN="${BANANAWRT_CLEAN:-}"
BANANAWRT_CI="${BANANAWRT_CI:-}"
BANANAWRT_NO_PACKAGE="${BANANAWRT_NO_PACKAGE:-0}"
BANANAWRT_RELEASE_DATE="${BANANAWRT_RELEASE_DATE:-$(date +'%Y.%m.%d-%H%M')}"

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --version-line|-V) BANANAWRT_VERSION_LINE="$2"; shift 2 ;;
            --track|-t)        BANANAWRT_TRACK="$2";        shift 2 ;;
            --arch|-a)         BANANAWRT_ARCH="$2";         shift 2 ;;
            --immortalwrt-version) BANANAWRT_IMMORTALWRT_VER="$2"; shift 2 ;;
            --jobs|-j)         BANANAWRT_JOBS="$2";         shift 2 ;;
            --ci)              BANANAWRT_CI=1;              shift ;;
            --no-package)      BANANAWRT_NO_PACKAGE=1;      shift ;;
            --stage)           BANANAWRT_STAGE="$2";        shift 2 ;;
            --keep-source)     BANANAWRT_KEEP_SOURCE=1;     shift ;;
            --clean)           BANANAWRT_CLEAN='build';     shift ;;
            --clean=all)       BANANAWRT_CLEAN='all';       shift ;;
            --clean=*)         BANANAWRT_CLEAN="${1#--clean=}"; shift ;;
            --verbose|-v)      BANANAWRT_DEBUG=1;           shift ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                display_alert err "Unknown option: $1"
                echo
                show_help
                exit 2
                ;;
        esac
    done
    export BANANAWRT_DEBUG
}

declare -ga BANANAWRT_STAGE_ORDER=(clone patch feeds config download compile package)
declare -gA BANANAWRT_STAGE_TITLES=(
    [clone]='Clone source tree'
    [patch]='Apply BananaWRT patches'
    [feeds]='Configure feeds'
    [config]='Apply build configuration'
    [download]='Download upstream sources'
    [compile]='Compile firmware'
    [package]='Package & publish'
)
declare -gA BANANAWRT_STAGE_DURATIONS=()

load_stage() {
    local name="$1"
    local file
    case "$name" in
        clone)    file="$BANANAWRT_ROOT/stages/01-clone.sh"    ;;
        patch)    file="$BANANAWRT_ROOT/stages/02-patch.sh"    ;;
        feeds)    file="$BANANAWRT_ROOT/stages/03-feeds.sh"    ;;
        config)   file="$BANANAWRT_ROOT/stages/04-config.sh"   ;;
        download) file="$BANANAWRT_ROOT/stages/05-download.sh" ;;
        compile)  file="$BANANAWRT_ROOT/stages/06-compile.sh"  ;;
        package)  file="$BANANAWRT_ROOT/stages/07-package.sh"  ;;
        *) exit_with_error "Unknown stage: $name" ;;
    esac
    # shellcheck disable=SC1090
    source "$file"
}

run_single_stage() {
    local name="$1" idx="$2" total="$3"
    local title="${BANANAWRT_STAGE_TITLES[$name]}"

    stage_header "$idx" "$total" "$title"
    timer_start "stage-$name"
    load_stage "$name"
    "stage_$name"
    local elapsed
    elapsed="$(timer_stop "stage-$name")"
    BANANAWRT_STAGE_DURATIONS[$name]="$elapsed"
    display_alert ok "[$idx/$total] $title — $(human_duration "$elapsed")"
}

run_pipeline() {
    local stages=("${BANANAWRT_STAGE_ORDER[@]}")
    if [[ -n "$BANANAWRT_STAGE" ]]; then
        local valid=0 s
        for s in "${stages[@]}"; do
            [[ "$s" == "$BANANAWRT_STAGE" ]] && valid=1
        done
        if (( valid == 0 )); then
            exit_with_error "Unknown --stage: $BANANAWRT_STAGE (valid: ${stages[*]})"
        fi
        stages=( "$BANANAWRT_STAGE" )
    fi
    # SDK workflow sets --no-package to skip firmware publishing stage
    if [[ "$BANANAWRT_NO_PACKAGE" == "1" ]]; then
        local -a filtered=()
        local s
        for s in "${stages[@]}"; do
            [[ "$s" == "package" ]] && continue
            filtered+=( "$s" )
        done
        stages=( "${filtered[@]}" )
    fi
    local total=${#stages[@]}
    local i=0 name
    for name in "${stages[@]}"; do
        i=$((i + 1))
        run_single_stage "$name" "$i" "$total"
    done
}

on_exit() {
    local rc="$1"
    if [[ -n "${BANANAWRT_TOTAL_START:-}" ]]; then
        local total=$(( $(date +%s) - BANANAWRT_TOTAL_START ))
        if (( rc == 0 )); then
            display_summary "$total"
        else
            display_alert err "Build aborted after $(human_duration "$total")"
        fi
    fi
}

display_summary() {
    local total="$1"
    local -a rows=()
    local name human
    rows+=( "Status:        $(printf '%b%s%b' "$C_GREEN$C_BOLD" 'SUCCESS' "$C_RESET")" )
    rows+=( "Duration:      $(human_duration "$total")" )
    rows+=( "Version line:  $BANANAWRT_VERSION_LINE  (track: $BANANAWRT_TRACK)" )
    rows+=( "ImmortalWRT:   $BANANAWRT_IMMORTALWRT_VER" )
    rows+=( "Kernel:        ${BANANAWRT_KERNEL_VERSION:-n/a}" )
    rows+=( "Devices:       ${BANANAWRT_TARGET_DEVICES:-n/a}" )
    if [[ -n "${BANANAWRT_FIRMWARE_DIR:-}" ]]; then
        rows+=( "Firmware dir:  ${BANANAWRT_FIRMWARE_DIR#$BANANAWRT_ROOT/}" )
    fi
    rows+=( "" )
    rows+=( "Per-stage timings:" )
    for name in "${BANANAWRT_STAGE_ORDER[@]}"; do
        [[ -z "${BANANAWRT_STAGE_DURATIONS[$name]:-}" ]] && continue
        human="$(human_duration "${BANANAWRT_STAGE_DURATIONS[$name]}")"
        rows+=( "  - $(pad_right "$name" 10) $human" )
    done
    display_box 'Build Summary' "${rows[@]}"
}

main() {
    parse_args "$@"
    check_host_requirements
    ensure_workspace

    if [[ -z "$BANANAWRT_VERSION_LINE" || -z "$BANANAWRT_TRACK" ]]; then
        if is_ci; then
            exit_with_error "CI mode requires --version-line and --track"
        fi
        interactive_menu
    fi

    validate_version_track "$BANANAWRT_VERSION_LINE" "$BANANAWRT_TRACK"
    resolved_paths

    local runner_type='local'
    if is_ci; then
        runner_type="${RUNNER_NAME:-CI}"
    fi

    show_banner "$BANANAWRT_VERSION_LINE" "$BANANAWRT_TRACK" \
                "$BANANAWRT_IMMORTALWRT_VER" "$BANANAWRT_ARCH" "$runner_type"
    show_config_summary

    BANANAWRT_TOTAL_START="$(date +%s)"

    case "${BANANAWRT_CLEAN:-}" in
        build)
            display_alert info "Cleaning build_dir/ (preserving dl/ and ccache)"
            rm -rf "$BANANAWRT_IMMORTAL_DIR/build_dir" "$BANANAWRT_IMMORTAL_DIR/tmp"
            ;;
        all)
            display_alert warn "Full wipe — removing $BANANAWRT_IMMORTAL_DIR"
            rm -rf "$BANANAWRT_IMMORTAL_DIR"
            ;;
        '')
            ;;
        *)
            display_alert warn "Unknown --clean value '$BANANAWRT_CLEAN' — ignoring"
            ;;
    esac

    run_pipeline
}

main "$@"
