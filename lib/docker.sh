#!/usr/bin/env bash
#
# File: lib/docker.sh
# Description: Re-exec compile.sh inside the BananaWRT builder container.
#              Handles image pulling, multi-arch selection, and volume mounts.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me>
#
# This is free software, licensed under the MIT License.
#

: "${BANANAWRT_DOCKER_IMAGE_DEFAULT:=ghcr.io/superkali/bananawrt-builder:latest}"

# docker_image - resolve the effective image reference
docker_image() {
    printf '%s' "${BANANAWRT_DOCKER_IMAGE:-$BANANAWRT_DOCKER_IMAGE_DEFAULT}"
}

# docker_platform - map BANANAWRT_ARCH to docker platform string
docker_platform() {
    case "${BANANAWRT_ARCH:-ARM64}" in
        ARM64) printf 'linux/arm64' ;;
        X64)   printf 'linux/amd64' ;;
        *)     printf 'linux/amd64' ;;
    esac
}

# docker_pull - pull the builder image (idempotent)
docker_pull() {
    local image platform
    image="$(docker_image)"
    platform="$(docker_platform)"
    substep "Pulling container image ($platform)"
    if docker pull --platform "$platform" "$image" >/dev/null 2>&1; then
        substep_done "$image"
        return 0
    else
        substep_fail 'pull failed'
        exit_with_error "Unable to pull $image for $platform"
    fi
}

# docker_run_stage <compile.sh args...>
#   Re-executes this script inside the container with BANANAWRT_IN_CONTAINER=1
#   and the repo mounted at /build.
docker_run_stage() {
    local image platform
    image="$(docker_image)"
    platform="$(docker_platform)"

    local -a env_pass=()
    local v
    for v in BANANAWRT_DEBUG BANANAWRT_LOG_FILE BANANAWRT_CI BANANAWRT_JOBS \
             BANANAWRT_KEEP_SOURCE BANANAWRT_CLEAN BANANAWRT_ARCH \
             BANANAWRT_IMMORTALWRT_VER BANANAWRT_VERSION_LINE BANANAWRT_TRACK \
             FTP_HOST FTP_USERNAME FTP_PASSWORD GITHUB_TOKEN \
             GITHUB_REF GITHUB_SHA GITHUB_REPOSITORY; do
        if [[ -n "${!v:-}" ]]; then
            env_pass+=( -e "$v=${!v}" )
        fi
    done
    env_pass+=( -e 'BANANAWRT_IN_CONTAINER=1' )
    env_pass+=( -e 'TERM=xterm-256color' )

    # Workspace volume: keep build outputs on the host for incremental builds.
    : "${BANANAWRT_WORKSPACE:=$BANANAWRT_ROOT/workspace}"
    mkdir -p "$BANANAWRT_WORKSPACE"

    local -a opts=(
        --rm
        --platform "$platform"
        --workdir /build
        -v "$BANANAWRT_ROOT:/build"
        -v "$BANANAWRT_WORKSPACE:/build/workspace"
        -e "BANANAWRT_ROOT=/build"
        -e "BANANAWRT_WORKSPACE=/build/workspace"
    )

    # Interactive TTY when a user is driving the build
    if [[ -t 0 && -t 1 ]]; then
        opts+=( -it )
    fi

    docker run "${opts[@]}" "${env_pass[@]}" "$image" \
        /build/compile.sh --no-docker "$@"
}
