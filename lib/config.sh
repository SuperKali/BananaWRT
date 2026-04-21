#!/usr/bin/env bash
#
# File: lib/config.sh
# Description: Read and validate the per-version-line config (versions.json,
#              .config files, patch directories) used by the build pipeline.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me>
#
# This is free software, licensed under the MIT License.
#

# Environment variables set by this module:
#   BANANAWRT_VERSION_LINE       e.g. "v25.12"
#   BANANAWRT_TRACK              e.g. "nightly"
#   BANANAWRT_STATUS             e.g. "active" | "eol"
#   BANANAWRT_IMMORTALWRT_VER    e.g. "25.12.0-rc2"
#   BANANAWRT_FEED_BRANCH        e.g. "main"
#   BANANAWRT_CONFIG_FILE        e.g. "config/v25.12/nightly/.config"
#   BANANAWRT_VERSION_JSON       e.g. "config/v25.12/version.json"
#   BANANAWRT_VERSION_LINE_TAG   short numeric form, e.g. "25.12"

# list_version_lines - print one version line per row (active only)
list_version_lines() {
    local vf
    for vf in "$BANANAWRT_ROOT"/config/*/version.json; do
        [[ -f "$vf" ]] || continue
        local status line
        status="$(jq -r '.status' "$vf")"
        line="$(jq -r '.version_line' "$vf")"
        if [[ "$status" == "active" ]]; then
            printf '%s\n' "$line"
        fi
    done
}

# list_tracks_for <version_line> - print supported tracks, newline-separated
list_tracks_for() {
    local vl="$1"
    local vf="$BANANAWRT_ROOT/config/$vl/version.json"
    [[ -f "$vf" ]] || return 1
    jq -r '.tracks[]' "$vf"
}

# validate_version_track <version_line> <track> → sets all BANANAWRT_* vars
#   Returns non-zero (and calls exit_with_error) on failure.
validate_version_track() {
    local vl="$1" track="$2"
    local vf="$BANANAWRT_ROOT/config/$vl/version.json"

    if [[ ! -f "$vf" ]]; then
        exit_with_error "Unknown version line: $vl (no $vf)"
    fi

    # Validate track is listed for this version line
    if ! jq -e --arg t "$track" '.tracks | index($t)' "$vf" > /dev/null; then
        local available
        available="$(jq -r '.tracks | join(", ")' "$vf")"
        exit_with_error "Track '$track' not available for $vl (available: $available)"
    fi

    local config_file="$BANANAWRT_ROOT/config/$vl/$track/.config"
    if [[ ! -f "$config_file" ]]; then
        exit_with_error "Config file missing: $config_file"
    fi

    BANANAWRT_VERSION_LINE="$vl"
    BANANAWRT_TRACK="$track"
    BANANAWRT_STATUS="$(jq -r '.status' "$vf")"
    BANANAWRT_IMMORTALWRT_VER="${BANANAWRT_IMMORTALWRT_VER:-$(jq -r '.branch' "$vf")}"
    BANANAWRT_FEED_BRANCH="$(jq -r '.feed_branch' "$vf")"
    BANANAWRT_CONFIG_FILE="$config_file"
    BANANAWRT_VERSION_JSON="$vf"
    BANANAWRT_VERSION_LINE_TAG="${vl#v}"

    if [[ "$BANANAWRT_STATUS" == "eol" ]]; then
        display_alert warn "Version line $vl is marked EOL — build will proceed but is unsupported"
    fi

    return 0
}

# resolved_paths - populate derived paths based on BANANAWRT_WORKSPACE
resolved_paths() {
    : "${BANANAWRT_WORKSPACE:=$BANANAWRT_ROOT/workspace}"
    BANANAWRT_IMMORTAL_DIR="$BANANAWRT_WORKSPACE/immortalwrt"
    BANANAWRT_CACHE_DIR="$BANANAWRT_WORKSPACE/cache"
    BANANAWRT_DL_DIR="$BANANAWRT_IMMORTAL_DIR/dl"
    BANANAWRT_CCACHE_DIR="$BANANAWRT_IMMORTAL_DIR/.ccache"
    BANANAWRT_STAGING_DIR="$BANANAWRT_IMMORTAL_DIR/staging_dir"
    BANANAWRT_FEEDS_DIR="$BANANAWRT_IMMORTAL_DIR/feeds"
}

# show_config_summary - print resolved config to the user
show_config_summary() {
    display_subheader "Resolved configuration"
    printf '  %-24s %s\n' 'Version line'         "$BANANAWRT_VERSION_LINE"
    printf '  %-24s %s\n' 'Track'                "$BANANAWRT_TRACK"
    printf '  %-24s %s\n' 'Status'               "$BANANAWRT_STATUS"
    printf '  %-24s %s\n' 'ImmortalWRT version'  "$BANANAWRT_IMMORTALWRT_VER"
    printf '  %-24s %s\n' 'Feed branch'          "$BANANAWRT_FEED_BRANCH"
    printf '  %-24s %s\n' 'Config file'          "${BANANAWRT_CONFIG_FILE#$BANANAWRT_ROOT/}"
    printf '  %-24s %s\n' 'Workspace'            "$BANANAWRT_WORKSPACE"
    printf '  %-24s %s\n' 'ImmortalWRT tree'     "$BANANAWRT_IMMORTAL_DIR"
}

# packages_from_version_json - print configured additional_pack packages
packages_from_version_json() {
    [[ -f "$BANANAWRT_VERSION_JSON" ]] || return 1
    jq -r '.packages[]?' "$BANANAWRT_VERSION_JSON"
}
