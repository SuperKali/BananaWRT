<div align="center">
  <img src="https://cdn.superkali.me/1113423827479274/bananawrt-logo.png" alt="BananaWRT" width="320">

  # BananaWRT

  **A purpose-built ImmortalWRT distribution for the Banana Pi R3 Mini**
  <br>
  Engineered around the Fibocom FM350 5G modem, with first-class modem management,
  automatic APN detection, eSIM support, and an end-to-end CI pipeline.

  <p>
    <a href="https://github.com/SuperKali/BananaWRT/actions/workflows/immortalwrt-builder-stable.yml"><img alt="Stable build" src="https://img.shields.io/github/actions/workflow/status/SuperKali/BananaWRT/immortalwrt-builder-stable.yml?label=stable&logo=github&style=for-the-badge"></a>
    <a href="https://github.com/SuperKali/BananaWRT/actions/workflows/immortalwrt-builder-nightly.yml"><img alt="Nightly build" src="https://img.shields.io/github/actions/workflow/status/SuperKali/BananaWRT/immortalwrt-builder-nightly.yml?label=nightly&logo=github&style=for-the-badge"></a>
    <a href="https://github.com/SuperKali/BananaWRT/actions/workflows/immortalwrt-builder-mtk-vendor.yml"><img alt="MTK vendor build" src="https://img.shields.io/github/actions/workflow/status/SuperKali/BananaWRT/immortalwrt-builder-mtk-vendor.yml?label=mtk-vendor&logo=github&style=for-the-badge"></a>
    <a href="https://github.com/SuperKali/BananaWRT/actions/workflows/immortalwrt-checker.yml"><img alt="Version checker" src="https://img.shields.io/github/actions/workflow/status/SuperKali/BananaWRT/immortalwrt-checker.yml?label=version%20bump&logo=github&style=for-the-badge"></a>
  </p>

  <sub>
    <a href="#downloads">Downloads</a> · <a href="#installation">Install</a> · <a href="#release-channels">Channels</a> · <a href="#building-from-source">Build</a> · <a href="./DEVELOPMENT.md">Developers</a> · <a href="#contributing">Contribute</a>
  </sub>
</div>

---

## Overview

