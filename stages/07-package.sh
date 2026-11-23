#!/usr/bin/env bash
#
# stages/07-package.sh — collect firmware + firmware-info.json, and in CI
#                        mode upload via FTP + create the GitHub Release.
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me> — MIT.
#

# Print the CDN firmware index; fails when it cannot be downloaded.
fetch_firmware_index() {
    curl --fail --silent --show-error --connect-timeout 15 --max-time 60 --retry 2 \
        --header 'Cache-Control: no-cache' \
        'https://repo.superkali.me/bananawrt/firmware/firmware-index.json'
}

# Succeed when $1 is one firmware index document with safe build tags.
firmware_index_valid() {
    jq -es '
        length == 1 and (.[0].versions |
            type == "object" and length > 0 and
            all(.[]; type == "object" and (.tracks |
                type == "object" and all(.[]; type == "object" and (.builds |
                    type == "array" and all(.[]; type == "object" and (.tag |
                        type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$")
                    ))
                ))
            ))
        )' <<< "$1" >/dev/null
}

# Merge build $2 into index $1, first in this channel. Sets merged_full
# (every build, for the FTP cleanup) and merged_index (at most 4 builds).
# Merging the same build twice leaves one entry.
merge_firmware_index() {
    merged_full="$(
        jq --arg vl "$BANANAWRT_VERSION_LINE" --arg track "$BANANAWRT_TRACK" \
           --arg latest "$BANANAWRT_RELEASE_DATE" --arg iwrt "$BANANAWRT_IMMORTALWRT_VER" \
           --argjson build "$2" '
            .versions[$vl] //= {"status":"active","tracks":{}} |
            .versions[$vl].tracks[$track] //= {"latest_build":"","immortalwrt_version":"","builds":[]} |
            .versions[$vl].tracks[$track].latest_build = $latest |
            .versions[$vl].tracks[$track].immortalwrt_version = $iwrt |
            .versions[$vl].tracks[$track].builds =
                ([$build] + (.versions[$vl].tracks[$track].builds | map(select(.tag != $build.tag))))
        ' <<< "$1"
    )" || return 1
    merged_index="$(
        jq --arg vl "$BANANAWRT_VERSION_LINE" --arg track "$BANANAWRT_TRACK" \
            '.versions[$vl].tracks[$track].builds |= .[:4]' <<< "$merged_full"
    )"
}

