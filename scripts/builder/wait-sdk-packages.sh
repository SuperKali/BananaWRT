#!/usr/bin/env bash
# Wait for the dispatched package run, not the newest run on the repository.
set -euo pipefail

: "${PACKAGE_RUN_ID:?Package run ID is required}"
: "${SDK_VERSIONS:?Expected package versions are required}"
[[ "$PACKAGE_RUN_ID" =~ ^[1-9][0-9]*$ ]]
endpoint="repos/SuperKali/openwrt-packages/actions/runs/$PACKAGE_RUN_ID"
attempts=${PACKAGE_POLL_ATTEMPTS:-360}
interval=${PACKAGE_POLL_SECONDS:-30}

for ((i=1; i<=attempts; i++)); do
    if result=$(timeout 20s gh api "$endpoint"); then
        jq -e --arg id "$PACKAGE_RUN_ID" '
            (.id | tostring) == $id and .event == "workflow_dispatch" and .head_branch == "main"
            and .path == ".github/workflows/bananawrt-builder.yml"
        ' <<< "$result" > /dev/null
        status=$(jq -er '.status' <<< "$result")
        if [[ "$status" == completed ]]; then
            conclusion=$(jq -er '.conclusion' <<< "$result")
            if [[ "$conclusion" != success ]]; then
                printf '::error::Package run %s finished with %s; firmware will not start\n' "$PACKAGE_RUN_ID" "$conclusion"
                exit 1
            fi
            jobs=$(timeout 30s gh api --paginate --slurp "$endpoint/jobs?filter=latest&per_page=100")
            jq -e --arg versions "$SDK_VERSIONS" '
                [.[].jobs[]] as $jobs |
                all(($versions | split(","))[]; . as $v |
                    any($jobs[]; .name == ("Deploy Packages (" + $v + ")") and .conclusion == "success")
                    and any($jobs[]; (.name == ("Build X64 / " + $v) or .name == ("Build ARM64 / " + $v))
                        and .conclusion == "success" and any(.steps[];
                            .name == "Verify additional_pack Commit" and .conclusion == "success")))
            ' <<< "$jobs" > /dev/null || {
                printf '::error::Expected signed package deploys or feed verification missing for %s\n' "$SDK_VERSIONS"
                exit 1
            }
            sha=$(jq -er '.head_sha | select(test("^[0-9a-f]{40}$"))' <<< "$result")
            printf 'packages_sha=%s\n' "$sha" >> "$GITHUB_OUTPUT"
            printf 'Verified package deploy %s for %s\n' "$PACKAGE_RUN_ID" "$SDK_VERSIONS"
            exit 0
        fi
        printf 'Package run %s: %s\n' "$PACKAGE_RUN_ID" "$status"
    fi
    if ((i < attempts)); then sleep "$interval"; fi
done
printf '::error::Timed out waiting for package run %s; firmware will not start\n' "$PACKAGE_RUN_ID"
exit 1
