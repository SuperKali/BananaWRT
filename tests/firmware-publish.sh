#!/usr/bin/env bash
# Exercise the real publish stage with local inputs and no network clients.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
source "$root/stages/07-package.sh"

display_subheader() { :; }; display_alert() { :; }
substep() { :; }; substep_done() { :; }; substep_skip() { :; }; substep_fail() { :; }
is_ci() { return 0; }; check_ci_requirements() { :; }
capitalize() { printf '%s\n' "$1"; }
exit_with_error() { printf '%s\n' "$*" >&2; exit 1; }
curl() {
    if [[ $FETCH_INDEX == fail ]]; then return 22; fi
    local uploaded="$BANANAWRT_WORKSPACE/uploaded-index.json"
    local count_file="$BANANAWRT_WORKSPACE/fetches"
    local count=$(( $(cat "$count_file" 2>/dev/null || echo 0) + 1 ))
    printf '%s\n' "$count" > "$count_file"
    # race: a concurrent publisher overwrites the first upload with its older copy
    if [[ $FETCH_INDEX == race && $count == 3 ]]; then
        printf '%s\n' "$EXISTING_INDEX"
    elif [[ -e $uploaded ]]; then
        cat "$uploaded"
    else
        printf '%s\n' "$EXISTING_INDEX"
    fi
}
lftp() {
    if [[ $2 == *mirror* ]]; then
        [[ ! -e $BANANAWRT_WORKSPACE/ftp-upload/bananawrt/firmware/firmware-index.json ]]
        touch "$BANANAWRT_WORKSPACE/mirror-called"
    elif [[ $2 == *put* ]]; then
        cp "$BANANAWRT_WORKSPACE/firmware-index.json" "$BANANAWRT_WORKSPACE/uploaded-index.json"
        echo put >> "$BANANAWRT_WORKSPACE/puts"
    fi
}
gh() {
    touch "$BANANAWRT_WORKSPACE/gh-called"
    [[ $1 = release && $2 = view ]]
}
git() {
    case "$3" in
        fetch) [[ $CURRENT_CONFIG != fetch-failure ]] ;;
        show) printf '%s\n' "$CURRENT_CONFIG" ;;
        *) return 1 ;;
    esac
}

run_case() (
    FETCH_INDEX=$2
    EXISTING_INDEX=$3
    BANANAWRT_ROOT=$root
    BANANAWRT_WORKSPACE="$work/$1"
    BANANAWRT_IMMORTAL_DIR="$BANANAWRT_WORKSPACE/tree"
    BANANAWRT_VERSION_LINE=v25.12-mtk-vendor
    BANANAWRT_TRACK=mtk-vendor
    BANANAWRT_RELEASE_DATE=test-build
    BANANAWRT_IMMORTALWRT_VER=25.12-linkup
    BANANAWRT_FEED_COMMIT=${4:-}
    BANANAWRT_INDEX_SETTLE=0
    CURRENT_CONFIG=${5:-}
    if [[ -n "$BANANAWRT_FEED_COMMIT" ]]; then
        BANANAWRT_VERSION_LINE=v25.12 BANANAWRT_TRACK=stable BANANAWRT_IMMORTALWRT_VER=25.12.3
    fi
    GITHUB_SHA=fixture-builder
    FTP_USERNAME=fixture FTP_PASSWORD=fixture FTP_HOST=fixture.invalid
    local target="$BANANAWRT_IMMORTAL_DIR/bin/targets/mediatek/filogic"
    mkdir -p "$target"
    printf '%s\n' 'CONFIG_TARGET_mediatek_filogic_DEVICE_test=y' > "$BANANAWRT_IMMORTAL_DIR/.config"
    printf '%s\n' 'fixture, not firmware' > "$target/test.itb"
    stage_package
)

blocked() {
    local name=$1 fetch=$2 json=$3 message=$4
    if run_case "$name" "$fetch" "$json" >"$work/$name.log" 2>&1; then
        printf 'FAIL: %s did not block publishing\n' "$name" >&2
        exit 1
    fi
    grep -Fq "$message" "$work/$name.log"
    [[ ! -e $work/$name/uploaded-index.json && ! -e $work/$name/mirror-called && ! -e $work/$name/gh-called ]]
    printf 'PASS: %s blocked before FTP and GitHub\n' "$name"
}