stage_package() {
    display_subheader "Package firmware artefacts"

    local target_dir
    # `|| true` neutralises SIGPIPE (141) from head closing stdin under pipefail.
    target_dir="$(ls -d "$BANANAWRT_IMMORTAL_DIR"/bin/targets/*/* 2>/dev/null | head -n1 || true)"
    if [[ -z "$target_dir" || ! -d "$target_dir" ]]; then
        exit_with_error "No firmware target directory found under bin/targets/*"
    fi

    # Prune artefacts we never publish (SDK, imagebuilder, toolchain)
    substep "Pruning SDK / toolchain / imagebuilder artefacts"
    (
        cd "$target_dir"
        rm -rf packages 2>/dev/null
        rm -f -- *-sdk-* *-imagebuilder-* *-toolchain-* llvm-bpf-* 2>/dev/null
    )
    substep_done

    substep "Computing sha256 checksums"
    local files_json='{}'
    local fname sha size
    while IFS= read -r -d '' fname; do
        sha="$(sha256sum "$fname" | awk '{print $1}')"
        size="$(stat -c%s "$fname")"
        files_json="$(jq -nc --argjson obj "$files_json" \
                           --arg k "$(basename "$fname")" \
                           --arg sha "$sha" \
                           --argjson sz "$size" \
                           '$obj + {($k): {sha256:$sha, size:$sz}}')"
    done < <(find "$target_dir" -maxdepth 1 -type f -print0)
    substep_done

    # Kernel sources live at build_dir/target-<arch>/linux-<target>/linux-<X.Y.Z>/,
    # so find must recurse (no -maxdepth 0) to reach the versioned subdir.
    local kernel_version target_devices
    kernel_version="$(find "$BANANAWRT_IMMORTAL_DIR/build_dir/target-"*/linux-*/ -type d -regex '.*/linux-[0-9]+\.[0-9]+.*' 2>/dev/null \
                       | head -n1 | sed -E 's|.*/linux-||' || true)"
    kernel_version="${kernel_version:-unknown}"
    target_devices="$(grep '^CONFIG_TARGET.*DEVICE.*=y' "$BANANAWRT_IMMORTAL_DIR/.config" | sed -r 's/.*DEVICE_(.*)=y/\1/')"

    BANANAWRT_KERNEL_VERSION="$kernel_version"
    BANANAWRT_TARGET_DEVICES="$target_devices"
    BANANAWRT_FIRMWARE_DIR="$target_dir"

    substep "Writing firmware-info.json"
    local firmware_info
    firmware_info="$(
        jq -nc \
            --arg tag "$BANANAWRT_RELEASE_DATE" \
            --arg vl "$BANANAWRT_VERSION_LINE" \
            --arg track "$BANANAWRT_TRACK" \
            --arg iwrt "$BANANAWRT_IMMORTALWRT_VER" \
            --arg kernel "$kernel_version" \
            --arg built "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
            --arg commit "${GITHUB_SHA:-$(git -C "$BANANAWRT_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)}" \
            --arg packages_commit "${BANANAWRT_FEED_COMMIT:-}" \
            --argjson files "$files_json" \
            '{tag:$tag, version_line:$vl, track:$track, immortalwrt_version:$iwrt,
              kernel_version:$kernel, build_date:$built, commit:$commit, files:$files} +
             (if $packages_commit == "" then {} else {packages_commit:$packages_commit} end)' \
        | jq '.'
    )"
    printf '%s\n' "$firmware_info" > "$target_dir/firmware-info.json"
    substep_done

    # Non-CI run: stop here. Show artefacts and exit cleanly.
    if ! is_ci; then
        display_alert ok "Build artefacts available at:" "$target_dir"
        return 0
    fi

    # ── CI publishing path ────────────────────────────────────────────────
    display_subheader "Publish (CI mode)"

    check_ci_requirements

    if [[ -n "${BANANAWRT_FEED_COMMIT:-}" ]]; then
        # A newer bump may have landed while this automatic build was running.
        local current_config
        if ! git -C "$BANANAWRT_ROOT" fetch --quiet --depth 1 origin refs/heads/main ||
           ! current_config=$(git -C "$BANANAWRT_ROOT" show "FETCH_HEAD:config/$BANANAWRT_VERSION_LINE/version.json") ||
           ! jq -e --arg version "$BANANAWRT_IMMORTALWRT_VER" --arg track "$BANANAWRT_TRACK" '
               .status == "active" and .branch == $version and (.tracks | index($track) != null)
           ' <<< "$current_config" >/dev/null; then
            exit_with_error "Cannot confirm this firmware version is still current on main; nothing published"
        fi
    fi

    local ftp_root="$BANANAWRT_WORKSPACE/ftp-upload"
    local fw_subpath="bananawrt/firmware/$BANANAWRT_VERSION_LINE/$BANANAWRT_TRACK/$BANANAWRT_RELEASE_DATE"
    local fw_upload_dir="$ftp_root/$fw_subpath"
    mkdir -p "$fw_upload_dir"

    substep "Copying firmware into upload staging"
    cp -a "$target_dir"/* "$fw_upload_dir/"
    substep_done

    # Check the CDN index before anything is uploaded: a broken index stops
    # the release while nothing is published yet.
    substep "Checking firmware-index.json"
    local existing_index
    existing_index="$(fetch_firmware_index)" ||
        exit_with_error "Could not fetch the existing firmware index; nothing published"
    firmware_index_valid "$existing_index" ||
        exit_with_error "Existing firmware index is empty or invalid; nothing published"
    substep_done

    local new_build
    new_build="$(
        jq -nc \
            --arg tag "$BANANAWRT_RELEASE_DATE" \
            --arg date "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
            --arg iwrt "$BANANAWRT_IMMORTALWRT_VER" \
            --arg url "https://repo.superkali.me/bananawrt/firmware/$BANANAWRT_VERSION_LINE/$BANANAWRT_TRACK/$BANANAWRT_RELEASE_DATE/" \
            '{tag:$tag, date:$date, immortalwrt_version:$iwrt, url:$url}'
    )"

    # Upload the build directory first; the index comes after, so it never
    # points at files that are not there yet.
    substep "Uploading firmware via lftp mirror --only-newer"
    local log
    log="$(mktemp -t bananawrt-ftp.XXXXXX)"
    if lftp -c "
        set ftp:ssl-allow no;
        open -u $FTP_USERNAME,$FTP_PASSWORD $FTP_HOST;
        mirror --reverse --verbose --only-newer --parallel=4 \
            $ftp_root/bananawrt/firmware /bananawrt/firmware;
        quit
    " >"$log" 2>&1; then
        substep_done
    else
        substep_fail 'lftp upload failed'
        cat "$log"
        rm -f "$log"
        exit_with_error "FTP upload failed"
    fi
    rm -f "$log"

    # Other channels may publish at the same time. Merge into a fresh copy
    # right before the upload, then read it back after a pause: if a
    # concurrent publisher wrote an older copy over ours, merge again.
    substep "Publishing firmware-index.json"
    local index_file="$BANANAWRT_WORKSPACE/firmware-index.json"
    local attempt current merged_full merged_index published=0
    for attempt in 1 2 3 4 5; do
        current="$(fetch_firmware_index)" && firmware_index_valid "$current" ||
            exit_with_error "Firmware index became unreadable during publication"
        merge_firmware_index "$current" "$new_build" ||
            exit_with_error "Could not merge the firmware index"
        printf '%s\n' "$merged_index" | jq '.' > "$index_file"
        lftp -c "
            set ftp:ssl-allow no;
            set cmd:fail-exit true;
            open -u $FTP_USERNAME,$FTP_PASSWORD $FTP_HOST;
            put $index_file -o /bananawrt/firmware/firmware-index.json;
            quit
        " >/dev/null 2>&1 || exit_with_error "Firmware index upload failed"
        sleep "${BANANAWRT_INDEX_SETTLE:-10}"
        current="$(fetch_firmware_index)" || continue
        if jq -e --arg vl "$BANANAWRT_VERSION_LINE" --arg track "$BANANAWRT_TRACK" \
               --arg tag "$BANANAWRT_RELEASE_DATE" \
               '.versions[$vl].tracks[$track].builds | any(.tag == $tag)' \
               <<< "$current" >/dev/null 2>&1; then
            published=1
            break
        fi
        display_alert warn "firmware index lost this build (attempt $attempt); merging again"
    done
    [[ "$published" == 1 ]] || exit_with_error "Firmware index kept losing this build"
    jq -r --arg vl "$BANANAWRT_VERSION_LINE" --arg track "$BANANAWRT_TRACK" \
        '.versions[$vl].tracks[$track].builds[4:] | .[].tag' <<< "$merged_full" \
        > "$BANANAWRT_WORKSPACE/builds_to_remove.txt"
    substep_done

    # Remove stale builds from the server (keep max 4 per track)
    if [[ -s "$BANANAWRT_WORKSPACE/builds_to_remove.txt" ]]; then
        substep "Cleaning up old builds on FTP"
        local cmds="set ftp:ssl-allow no; open -u $FTP_USERNAME,$FTP_PASSWORD $FTP_HOST;"
        local tag
        while IFS= read -r tag; do
            [[ -z "$tag" ]] && continue
            cmds+=" rm -rf /bananawrt/firmware/$BANANAWRT_VERSION_LINE/$BANANAWRT_TRACK/$tag;"
        done < "$BANANAWRT_WORKSPACE/builds_to_remove.txt"
        cmds+=' quit'
        if lftp -c "$cmds" >/dev/null 2>&1; then
            substep_done
        else
            substep_fail 'cleanup failed'
            display_alert warn 'continuing even though old-build cleanup failed'
        fi
    fi

    # GitHub Release
    substep "Rendering release notes"
    local release_type_upper
    release_type_upper="$(capitalize "$BANANAWRT_TRACK")"
    local release_notes="$BANANAWRT_WORKSPACE/release.txt"
    sed \
        -e "s|{{BANANAWRT_KERNEL}}|$kernel_version|g" \
        -e "s|{{RELEASE_TYPE}}|$release_type_upper|g" \
        -e "s|{{BANANAWRT_VERSION}}|$BANANAWRT_IMMORTALWRT_VER|g" \
        -e "s|{{RELEASE_DATE}}|$(date '+%Y-%m-%d %H:%M:%S')|g" \
        -e "s|{{TARGET_DEVICES}}|$target_devices|g" \
        -e "s|{{VERSION_LINE}}|$BANANAWRT_VERSION_LINE|g" \
        -e "s|{{DOWNLOAD_URL}}|https://repo.superkali.me/?dir=bananawrt/firmware/$BANANAWRT_VERSION_LINE/$BANANAWRT_TRACK/$BANANAWRT_RELEASE_DATE|g" \
        "$BANANAWRT_ROOT/templates/release-notes-template.md" > "$release_notes"
    substep_done

    substep "Creating GitHub Release"
    if command -v gh >/dev/null 2>&1; then
        local tag="$BANANAWRT_VERSION_LINE-$BANANAWRT_RELEASE_DATE"
        if gh release view "$tag" >/dev/null 2>&1; then
            substep_done "tag $tag already exists"
        elif gh release create "$tag" --notes-file "$release_notes" --title "$tag" >/dev/null 2>&1; then
            substep_done "$tag"
        else
            substep_fail 'gh release create failed'
            exit_with_error "Could not create release $tag"
        fi
    else
        substep_skip 'gh CLI missing (handled by workflow step)'
    fi

    # Clean staging now that the upload is done
    rm -rf "$ftp_root" 2>/dev/null || true
}
