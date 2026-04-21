#!/usr/bin/env bash
#
# File: compile.sh
# Description: BananaWRT firmware build orchestrator.
#
#              This is the single entry point for both local development
#              builds and CI invocations. It sources lib/*.sh for helpers,
#              parses CLI arguments (or launches a dialog menu if called
#              without any), optionally re-executes itself inside the
#              BananaWRT builder container, then runs the stages/*.sh
#              pipeline.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

set -Eeuo pipefail

# ─── Resolve repo root ────────────────────────────────────────────────────────
BANANAWRT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BANANAWRT_ROOT

# ─── Load libraries ───────────────────────────────────────────────────────────
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
# shellcheck source=lib/docker.sh
source "$BANANAWRT_ROOT/lib/docker.sh"

install_traps

# ─── Defaults ─────────────────────────────────────────────────────────────────
BANANAWRT_VERSION_LINE="${BANANAWRT_VERSION_LINE:-}"
BANANAWRT_TRACK="${BANANAWRT_TRACK:-}"
BANANAWRT_ARCH="${BANANAWRT_ARCH:-ARM64}"
BANANAWRT_IMMORTALWRT_VER="${BANANAWRT_IMMORTALWRT_VER:-}"
BANANAWRT_JOBS="${BANANAWRT_JOBS:-}"
BANANAWRT_USE_DOCKER="${BANANAWRT_USE_DOCKER:-}"
BANANAWRT_DOCKER_IMAGE="${BANANAWRT_DOCKER_IMAGE:-}"
BANANAWRT_STAGE="${BANANAWRT_STAGE:-}"
BANANAWRT_KEEP_SOURCE="${BANANAWRT_KEEP_SOURCE:-0}"
BANANAWRT_CLEAN="${BANANAWRT_CLEAN:-}"
BANANAWRT_CI="${BANANAWRT_CI:-}"
BANANAWRT_RELEASE_DATE="${BANANAWRT_RELEASE_DATE:-$(date +'%Y.%m.%d-%H%M')}"

# ─── Argument parser ─────────────────────────────────────────────────────────
parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --version-line|-V) BANANAWRT_VERSION_LINE="$2"; shift 2 ;;
            --track|-t)        BANANAWRT_TRACK="$2";        shift 2 ;;
            --arch|-a)         BANANAWRT_ARCH="$2";         shift 2 ;;
            --immortalwrt-version) BANANAWRT_IMMORTALWRT_VER="$2"; shift 2 ;;
            --jobs|-j)         BANANAWRT_JOBS="$2";         shift 2 ;;
            --docker)          BANANAWRT_USE_DOCKER=1;      shift ;;
            --no-docker)       BANANAWRT_USE_DOCKER=0;      shift ;;
            --image)           BANANAWRT_DOCKER_IMAGE="$2"; shift 2 ;;
            --ci)              BANANAWRT_CI=1;              shift ;;
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

# ─── Stage runner ────────────────────────────────────────────────────────────
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

# load a stage file lazily
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
    local total=${#stages[@]}
    local i=0 name
    for name in "${stages[@]}"; do
        i=$((i + 1))
        run_single_stage "$name" "$i" "$total"
    done
}

# ─── Exit hook ────────────────────────────────────────────────────────────────
on_exit() {
    local rc="$1"
    if [[ "$BANANAWRT_KEEP_SOURCE" != "1" && "$rc" != "0" ]]; then
        : # leave tree for debugging on failure
    fi
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

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    # Minimal host toolchain required even to parse versions.json
    check_host_requirements
    ensure_workspace

    # No required args provided? → launch interactive picker
    if [[ -z "$BANANAWRT_VERSION_LINE" || -z "$BANANAWRT_TRACK" ]]; then
        if is_ci; then
            exit_with_error "CI mode requires --version-line and --track"
        fi
        interactive_menu
    fi

    validate_version_track "$BANANAWRT_VERSION_LINE" "$BANANAWRT_TRACK"
    resolved_paths

    # Default: use docker when available AND we are NOT already inside a container.
    if [[ -z "$BANANAWRT_USE_DOCKER" ]]; then
        if in_container; then
            BANANAWRT_USE_DOCKER=0
        elif command -v docker >/dev/null 2>&1 && ! is_ci; then
            BANANAWRT_USE_DOCKER=1
        else
            BANANAWRT_USE_DOCKER=0
        fi
    fi

    # Runner-type hint for banner (CI detected separately)
    local runner_type='local'
    if is_ci; then
        runner_type="${RUNNER_NAME:-CI}"
    fi

    show_banner "$BANANAWRT_VERSION_LINE" "$BANANAWRT_TRACK" \
                "$BANANAWRT_IMMORTALWRT_VER" "$BANANAWRT_ARCH" "$runner_type"
    show_config_summary

    BANANAWRT_TOTAL_START="$(date +%s)"

    # Re-exec inside container if requested and not already inside one
    if [[ "$BANANAWRT_USE_DOCKER" == "1" ]] && ! in_container; then
        display_title "Launching container"
        check_docker
        docker_pull
        # Rebuild argv for container invocation (preserve everything except --docker)
        local -a fwd_args=()
        [[ -n "$BANANAWRT_VERSION_LINE" ]]    && fwd_args+=( --version-line "$BANANAWRT_VERSION_LINE" )
        [[ -n "$BANANAWRT_TRACK" ]]           && fwd_args+=( --track "$BANANAWRT_TRACK" )
        [[ -n "$BANANAWRT_ARCH" ]]            && fwd_args+=( --arch "$BANANAWRT_ARCH" )
        [[ -n "$BANANAWRT_IMMORTALWRT_VER" ]] && fwd_args+=( --immortalwrt-version "$BANANAWRT_IMMORTALWRT_VER" )
        [[ -n "$BANANAWRT_JOBS" ]]            && fwd_args+=( --jobs "$BANANAWRT_JOBS" )
        [[ -n "$BANANAWRT_STAGE" ]]           && fwd_args+=( --stage "$BANANAWRT_STAGE" )
        [[ -n "$BANANAWRT_CLEAN" ]]           && fwd_args+=( --clean="$BANANAWRT_CLEAN" )
        [[ "$BANANAWRT_KEEP_SOURCE" == "1" ]] && fwd_args+=( --keep-source )
        [[ "${BANANAWRT_DEBUG:-0}" == "1" ]]  && fwd_args+=( --verbose )
        [[ "$BANANAWRT_CI" == "1" ]]          && fwd_args+=( --ci )
        docker_run_stage "${fwd_args[@]}"
        return $?
    fi

    # Native build path
    if [[ "$BANANAWRT_USE_DOCKER" == "0" && "$BANANAWRT_CI" != "1" ]]; then
        # In non-CI host mode, warn about missing tools but don't hard-fail on
        # every apt package; we rely on the user running setup-env.sh themselves.
        :
    fi

    # Optional clean
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