valid='{"versions":{"v24.10":{"status":"eol","tracks":{}},"v25.12":{"status":"active","tracks":{"stable":{"builds":[{"tag":"stable-existing"}]}}},"v25.12-mtk-vendor":{"status":"active","tracks":{"mtk-vendor":{"builds":[{"tag":"vendor-existing"}]}}}}}'
run_case success ok "$valid"
jq -e '
    (.versions | keys) == ["v24.10", "v25.12", "v25.12-mtk-vendor"] and
    .versions["v24.10"].status == "eol" and
    .versions["v25.12"].tracks.stable.builds[0].tag == "stable-existing" and
    ([.versions["v25.12-mtk-vendor"].tracks["mtk-vendor"].builds[].tag] == ["test-build", "vendor-existing"])
' "$work/success/uploaded-index.json" >/dev/null
printf 'PASS: valid index preserves old builds and all channels\n'
[[ $(wc -l < "$work/success/puts") == 1 ]]
printf 'PASS: index uploaded once, after the firmware mirror\n'

run_case race race "$valid"
[[ $(wc -l < "$work/race/puts") == 2 ]]
jq -e '[.versions["v25.12-mtk-vendor"].tracks["mtk-vendor"].builds[].tag] == ["test-build", "vendor-existing"]' \
    "$work/race/uploaded-index.json" >/dev/null
printf 'PASS: build overwritten by a concurrent publisher is merged again once\n'

full='{"versions":{"v25.12-mtk-vendor":{"status":"active","tracks":{"mtk-vendor":{"builds":[{"tag":"test-build"},{"tag":"b1"},{"tag":"b2"},{"tag":"b3"},{"tag":"b4"}]}}}}}'
run_case full ok "$full"
jq -e '[.versions["v25.12-mtk-vendor"].tracks["mtk-vendor"].builds[].tag] == ["test-build", "b1", "b2", "b3"]' \
    "$work/full/uploaded-index.json" >/dev/null
[[ $(cat "$work/full/builds_to_remove.txt") == b4 ]]
printf 'PASS: same build merged twice stays once; only the 5th build is removed\n'
blocked download-failure fail '' 'Could not fetch the existing firmware index'
for name in empty malformed empty-versions missing-tracks broken-builds bad-tag two-documents; do
    case "$name" in
        empty) json='' ;;
        malformed) json='<html>Upstream unavailable</html>' ;;
        empty-versions) json='{"versions":{}}' ;;
        missing-tracks) json='{"versions":{"v25.12":{}}}' ;;
        broken-builds) json='{"versions":{"v25.12":{"tracks":{"stable":{"builds":{}}}}}}' ;;
        bad-tag) json='{"versions":{"v25.12":{"tracks":{"stable":{"builds":[{"tag":"../other-dir"}]}}}}}' ;;
        two-documents) json="$valid $valid" ;;
    esac
    blocked "$name" ok "$json" 'Existing firmware index is empty or invalid'
done

printf -v pin '%040d' 1
current='{"status":"active","branch":"25.12.3","tracks":["stable"]}'
run_case current-auto ok "$valid" "$pin" "$current"
jq -e --arg pin "$pin" '.packages_commit == $pin' \
    "$work/current-auto/tree/bin/targets/mediatek/filogic/firmware-info.json" >/dev/null
[[ -e $work/current-auto/uploaded-index.json ]]
printf 'PASS: current automatic firmware records the deployed package commit\n'
for name in newer-version changed-track fetch-failure; do
    case "$name" in
        newer-version) config='{"status":"active","branch":"25.12.4","tracks":["stable"]}' ;;
        changed-track) config='{"status":"active","branch":"25.12.3","tracks":["oldstable"]}' ;;
        fetch-failure) config=fetch-failure ;;
    esac
    if run_case "$name" ok "$valid" "$pin" "$config" >"$work/$name.log" 2>&1; then
        printf 'FAIL: %s did not block publishing\n' "$name" >&2
        exit 1
    fi
    grep -Fq 'Cannot confirm this firmware version is still current' "$work/$name.log"
    [[ ! -e $work/$name/uploaded-index.json && ! -e $work/$name/gh-called ]]
    printf 'PASS: %s blocked automatic firmware publication\n' "$name"
done
