# BananaWRT Development Guide

Technical reference for contributors and maintainers. See [README.md](./README.md) for user-facing material.

## Contents

- [Building from Source](#building-from-source)
- [Pipeline Stages](#pipeline-stages)
- [Repository Layout](#repository-layout)
- [`version.json` Schema](#versionjson-schema)
- [Adding a New Channel](#adding-a-new-channel)
- [CI / Workflows](#ci--workflows)
- [Build Infrastructure](#build-infrastructure)
- [Related Repositories](#related-repositories)
- [Coding Guidelines](#coding-guidelines)

---

## Building from Source

All pipelines — local and CI — go through the same orchestrator, [`compile.sh`](./compile.sh).

### Dependency setup

Run the apt bootstrap once per build host. It handles `x86_64` and `aarch64` and is idempotent.

```sh
sudo /bin/bash .github/scripts/setup-env.sh setup
```

### Quick start

```sh
# Interactive dialog menu
./compile.sh

# Non-interactive build
./compile.sh --version-line v25.12 --track nightly

# Run a single stage (useful during debugging)
./compile.sh --stage compile --version-line v25.12 --track nightly

# Full CLI reference
./compile.sh --help
```

### CI invocation

The callers in `.github/workflows/immortalwrt-builder-*.yml` resolve the target version line, then delegate to the reusable workflow [`immortalwrt-builder.yml`](./.github/workflows/immortalwrt-builder.yml), which runs:

```sh
./compile.sh --ci --version-line … --track … --immortalwrt-version …
```

Runner selection is dynamic: the pipeline queries the GitHub API for an idle self-hosted runner matching the requested arch, with `ubuntu-latest` / `ubuntu-24.04-arm` as the fallback.

## Pipeline Stages

```
  clone → patch → feeds → config → download → compile → package
```

Each stage lives in [`stages/`](./stages) and can be invoked individually with `--stage <name>`:

| Stage | Script | Responsibility |
|---|---|---|
| 1 — clone | [`01-clone.sh`](./stages/01-clone.sh) | Fetch ImmortalWRT source at the pinned ref (supports custom `repo_url` + branch refs) |
| 2 — patch | [`02-patch.sh`](./stages/02-patch.sh) | Apply DTS, kernel and whole-tree patches from `patch/` |
| 3 — feeds | [`03-feeds.sh`](./stages/03-feeds.sh) | Inject the `additional_pack` feed, then update/install |
| 4 — config | [`04-config.sh`](./stages/04-config.sh) | Drop the channel `.config`, strip stock packages, generate metadata |
| 5 — download | [`05-download.sh`](./stages/05-download.sh) | `make download -jN`, wipe stub archives |
| 6 — compile | [`06-compile.sh`](./stages/06-compile.sh) | `make -jN` with `-j1 V=s` fallback on failure |
| 7 — package | [`07-package.sh`](./stages/07-package.sh) | Pack artefacts, update `firmware-index.json`, FTP upload, create GitHub Release |

GitHub Actions cache layers are scoped per `version_line + track` and save the bulk of feed clones and source downloads across runs:

- `dl/` — upstream tarballs (arch-agnostic)
- `feeds/` — Git clones of every `src-git` feed (arch-agnostic)
- `.ccache/` — compiler cache (arch-specific)
- `staging_dir/` — host + toolchain + target staging (arch-specific)

## Repository Layout

```
BananaWRT/
├── compile.sh                          Main orchestrator
├── lib/                                Shared helpers (colour output, timers, config, dialog)
├── stages/                             7 pipeline stages (01-clone … 07-package)
├── config/
│   ├── v24.10/                         Oldstable version line
│   │   ├── oldstable/.config
│   │   └── version.json
│   ├── v25.12/                         Stable version line
│   │   ├── stable/.config
│   │   └── version.json
│   └── v25.12-mtk-vendor/              MTK vendor-driver variant
│       ├── mtk-vendor/.config
│       └── version.json
├── patch/
│   ├── kernel/dts/<vl>/<track>/        Device-tree drop-ins
│   ├── kernel/files/<vl>/<track>/      Kernel source patches
│   └── tree/<vl>/<track>/*.patch       Whole-tree quilt patches
├── scripts/
│   ├── builder/                        Feed injection + stock-pkg removal
│   ├── utils/                          patch-manager.sh, metadata-generator.sh
│   └── update-script.sh                On-device OTA client
└── .github/
    ├── scripts/setup-env.sh            Apt bootstrap for build hosts
    └── workflows/                      CI callers + reusable builder + housekeeping
```

## `version.json` Schema

Each version line is described by a single JSON document — the source of truth consumed by `compile.sh`, the OTA index, and the release-cleanup automation.

```jsonc
{
  "version_line": "v25.12-mtk-vendor",
  "branch": "25.12-linkup",                                       // human-readable version
  "status": "active",                                             // active | eol
  "tracks": ["mtk-vendor"],                                       // release tracks served
  "feed_branch": "main",                                          // custom feed branch to pin
  "repo_url": "https://github.com/SuperKali/immortalwrt-mt798x-rebase",
  "ref_type": "branch",                                           // tag (default) or branch
  "ref": "25.12-linkup",                                          // explicit git ref
  "version_repo_url": "https://repo.superkali.me/releases/25.12-mtk-vendor",
  "checker_pattern": "25\\.12-mtk-vendor",
  "packages": [ "atc-apn-database", "banana-utils", "lpac", "…" ]
}
```

| Field | Purpose |
|---|---|
| `version_line` | Directory and registry key (`config/<version_line>/`). Must be unique. |
| `branch` | Human-readable version label (used in release tags and the `bananawrt_release` file). |
| `status` | `active` versions are serviced; `eol` versions stay hosted but are flagged in the OTA client. |
| `tracks` | One or more release tracks served under this line (`stable`, `nightly`, custom). |
| `feed_branch` | Branch to pin the `additional_pack` feed to. |
| `repo_url` | Optional override for the upstream ImmortalWRT git URL. |
| `ref_type` | `tag` (default) or `branch`. |
| `ref` | Explicit git ref. Defaults to `v${branch}` for tag mode, `${branch}` for branch mode. |
| `version_repo_url` | URL baked into `CONFIG_VERSION_REPO` (apk distfeeds root). Defaults to the upstream `downloads.immortalwrt.org` path. |
| `buildinfo_base` | Optional URL serving `targets/mediatek/filogic/config.buildinfo`. When `repo_url` is set, the fetch is skipped entirely and the shipped `.config` becomes the diff base. |
| `checker_pattern` | Regex used by `immortalwrt-checker.yml` to detect new upstream tags. Irrelevant for branch-based variants. |
| `packages` | List of `additional_pack` packages expected for this line. Consumed by tooling, not enforced by the build. |

## Adding a New Channel

1. **Decide the shape.** Is it a new track inside an existing version line, or a whole new line? New line = new upstream source or a hard fork; new track = same upstream with different cadence or config.
2. **Seed the directory tree.**
   ```
   config/<version_line>/
     ├── <track>/.config              # start from an adjacent channel
     └── version.json                 # fill in the schema above
   ```
3. **(Optional) Add kernel or tree patches** under `patch/kernel/{dts,files}/<vl>/<track>/` and `patch/tree/<vl>/<track>/*.patch`.
4. **Create a caller workflow** at `.github/workflows/immortalwrt-builder-<track>.yml`. Mirror `immortalwrt-builder-mtk-vendor.yml`: resolve `version_line` + `immortalwrt_version`, then delegate to `immortalwrt-builder.yml`.
5. **(Optional) Track upstream bumps** by adding an entry to `immortalwrt-checker.yml`. Skip for branch-based variants — the branch moves on its own.
6. **Update `README.md`** so users can find the new channel.

`v25.12-mtk-vendor` is a worked example covering every point above.

## CI / Workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `immortalwrt-builder.yml` | reusable | Shared build pipeline — caches, auth, runner resolution, `compile.sh` |
| `immortalwrt-builder-stable.yml` | monthly cron + dispatch | Calls the reusable with the stable version line |
| `immortalwrt-builder-oldstable.yml` | monthly cron + dispatch | Calls the reusable with the oldstable version line |
| `immortalwrt-builder-nightly.yml` | dispatch only | Calls the reusable with the nightly version line (cron paused until a newer upstream line ships) |
| `immortalwrt-builder-mtk-vendor.yml` | weekly cron + dispatch | Calls the reusable with the MTK-vendor variant |
| `immortalwrt-builder-selfhost.yml` | dispatch | Ad-hoc manual build against any version / arch |
| `immortalwrt-sdk-matrix-builder.yml` | dispatch | Publishes SDK tarballs per `(version, arch)` to `repo.superkali.me` |
| `immortalwrt-checker.yml` | 23-hour cron | Bumps upstream ImmortalWRT tag in `version.json` + `.config` via PR |
| `immortalwrt-promote.yml` | dispatch | Promotes nightly → stable, demotes the previous stable → oldstable, sets up the next nightly |
| `immortalwrt-repo-migrate.yml` | dispatch | Renames firmware track dirs + `firmware-index.json` on the CDN to match `version.json` tracks (no rebuild); skips version bumps. `dry_run` defaults true |
| `changelog-updater.yml` | dispatch | Regenerates `CHANGELOG.md` from commit history |

## Build Infrastructure

| Runner | Arch | Spec | Location |
|---|---|---|---|
| `netcup-de-arm64` | ARM64 | 10-vCore @ 3.0 GHz · 16 GB RAM · 1 TB NVMe · 2.5 Gbps | Germany |
| `ubuntu-24.04-arm` (fallback) | ARM64 | GitHub-hosted | — |
| `ubuntu-latest` (fallback) | X64 | GitHub-hosted | — |

The reusable builder first probes for an idle self-hosted runner that matches the requested arch; only when none is available does it spill over to GitHub-hosted. This keeps the cluster warm and avoids queueing while still tolerating outages.

## Related Repositories

| Repository | Purpose |
|---|---|
| [`SuperKali/BananaWRT`](https://github.com/SuperKali/BananaWRT) | Orchestrator, configs, patches, CI — **this repo** |
| [`SuperKali/immortalwrt-mt798x-rebase`](https://github.com/SuperKali/immortalwrt-mt798x-rebase) | Upstream fork with MTK proprietary Wi-Fi drivers (`mtk-vendor` variant) |
| [`immortalwrt/immortalwrt`](https://github.com/immortalwrt/immortalwrt) | Upstream ImmortalWRT (`stable` / `nightly` variants) |

## Coding Guidelines

- **Commit messages** follow the `type(scope): subject` convention (`feat`, `fix`, `refactor`, `docs`, `chore`, …). Body wraps at 72 columns and explains *why*, not *what*.
- **Shell** — `set -Eeuo pipefail`, no bashisms in POSIX scripts, colour output via `lib/functions.sh::display_alert`. Prefer dedicated logging helpers over raw `echo`.
- **YAML workflows** — `permissions:` declared at the top, secrets passed via `secrets: inherit` on reusable callers, every step has a `name:`.
- **Comments** — write *why*, not *what*. Avoid multi-paragraph docstrings. Never reference PR numbers or commit hashes in source comments.
- **PRs** — single concern per PR. Run `bash -n` on every touched script and validate YAML before pushing. Rebase, don't merge-commit.