BananaWRT is a specialised [OpenWRT](https://openwrt.org/) / [ImmortalWRT](https://immortalwrt.org/) distribution for the [Banana Pi R3 Mini](https://docs.banana-pi.org/en/BPI-R3_Mini/) (MediaTek MT7986A), tailored around the [Fibocom FM350](https://share.superkali.me/s/7SxD8MpKYEigFKF) 5G NR modem.

Where upstream ImmortalWRT stops, BananaWRT layers:

- **Turn-key modem integration** — autodetected APNs, ATC proto, eSIM/LPAC toolchain, SMS & band tools.
- **Multi-version CI pipeline** — several ImmortalWRT version lines build in parallel from the same code base.
- **Reproducible on-device upgrades** — the `bananawrt-update` FOTA flow serves signed builds from `repo.superkali.me`.
- **A single `./compile.sh` entry point** — the same orchestrator runs locally and in CI, with caching for `dl/`, `feeds/`, `ccache` and `staging_dir/`.

## Hardware

### Banana Pi R3 Mini

| Component | Specification |
|---|---|
| SoC | MediaTek **MT7986A** (Filogic 830) — 4× ARM Cortex-A53 @ 2.0 GHz |
| RAM | 2 GB DDR4 |
| Storage | 8 GB eMMC · 128 MB SPI-NAND · M.2 Key-M for NVMe |
| Ethernet | 2× 2.5 GbE (Airoha EN8811H) |
| Wi-Fi | Wi-Fi 6 dual-band (MediaTek MT7976C, 574 / 2402 Mbps) |
| Expansion | M.2 Key-B USB 3.0 (5G) · M.2 Key-M PCIe 2.0 x2 (NVMe) |
| Power | 12 V 1.67 A USB-C PD |

### Fibocom FM350 5G modem

> [!IMPORTANT]
> BananaWRT targets FM350 modems running firmware **81600.0000.00.29.23.xx** or newer.
> Firmware archive: [share.superkali.me/s/7SxD8MpKYEigFKF](https://share.superkali.me/s/7SxD8MpKYEigFKF).
> AT commands are exposed on `/dev/ttyUSB1` and `/dev/ttyUSB3`.

| Property | Value |
|---|---|
| Technology | 5G NR Sub-6 · LTE · WCDMA |
| Peak throughput | 4.67 Gbps DL / 1.25 Gbps UL |
| 5G bands | n1/2/3/7/25/28/30/38/40/41/48/66/77/78/79 |
| LTE bands | b1/2/3/4/7/25/30/32/34/38/39/40/41/42/43/48/66 |
| Interface | M.2 Key-B (USB 3.1 Gen 1 / PCIe Gen 3 x1) |

## Release Channels

Three officially built variants ship today. Each one is an independent version line with its own `config/`, patches and CI caller, and every build publishes to `repo.superkali.me`:

| Channel | Upstream | Track | Cadence | Audience |
|---|---|---|---|---|
| **Stable** | `immortalwrt/immortalwrt` tag (currently `24.10.5`) | `stable` | Monthly | Production deployments |
| **Nightly** | `immortalwrt/immortalwrt` tag (currently `25.12.0-rc2`) | `nightly` | Weekly | Early testing of upcoming releases |
| **MTK-vendor** | `SuperKali/immortalwrt-mt798x-rebase` branch `25.12-linkup` | `mtk-vendor` | Weekly | Devices that benefit from MediaTek proprietary Wi-Fi drivers + HNAT + USB offload |

Channel metadata lives in `config/<version_line>/version.json`. Adding a new channel is a matter of dropping a directory and a caller workflow — the reusable pipeline adapts.

## Downloads

Firmware and artefacts are hosted on `repo.superkali.me`, served via a standard autoindex plus a machine-readable `firmware-index.json` for the OTA client.

| Asset | URL |
|---|---|
| Firmware images | [repo.superkali.me/bananawrt/firmware/](https://repo.superkali.me/bananawrt/firmware/) |
| Custom packages | [repo.superkali.me/releases/](https://repo.superkali.me/releases/) |
| Build SDKs | [repo.superkali.me/bananawrt/sdk/](https://repo.superkali.me/bananawrt/sdk/) |
| Signing keys | [repo.superkali.me/bananawrt/keys/](https://repo.superkali.me/bananawrt/keys/) |

GitHub Releases carry the release notes; the binaries themselves live on `repo.superkali.me` to keep the GitHub archive slim.

## Installation

### First flash

1. Pick a build that matches your board and channel under the [firmware listing](https://repo.superkali.me/bananawrt/firmware/).
2. Follow the official **Banana Pi R3 Mini** flashing procedure from the [Banana Pi wiki](https://docs.banana-pi.org/en/BPI-R3_Mini/). Pay attention to boot mode (eMMC vs SNAND) — BananaWRT artefacts follow the ImmortalWRT naming convention (`*-emmc-*`, `*-snand-*`).
3. Connect to LuCI at `http://192.168.1.1`, configure your root password, then insert the FM350 SIM and pick a profile.

### On-device updates

```sh
# Interactive OTA (firmware + release notes)
bananawrt-update fota

# Custom-packages only (no reboot)
bananawrt-update packages

# Preview without touching the device
bananawrt-update fota --dry-run
```

The OTA client reads `/etc/bananawrt_release`, queries `firmware-index.json`, and lists:

- Upgrades within the current track;
- Builds of other tracks sharing the same version line;
- **Cross-version** upgrades (e.g. `v24.10 → v25.12-mtk-vendor`), which require explicit confirmation and perform a factory reset.

EOL channels keep serving existing users until they migrate — the OTA client flags them prominently.

## Building from Source

BananaWRT ships a single orchestrator, [`compile.sh`](./compile.sh), that drives both local and CI builds. Full details — pipeline stages, repository layout, `version.json` schema, coding guidelines — live in **[DEVELOPMENT.md](./DEVELOPMENT.md)**.

```sh
./compile.sh                                        # interactive dialog menu
./compile.sh --version-line v25.12 --track nightly  # non-interactive
./compile.sh --help                                 # full reference
```

## Contributing

Contributions are welcome across the full stack:

- **Bug reports** — include kernel version, `/etc/bananawrt_release`, reproduction steps.
- **Channel additions** — drop `config/<new_line>/{track}/.config` + a `version.json` + a caller workflow. See `v25.12-mtk-vendor` as a worked example.
- **Documentation** — from improved user guides to architecture notes.

See [DEVELOPMENT.md](./DEVELOPMENT.md) for the full developer guide. Please follow the existing commit message style (`type(scope): subject`) and keep each pull request focused on a single concern.

## Community

If BananaWRT saves you time, a ⭐️ on the repository helps more than you might think.

<p align="center">
  <a href="https://star-history.com/#SuperKali/BananaWRT&Date">
    <img src="https://api.star-history.com/svg?repos=SuperKali/BananaWRT&type=Date" alt="Star history">
  </a>
</p>

> **Milestone:** at **200 ⭐️** the remaining premium BananaWRT packages are released publicly. Financial sponsorship is available via the **Sponsor** button at the top of the page — the star count is purely a way of recognising community interest.

<p align="center">
  <img src="https://repobeats.axiom.co/api/embed/be7f3efd58c41ba325eff1a5b101c8e40956ff2e.svg" alt="Repobeats analytics">
</p>

## License

BananaWRT is built on top of ImmortalWRT and inherits the licensing of each component (predominantly **GPL-2.0**). Original BananaWRT code (scripts, workflows, configs) is released under the **MIT License** unless otherwise noted in the file header.

---

<div align="center">
  <sub>Crafted with care · Copyright © 2024–2026 SuperKali</sub>
</div>
