#!/usr/bin/env bash
# Dispatch packages only after the exact SDKs from this run are visible on the CDN.
set -euo pipefail

base=https://repo.superkali.me/bananawrt/sdk
attempts=${SDK_POLL_ATTEMPTS:-12}
interval=${SDK_POLL_SECONDS:-10}
: "${SDK_RECEIPT:?SDK build receipt is required}"
: "${SDK_VERSIONS:?Expected SDK versions are required}"

rows=$(jq -er --arg requested "$SDK_VERSIONS" '
    select(type == "array" and length > 0)
    | select((map(.version) | unique) == ($requested | split(",") | unique))
    | select(all(group_by(.version)[]; (map(.architecture) | sort) == ["ARM64", "X64"]))
    | .[]
    | [.version, .architecture, .filename, .sha256, .size] | @tsv
' <<< "$SDK_RECEIPT")

fetch() {
    curl --proto '=https' --fail --silent --show-error --max-time 20 \
        --header 'Cache-Control: no-cache' "$@"
}

ready() {
    local index version arch filename digest size url info
    index=$(fetch "$base/sdk-master-index.json") || return 1
    while IFS=$'\t' read -r version arch filename digest size; do
        url="$base/$arch/$version/"
        jq -e --arg v "$version" --arg a "$arch" --arg url "$url" '
            .versions[$v].architectures[$a] |
            .sdk_url == $url and .info_url == ($url + "sdk-info.json")
                and .config_url == ($url + "config.buildinfo")
        ' <<< "$index" > /dev/null || return 1
        info=$(fetch "${url}sdk-info.json") || return 1
        jq -e --arg v "$version" --arg a "$arch" --arg f "$filename" --arg sha "$digest" \
            --arg url "$url" --arg size "$size" '
            .version == $v and .architecture == $a and .filename == $f and .sha256 == $sha
                and .download_url == ($url + $f) and (.size | tostring) == $size
        ' <<< "$info" > /dev/null || return 1
        fetch --head "${url}config.buildinfo" > /dev/null || return 1
        fetch --head "${url}${filename}" > /dev/null || return 1
    done <<< "$rows"
}

for ((i=1; i<=attempts; i++)); do
    if ready; then
        payload=$(jq -nc --arg versions "$SDK_VERSIONS" \
            '{ref:"main",inputs:{versions:$versions,host_arch:"AUTO"}}')
        result=$(gh api --method POST -H 'X-GitHub-Api-Version: 2026-03-10' \
            repos/SuperKali/openwrt-packages/actions/workflows/bananawrt-builder.yml/dispatches \
            --input - <<< "$payload")
        run_id=$(jq -er '.workflow_run_id | numbers | select(. > 0 and floor == .)' <<< "$result")
        printf 'run_id=%s\n' "$run_id" >> "$GITHUB_OUTPUT"
        printf 'Dispatched packages: https://github.com/SuperKali/openwrt-packages/actions/runs/%s\n' "$run_id"
        exit 0
    fi
    printf 'SDKs not yet visible on the CDN (attempt %d/%d)\n' "$i" "$attempts"
    if ((i < attempts)); then sleep "$interval"; fi
done
printf '::error::Published SDKs not visible for %s; packages were not dispatched\n' "$SDK_VERSIONS" >&2
exit 1
