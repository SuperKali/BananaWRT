#!/usr/bin/env bash
# Offline regression test for the Dashboard patch's feed update lifecycle.
set -euo pipefail

builder=$(cd "$(dirname "$0")/.." && pwd)
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
export BANANAWRT_ROOT="$root/builder" BANANAWRT_IMMORTAL_DIR="$root/workspace"
export BANANAWRT_VERSION_LINE=v25.12-mtk-vendor BANANAWRT_TRACK=mtk-vendor BANANAWRT_FEED_BRANCH=fixture
export feed="$BANANAWRT_IMMORTAL_DIR/feeds/luci"
patch_file="$BANANAWRT_ROOT/patch/feeds/$BANANAWRT_VERSION_LINE/$BANANAWRT_TRACK/luci/010-dashboard-openwrt2020.patch"
applied="$BANANAWRT_IMMORTAL_DIR/feeds/.bananawrt-luci-dashboard.patch"
mkdir -p "$feed" "$BANANAWRT_IMMORTAL_DIR/scripts" "$BANANAWRT_ROOT/scripts/builder" "${patch_file%/*}"

# The fixture has a staged clean baseline, without requiring a Git commit.
git -C "$feed" init -q
printf 'a\nb\nstock\nc\nd\ne\nupstream-1\n' > "$feed/dashboard.css"
printf 'untouched\n' > "$feed/other.css"
git -C "$feed" add .
make_patch() {
    sed "s/stock/$1/" "$feed/dashboard.css" > "$feed/modified"
    mv "$feed/modified" "$feed/dashboard.css"
    git -C "$feed" diff -U1 -- dashboard.css > "$patch_file"
    git -C "$feed" checkout -- dashboard.css
}
make_patch design-1

printf '#!/bin/sh\nexit 0\n' > "$BANANAWRT_ROOT/scripts/builder/custom-repository.sh"
cat > "$BANANAWRT_IMMORTAL_DIR/scripts/feeds" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$1" >> events
case "$1" in
    update)
        # A fast-forward touching this file requires the old patch gone.
        git -C "$feed" diff --quiet -- dashboard.css
        if [[ -n "${update_upstream:-}" ]]; then
            sed -i 's/upstream-1/upstream-2/' "$feed/dashboard.css"
            git -C "$feed" add dashboard.css
        fi
        ;;
    install) grep -Fxq "$expected_design" "$feed/dashboard.css" ;;
    *) exit 1 ;;
esac
EOF
chmod +x "$BANANAWRT_ROOT/scripts/builder/custom-repository.sh" "$BANANAWRT_IMMORTAL_DIR/scripts/feeds"

C_DIM='' C_RESET=''
display_subheader() { :; }
substep() { :; }
substep_done() { :; }
substep_fail() { printf '%s\n' "$*" >&2; }
exit_with_error() { printf '%s\n' "$*" >&2; exit 1; }
source "$builder/stages/03-feeds.sh"

export expected_design=design-1
stage_feeds
cmp "$patch_file" "$applied"

# Remove the receipt to cover migrating from workspaces patched by the old builder.
rm "$applied"
stage_feeds
cmp "$patch_file" "$applied"

# The next builder ships a revised patch. Reverse the old one, not the new one.
cp "$patch_file" "$root/old.patch"
git -C "$feed" apply -R "$root/old.patch"
make_patch design-2
git -C "$feed" apply "$root/old.patch"
printf 'local edit\n' > "$feed/other.css"
export expected_design=design-2 update_upstream=yes
stage_feeds
unset update_upstream
cmp "$patch_file" "$applied"
grep -Fxq upstream-2 "$feed/dashboard.css"
grep -Fxq 'local edit' "$feed/other.css"

# Do not reset an edited patch in place, or try to pull before reporting it.
sed -i 's/design-2/local-design/' "$feed/dashboard.css"
if (stage_feeds) > "$root/diverged.log" 2>&1; then
    printf 'FAIL: accepted a diverged patch\n' >&2
    exit 1
fi
grep -Fq 'previous Dashboard patch no longer matches' "$root/diverged.log"
grep -Fxq local-design "$feed/dashboard.css"
diff -u <(printf 'update\ninstall\n%.0s' {1..3}) "$BANANAWRT_IMMORTAL_DIR/events"

# Leave a patch already present in the upstream/index tree untouched.
sed -i 's/local-design/design-2/' "$feed/dashboard.css"
git -C "$feed" add dashboard.css
stage_feeds
[[ ! -e "$applied" ]]
git -C "$feed" diff --quiet -- dashboard.css

# A different channel neither reverses nor applies the Dashboard patch.
git -C "$feed" apply --index -R "$patch_file"
BANANAWRT_VERSION_LINE=v25.12 BANANAWRT_TRACK=stable expected_design=stock stage_feeds
git -C "$feed" diff --quiet -- dashboard.css
printf 'PASS: cold, reused, revised, diverged, upstream and non-target feeds\n'
