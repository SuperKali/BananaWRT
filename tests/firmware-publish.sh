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
    printf '%s\n' "$EXISTING_INDEX"
}
lftp() {
    local index="$BANANAWRT_WORKSPACE/ftp-upload/bananawrt/firmware/firmware-index.json"
    cp "$index" "$BANANAWRT_WORKSPACE/uploaded-index.json"
}
gh() {
    touch "$BANANAWRT_WORKSPACE/gh-called"
    [[ $1 = release && $2 = view ]]
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
    [[ ! -e $work/$name/uploaded-index.json && ! -e $work/$name/gh-called ]]
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
