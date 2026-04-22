#!/usr/bin/env bash
#
# lib/banner.sh — ASCII banner + build context summary + --help.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me> — MIT.
#

# show_banner <version_line> <track> <immortalwrt_version> <arch> <runner_type>
show_banner() {
    local version_line="${1:-?}"
    local track="${2:-?}"
    local immortalwrt_version="${3:-?}"
    local arch="${4:-?}"
    local runner_type="${5:-local}"

    local mode
    if is_ci; then
        mode="CI"
    else
        mode="Local"
    fi

    local docker_tag="${BANANAWRT_DOCKER_IMAGE:-disabled}"
    if in_container; then
        docker_tag="running inside container"
    fi

    printf '\n'
    printf '%b' "$C_BOLD$C_CYAN"
    cat <<'BANANA'
    ____                               _       ______  ______
   / __ )____ _____  ____ _____  ____ | |     / / __ \/_  __/
  / __  / __ `/ __ \/ __ `/ __ \/ __ `/ | /| / / /_/ / / /
 / /_/ / /_/ / / / / /_/ / / / / /_/ /| |/ |/ / _, _/ / /
/_____/\__,_/_/ /_/\__,_/_/ /_/\__,_/ |__/|__/_/ |_| /_/
BANANA
    printf '%b          BananaWRT - The Ultimate Firmware Builder          %b\n' \
        "$C_BOLD$C_YELLOW" "$C_RESET"
    printf '\n'
    printf '  %bVersion line%b   %s  %b(track: %s)%b\n' \
        "$C_BOLD$C_CYAN" "$C_RESET" "$version_line" "$C_DIM" "$track" "$C_RESET"
    printf '  %bImmortalWRT%b    %s\n' \
        "$C_BOLD$C_CYAN" "$C_RESET" "$immortalwrt_version"
    printf '  %bTarget%b         Banana Pi R3 Mini  %b(mediatek/filogic, MT7986A)%b\n' \
        "$C_BOLD$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
    printf '  %bArchitecture%b   %s  %b(%s runner)%b\n' \
        "$C_BOLD$C_CYAN" "$C_RESET" "$arch" "$C_DIM" "$runner_type" "$C_RESET"
    printf '  %bMode%b           %s\n' \
        "$C_BOLD$C_CYAN" "$C_RESET" "$mode"
    printf '  %bContainer%b      %s\n' \
        "$C_BOLD$C_CYAN" "$C_RESET" "$docker_tag"
    printf '\n'
}

# show_help - usage / argument reference
show_help() {
    cat <<EOF
${C_BOLD}BananaWRT compile.sh${C_RESET} — firmware build orchestrator

${C_BOLD}USAGE${C_RESET}
  compile.sh [OPTIONS]                 run interactive menu (dialog)
  compile.sh --version-line <vl> --track <t> [OPTIONS]
  compile.sh --stage <name> [OPTIONS]  run a single pipeline stage
  compile.sh --help                    this message

${C_BOLD}REQUIRED ARGUMENTS${C_RESET}
  --version-line, -V <v24.10|v25.12>   ImmortalWRT major.minor line
  --track, -t <stable|nightly>         Release track

${C_BOLD}OPTIONAL ARGUMENTS${C_RESET}
  --immortalwrt-version <x.y.z>        Pin a specific ImmortalWRT version
                                       (default: read from config/<vl>/version.json)
  --arch, -a <ARM64|X64>               Target runner architecture (default: ARM64)
  --jobs, -j <N>                       Parallel make jobs (default: nproc)
  --docker                             Run inside the BananaWRT builder container
  --no-docker                          Use the host environment as-is
  --image <ref>                        Override container image reference
                                       (default: ghcr.io/superkali/bananawrt-builder:latest)
  --ci                                 Enable CI mode (FTP upload, GitHub release)
  --no-package                         Stop after stage 6 (compile); used by SDK workflow
  --stage <name>                       Run only the named stage
                                       (clone|patch|feeds|config|download|compile|package)
  --keep-source                        Skip cleanup of ${C_DIM}\$WORKSPACE/immortalwrt${C_RESET} on exit
  --clean                              Remove build_dir/ before starting (keep dl/)
  --clean=all                          Full wipe (dl/, build_dir/, staging_dir/)
  --verbose                            Enable verbose command output (BANANAWRT_DEBUG=1)
  --help, -h                           Show this help

${C_BOLD}ENVIRONMENT${C_RESET}
  BANANAWRT_WORKSPACE                  Where the ImmortalWRT tree lives
                                       (default: \$(pwd)/workspace)
  BANANAWRT_LOG_FILE                   Mirror build output to this path
  BANANAWRT_DEBUG=1                    Verbose mode
  BANANAWRT_IN_CONTAINER=1             Force "running inside container" mode
  NO_COLOR=1                           Disable color output
  FTP_HOST / FTP_USERNAME / FTP_PASSWORD   Required for --ci upload
  GITHUB_TOKEN                         Required for --ci release

${C_BOLD}EXAMPLES${C_RESET}
  ${C_DIM}# Interactive build (picks version, track, arch via dialog)${C_RESET}
  ./compile.sh

  ${C_DIM}# Local build of v25.12 nightly using container${C_RESET}
  ./compile.sh --version-line v25.12 --track nightly --docker

  ${C_DIM}# CI invocation (what the workflow runs)${C_RESET}
  ./compile.sh --ci --version-line v25.12 --track nightly --arch ARM64

  ${C_DIM}# Run just the compile stage (incremental dev)${C_RESET}
  ./compile.sh --stage compile --version-line v25.12 --track nightly
EOF
}
