#!/usr/bin/env bash
#
# lib/prereqs.sh — validate host toolchain + CI secrets.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me> — MIT.
#

# check_binary <name> <install_hint>
check_binary() {
    local name="$1"
    local hint="${2:-}"
    if ! command -v "$name" >/dev/null 2>&1; then
        display_alert err "Missing required tool: $name" "${hint:-install it and retry}"
        return 1
    fi
    return 0
}

# check_dialog - flag missing dialog without installing (CI never needs it)
check_dialog() {
    if command -v dialog >/dev/null 2>&1; then
        return 0
    fi
    if is_ci; then
        return 1
    fi
    display_alert warn "dialog is not installed — interactive menu disabled" \
        "install with: sudo apt-get install dialog"
    return 1
}

# ensure_workspace - create workspace dir if it doesn't exist
ensure_workspace() {
    : "${BANANAWRT_WORKSPACE:=$BANANAWRT_ROOT/workspace}"
    if [[ ! -d "$BANANAWRT_WORKSPACE" ]]; then
        display_alert info "Creating workspace directory" "$BANANAWRT_WORKSPACE"
        mkdir -p "$BANANAWRT_WORKSPACE"
    fi
}

# check_host_requirements - minimal toolchain to parse versions.json + run git
check_host_requirements() {
    local missing=0
    check_binary jq   'sudo apt-get install jq'   || missing=$((missing + 1))
    check_binary git  'sudo apt-get install git'  || missing=$((missing + 1))
    check_binary curl 'sudo apt-get install curl' || missing=$((missing + 1))
    check_binary make 'sudo apt-get install build-essential' || missing=$((missing + 1))
    if (( missing > 0 )); then
        exit_with_error "$missing prerequisite(s) missing — see hints above"
    fi
}

# check_build_host_requirements - full build toolchain sanity
check_build_host_requirements() {
    local missing=0
    local bin
    for bin in bison flex gcc g++ patch python3 unzip wget xxd zstd; do
        check_binary "$bin" 'run .github/scripts/setup-env.sh setup' || missing=$((missing + 1))
    done
    if (( missing > 0 )); then
        exit_with_error "Build environment incomplete — run .github/scripts/setup-env.sh setup"
    fi
}

# check_ci_requirements - credentials needed for FTP upload + GitHub release
check_ci_requirements() {
    local missing=0
    local var
    for var in FTP_HOST FTP_USERNAME FTP_PASSWORD; do
        if [[ -z "${!var:-}" ]]; then
            display_alert err "Missing env var for CI upload: $var"
            missing=$((missing + 1))
        fi
    done
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        display_alert err "Missing env var for GitHub Release: GITHUB_TOKEN"
        missing=$((missing + 1))
    fi
    if (( missing > 0 )); then
        exit_with_error "$missing CI secret(s) missing — aborting"
    fi
}
