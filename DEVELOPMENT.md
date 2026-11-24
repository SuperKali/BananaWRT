# BananaWRT development guide

Technical reference for contributors and maintainers. User documentation is in [README.md](./README.md).

## Contents

- [Building from source](#building-from-source)
- [Pipeline stages](#pipeline-stages)
- [Repository layout](#repository-layout)
- [`version.json` format](#versionjson-format)
- [Adding a channel](#adding-a-channel)
- [CI workflows](#ci-workflows)
- [Build hosts](#build-hosts)
- [Tests](#tests)
- [Related repositories](#related-repositories)
- [Coding guidelines](#coding-guidelines)

---

## Building from source

Local and CI builds both go through [`compile.sh`](./compile.sh).

### Build host setup

Install the build dependencies once per host. The script works on `x86_64` and `aarch64` and can be run again safely.

```sh
sudo /bin/bash .github/scripts/setup-env.sh setup
```

### Quick start

```sh
./compile.sh                                                   # interactive menu
./compile.sh --version-line v25.12 --track stable              # non-interactive
./compile.sh --stage compile --version-line v25.12 --track stable  # one stage only
./compile.sh --help                                            # all options
```

Useful options:

| Option | Effect |
|---|---|
| `--jobs N` | Parallel make jobs. By default, one per CPU but at most one per 1.25 GiB of usable memory (the smallest cgroup `memory.max` of the process, or `MemAvailable`). |
| `--no-package` | Stop after the compile stage (used by the SDK workflow). |
| `--keep-source` | Keep `$WORKSPACE/immortalwrt` on exit. |
| `--clean`, `--clean=all` | Remove `build_dir/`, or also `dl/` and `staging_dir/`, before building. |
| `--ci` | CI mode: upload to the CDN and create the GitHub release. |

### In CI

The callers in `.github/workflows/immortalwrt-builder-*.yml` resolve the version line and call the reusable workflow [`immortalwrt-builder.yml`](./.github/workflows/immortalwrt-builder.yml), which runs:

```sh
./compile.sh --ci --version-line … --track … --immortalwrt-version …
```

## Pipeline stages

```
clone → patch → feeds → config → download → compile → package
```

Each stage is a script in [`stages/`](./stages) and can be run alone with `--stage <name>`.

| Stage | Script | What it does |
|---|---|---|
| 1. clone | [`01-clone.sh`](./stages/01-clone.sh) | Fetches ImmortalWRT at the pinned tag or branch (a custom `repo_url` is supported) |
| 2. patch | [`02-patch.sh`](./stages/02-patch.sh) | Applies the device tree, kernel and whole-tree patches from `patch/` |
| 3. feeds | [`03-feeds.sh`](./stages/03-feeds.sh) | Adds the `additional_pack` feed, updates the feeds, patches the LuCI Dashboard on 25.12 MTK vendor, installs the feeds |
| 4. config | [`04-config.sh`](./stages/04-config.sh) | Installs the channel `.config`, drops stock packages that `additional_pack` replaces, writes the release metadata |
| 5. download | [`05-download.sh`](./stages/05-download.sh) | `make download`, then removes truncated archives |
| 6. compile | [`06-compile.sh`](./stages/06-compile.sh) | `make -jN`; on failure it runs again with `-j1 V=s` to show the error |
| 7. package | [`07-package.sh`](./stages/07-package.sh) | Collects the images, uploads them, updates `firmware-index.json` and creates the GitHub release |

On 25.12 MTK vendor, the feeds stage first reverts the Dashboard patch left by a previous build in a reused workspace, then applies the current one. It leaves other changes in the feed alone.

Publishing needs a valid `firmware-index.json` on the CDN. If it is missing or invalid, the package stage stops instead of writing a new one: restore it from a backup. On a new CDN, seed it with the configured version lines and empty `tracks` objects before the first publish.

GitHub Actions caches are kept per `version_line` and track:

- `dl/`: upstream source archives (any architecture)
- `feeds/`: Git clones of the `src-git` feeds (any architecture)
- `.ccache/`: compiler cache (per architecture)
- `staging_dir/`: host tools, toolchain and target staging (per architecture)

## Repository layout

```
BananaWRT/
├── compile.sh                          Main entry point
├── lib/                                Shared helpers (output, timers, config parsing, dialog menu)
├── stages/                             The 7 pipeline stages
├── config/
│   ├── v24.10/                         Oldstable line
│   │   ├── oldstable/.config
│   │   └── version.json
│   ├── v25.12/                         Stable line
│   │   ├── stable/.config
│   │   └── version.json
│   └── v25.12-mtk-vendor/              MediaTek vendor driver line
│       ├── mtk-vendor/.config
│       └── version.json
├── patch/
│   ├── feeds/<vl>/<track>/<feed>/      Patches to checked-out feeds (applied by the feeds stage)
│   ├── kernel/dts/<vl>/<track>/        Device tree files
│   ├── kernel/files/<vl>/<track>/      Kernel source files
│   └── tree/<vl>/<track>/*.patch       Whole-tree patches
├── scripts/
│   ├── builder/                        Feed setup and stock package removal
│   ├── utils/                          patch-manager.sh, metadata-generator.sh
│   └── update-script.sh                Old on-device updater, kept for devices that still run it
├── templates/                          GitHub release notes template
├── tests/                              Offline tests of the CI and publishing logic
└── .github/
    ├── scripts/setup-env.sh            Build host setup
    └── workflows/                      Channel callers, reusable builder, SDK and housekeeping workflows
```

The current on-device updater is `banana-update`, shipped in the `banana-utils` package of [openwrt-packages](https://github.com/SuperKali/openwrt-packages), with its LuCI page in `luci-app-banana-update`.

## `version.json` format

Each version line has one `version.json`. `compile.sh`, the update index, the SDK and package workflows and the release cleanup all read it.

```jsonc
{
  "version_line": "v25.12-mtk-vendor",
  "branch": "25.12-linkup",                 // version label
  "status": "active",                       // active | eol
  "tracks": ["mtk-vendor"],                 // tracks built from this line
  "feed_branch": "main",                    // branch of the additional_pack feed
  "repo_url": "https://github.com/SuperKali/immortalwrt-mt798x-rebase",
  "ref_type": "branch",                     // tag (default) or branch
  "ref": "25.12-linkup",                    // explicit Git ref
  "version_repo_url": "https://repo.superkali.me/releases/25.12-mtk-vendor",
  "checker_pattern": "25\\.12-mtk-vendor",
  "packages": ["atc-apn-database", "banana-utils", "lpac", "…"]
}
```

| Field | Meaning |
|---|---|
| `version_line` | Directory name under `config/` and key in the update index. Must be unique. |
| `branch` | Version label, used in release tags, `/etc/bananawrt_release` and the package feed path. |
| `status` | `active` lines are built. `eol` lines stay on the CDN and the update client flags them. |
| `tracks` | Tracks built from this line (`stable`, `oldstable`, `nightly`, `mtk-vendor`). |
| `feed_branch` | Branch the `additional_pack` feed is pinned to. |
| `repo_url` | Upstream Git URL, when it is not ImmortalWRT. |
| `ref_type` | `tag` (default) or `branch`. |
| `ref` | Git ref. Defaults to `v${branch}` for tags and `${branch}` for branches. |
| `version_repo_url` | Value of `CONFIG_VERSION_REPO`, the root of the package feeds on the device. Defaults to `downloads.immortalwrt.org`. |
| `buildinfo_base` | Optional URL of `targets/mediatek/filogic/config.buildinfo`. Ignored when `repo_url` is set; the shipped `.config` is then the base. |
| `checker_pattern` | Regex the version checker uses to find new upstream tags. Not used by branch-based lines. |
| `packages` | `additional_pack` packages expected on this line. Used by tooling and the promote workflow; the build does not enforce it. |

## Adding a channel

1. Decide whether it is a new track of an existing line (same upstream, different config or schedule) or a new line (new upstream version or fork).
2. Create the directory:
   ```
   config/<version_line>/
     ├── <track>/.config      # start from a similar channel
     └── version.json         # see the format above
   ```
3. Add kernel or tree patches under `patch/kernel/{dts,files}/<vl>/<track>/` and `patch/tree/<vl>/<track>/` if needed.
4. Add a caller workflow `.github/workflows/immortalwrt-builder-<track>.yml`, modelled on `immortalwrt-builder-mtk-vendor.yml`.
5. For tag-based lines, add the line to `immortalwrt-checker.yml` so upstream releases are picked up.
6. Add the channel to the README.

`v25.12-mtk-vendor` covers every step.

## CI workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `immortalwrt-builder.yml` | reusable | Shared build: caches, runner choice, `compile.sh`, publishing |
| `immortalwrt-builder-stable.yml` | 1st of each month, manual | Builds the stable track |
| `immortalwrt-builder-oldstable.yml` | 15th of each month, manual | Builds the oldstable track |
| `immortalwrt-builder-mtk-vendor.yml` | every Tuesday, manual | Builds the MTK vendor track |
| `immortalwrt-builder-nightly.yml` | manual | Builds the nightly track (schedule paused until a newer upstream line exists) |
| `immortalwrt-builder-selfhost.yml` | manual | One-off build of any version and architecture |
| `immortalwrt-sdk-matrix-builder.yml` | manual, reusable | Builds and publishes the SDK of each version and architecture |
| `immortalwrt-sdk-trigger.yml` | push to `main` changing `version.json` | Builds SDKs, packages and firmware after a version bump |
| `immortalwrt-checker.yml` | every 23 hours, manual | Opens a pull request when ImmortalWRT publishes a new tag |
| `immortalwrt-promote.yml` | manual | Promotes nightly to stable and stable to oldstable, then prepares the next nightly |
| `immortalwrt-repo-migrate.yml` | manual | Renames firmware track directories and `firmware-index.json` entries on the CDN to match `version.json` (no rebuild). `dry_run` is on by default |
| `changelog-updater.yml` | manual | Regenerates `CHANGELOG.md` from the commit history |

### Version bumps

When a version bump lands on `main`, `immortalwrt-sdk-trigger.yml` compares the old and new `branch` values. For each changed, active upstream version it builds the X64 and ARM64 SDKs. Track-only edits and forks such as MTK vendor do not build SDKs. To rebuild the MTK vendor SDK, run the SDK builder by hand with `mtk-vendor` and `X64`; it is published as `25.12-linkup`, so the package builder covers it too.

Once the CDN serves the new SDKs, the trigger starts the package builder in openwrt-packages once. It waits for that exact run and checks that every requested version was deployed and signed. The firmware build of each bumped channel then pins the same package commit. If a package deploy fails or is skipped, no firmware is built.

SDK uploads share a queue that protects the SDK index. Firmware channels build and publish in parallel: each uploads its files, merges its entry into a fresh copy of `firmware-index.json`, reads it back and merges again if another channel overwrote it. Before an automatic publish, the builder checks that the version and track are still current on `main`. Manual SDK builds do not start package builds.

`PERSONAL_ACCESS_TOKEN` needs Actions read and write access in openwrt-packages. If the SDK index on the CDN is missing or invalid, restore it before retrying; a new CDN can start from `{"versions":{}}`. Rerunning a failed wait job checks the same package run again without starting a new one.

The package builder in openwrt-packages compiles only the packages changed since the published feed. See its README for details.

## Build hosts

The reusable builder looks for an idle self-hosted runner first. With `AUTO`, the default, it takes an idle self-hosted runner of either architecture (X64 first) and otherwise uses GitHub's `ubuntu-24.04-arm`. A specific architecture falls back to `ubuntu-latest` (X64) or `ubuntu-24.04-arm`.

On a shared machine, run one firmware build at a time and cap the runner's memory (for example `MemoryMax=` in a systemd drop-in) so an out-of-memory kill stops the job rather than the host. The default job count of `compile.sh` follows that cap: 16 jobs under a 20 GiB limit.

## Tests

The tests run offline, with no network or build host:

```sh
bash tests/feeds-dashboard.sh      # Dashboard patch revert and reapply on MTK vendor
bash tests/firmware-publish.sh     # firmware index checks and publish failure paths
python3 -I tests/sdk-release.py    # SDK index and version bump chain
```

## Related repositories

| Repository | Purpose |
|---|---|
| [SuperKali/BananaWRT](https://github.com/SuperKali/BananaWRT) | Build orchestration, configs, patches, CI (this repository) |
| [SuperKali/openwrt-packages](https://github.com/SuperKali/openwrt-packages) | The `additional_pack` feed: modem tools, LuCI apps, `banana-update` |
| [SuperKali/immortalwrt-mt798x-rebase](https://github.com/SuperKali/immortalwrt-mt798x-rebase) | ImmortalWRT fork with MediaTek's Wi-Fi driver (MTK vendor line) |
| [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) | Upstream ImmortalWRT (stable, oldstable, nightly) |

## Coding guidelines

- Commit messages use `type(scope): subject` (`feat`, `fix`, `refactor`, `docs`, `chore`, ...). Wrap the body at 72 columns and explain why, not what.
- Shell: `set -Eeuo pipefail` in Bash scripts, no Bash features in POSIX scripts, output through `display_alert` in `lib/functions.sh` instead of raw `echo`.
- Workflows: declare `permissions:` at the top, pass secrets with `secrets: inherit` to reusable workflows, give every step a `name:`.
- Comments say why, not what. Keep them short, and never mention pull request numbers or commit hashes.
- Pull requests: one change each. Run `bash -n` on every script you touch and validate the YAML before pushing. Rebase instead of merge commits.
