<div align="center">
  <img src="https://cdn.superkali.me/1113423827479274/bananawrt-logo.png" alt="BananaWRT" width="320">

  # BananaWRT

  **ImmortalWRT for the Banana Pi R3 Mini, built around a 5G modem**
  <br>
  Modem management, automatic APN detection, eSIM support and signed over-the-air updates.

  <p>
    <a href="https://github.com/SuperKali/BananaWRT/actions/workflows/immortalwrt-builder-stable.yml"><img alt="Stable build" src="https://img.shields.io/github/actions/workflow/status/SuperKali/BananaWRT/immortalwrt-builder-stable.yml?label=stable&logo=github&style=for-the-badge"></a>
    <a href="https://github.com/SuperKali/BananaWRT/actions/workflows/immortalwrt-builder-oldstable.yml"><img alt="Oldstable build" src="https://img.shields.io/github/actions/workflow/status/SuperKali/BananaWRT/immortalwrt-builder-oldstable.yml?label=oldstable&logo=github&style=for-the-badge"></a>
    <a href="https://github.com/SuperKali/BananaWRT/actions/workflows/immortalwrt-builder-mtk-vendor.yml"><img alt="MTK vendor build" src="https://img.shields.io/github/actions/workflow/status/SuperKali/BananaWRT/immortalwrt-builder-mtk-vendor.yml?label=mtk-vendor&logo=github&style=for-the-badge"></a>
    <a href="https://github.com/SuperKali/BananaWRT/actions/workflows/immortalwrt-checker.yml"><img alt="Version checker" src="https://img.shields.io/github/actions/workflow/status/SuperKali/BananaWRT/immortalwrt-checker.yml?label=version%20bump&logo=github&style=for-the-badge"></a>
  </p>

  <sub>
    <a href="#downloads">Downloads</a> · <a href="#installation">Install</a> · <a href="#updates">Updates</a> · <a href="#release-channels">Channels</a> · <a href="#building-from-source">Build</a> · <a href="./DEVELOPMENT.md">Developers</a> · <a href="#contributing">Contribute</a>
  </sub>
</div>

---

## Overview

BananaWRT is an [ImmortalWRT](https://immortalwrt.org/) (OpenWrt) distribution for the [Banana Pi R3 Mini](https://docs.banana-pi.org/en/BPI-R3_Mini/) (MediaTek MT7986A). It started around the [Fibocom FM350](https://share.superkali.me/s/7SxD8MpKYEigFKF) 5G modem and now also supports Quectel and other Fibocom USB modems.

On top of ImmortalWRT, every image adds:

- Modem support out of the box: automatic APN detection, the ATC protocol for the FM350, the Quectel connection manager, eSIM (LPAC), SMS, band locking and per-carrier signal readings.
- The full USB data stack for Quectel and Fibocom modems in every channel: QMI (with the Quectel and Fibocom `qmi_wwan` drivers), MBIM, ECM and NCM, plus their LuCI protocol pages.
- Signed firmware and package updates from `repo.superkali.me`, from LuCI (System → Updates) or the `banana-update` command.
- Settings that survive updates, including Wi-Fi when you switch between the standard and the MediaTek vendor Wi-Fi driver.

The BananaWRT packages (modem tools, LuCI apps, the updater) are closed source. They are published as signed binary feeds on `repo.superkali.me`, and every image has the feed configured.

## Hardware

### Banana Pi R3 Mini

| Component | Specification |
|---|---|
| SoC | MediaTek MT7986A (Filogic 830), 4× ARM Cortex-A53 at 2.0 GHz |
| RAM | 2 GB DDR4 |
| Storage | 8 GB eMMC, 128 MB SPI-NAND, M.2 Key-M for NVMe |
| Ethernet | 2× 2.5 GbE (Airoha EN8811H) |
| Wi-Fi | Wi-Fi 6 dual band (MediaTek MT7976C, 574 / 2402 Mbps) |
| Expansion | M.2 Key-B with USB 3.0 (modem), M.2 Key-M with PCIe 2.0 x2 (NVMe) |
| Power | 12 V 1.67 A, USB-C PD |

### Modems

The FM350 is the reference modem. Quectel and Fibocom modems that use QMI, MBIM, ECM or NCM over USB work with the drivers and connection managers shipped in every image. The Quectel RG501Q-EU is tested in both ECM and QMI mode.

> [!IMPORTANT]
> On the Fibocom FM350, use firmware **81600.0000.00.29.23.xx** or newer
> ([firmware archive](https://share.superkali.me/s/7SxD8MpKYEigFKF)). Its AT ports are `/dev/ttyUSB1` and `/dev/ttyUSB3`.

| FM350 | Value |
|---|---|
| Technology | 5G NR Sub-6, LTE, WCDMA |
| Peak throughput | 4.67 Gbps down, 1.25 Gbps up |
| 5G bands | n1/2/3/7/25/28/30/38/40/41/48/66/77/78/79 |
| LTE bands | b1/2/3/4/7/25/30/32/34/38/39/40/41/42/43/48/66 |
| Interface | M.2 Key-B (USB 3.1 Gen 1 / PCIe Gen 3 x1) |

## Release channels

Each channel has its own configuration and CI workflow. All of them publish to `repo.superkali.me`.

| Channel | Source | Kernel | Packages | Built | For |
|---|---|---|---|---|---|
| Stable | ImmortalWRT `25.12.2` | 6.12 | apk | 1st of each month | Most users |
| Oldstable | ImmortalWRT `24.10.7` | 6.6 | opkg | 15th of each month | Devices not yet moved to 25.12 |
| MTK vendor | [`immortalwrt-mt798x-rebase`](https://github.com/SuperKali/immortalwrt-mt798x-rebase) branch `25.12-linkup` | 6.12 | apk | Every Tuesday | MediaTek's own Wi-Fi driver, hardware NAT and USB offload |
| Nightly | Next ImmortalWRT pre-release | | | On demand | Testing; paused until a newer upstream line exists |

A new upstream ImmortalWRT release is picked up automatically: a checker opens the version bump, and merging it rebuilds the SDKs, the packages and the firmware of that channel.

## Downloads

| What | Where |
|---|---|
| Firmware images | [bananawrt/firmware](https://repo.superkali.me/?dir=bananawrt/firmware) |
| BananaWRT package feeds (signed binaries, per ImmortalWRT version) | [releases](https://repo.superkali.me/?dir=releases) |
| Build SDKs | [bananawrt/sdk](https://repo.superkali.me/?dir=bananawrt/sdk) |
| Signing keys | [bananawrt/keys](https://repo.superkali.me/?dir=bananawrt/keys) |

GitHub Releases carry the release notes. The binaries live on `repo.superkali.me`, together with `firmware-index.json`, which the update client reads.

## Installation

1. Pick the build for your channel in the [firmware listing](https://repo.superkali.me/?dir=bananawrt/firmware).
2. Flash it with the Banana Pi R3 Mini procedure from the [Banana Pi wiki](https://docs.banana-pi.org/en/BPI-R3_Mini/). Check the boot mode (eMMC or SPI-NAND): file names follow the ImmortalWRT convention (`*-emmc-*`, `*-snand-*`).
3. Open LuCI at `http://192.168.1.1`, set a root password, insert the SIM and pick a modem profile.

## Updates

In LuCI, System → Updates shows new firmware and package updates. From there you can install a build of the current channel or of another one, flash a firmware file you upload, or update the BananaWRT packages without rebooting.

The same client runs from the shell:

```sh
banana-update fota            # download and install firmware
banana-update packages        # update the BananaWRT packages, no reboot
banana-update fota --dry-run  # run every check, change nothing
```

The client reads `/etc/bananawrt_release` and `firmware-index.json`, then offers newer builds of your track, builds of the other tracks of the same version line, and builds of other version lines (for example `v24.10` to `v25.12-mtk-vendor`).

Before writing anything it checks every firmware file against the published SHA-256 sums and runs `sysupgrade -T`. The configuration is kept. A factory reset happens only when the new image cannot keep it, and only after you confirm.

Package updates retry a failed download up to three times, so a slow or flaky mobile connection does not leave an update half done. Channels marked end of life keep their files until users move on, and the client warns about them.

## Building from source

[`compile.sh`](./compile.sh) drives both local and CI builds. [DEVELOPMENT.md](./DEVELOPMENT.md) covers the pipeline stages, the repository layout, the `version.json` format and the CI workflows.

```sh
./compile.sh                                        # interactive menu
./compile.sh --version-line v25.12 --track stable   # non-interactive
./compile.sh --help                                 # all options
```

## Contributing

- Bug reports: include `/etc/bananawrt_release`, the modem model and the steps to reproduce.
- New channels: add `config/<version_line>/<track>/.config`, a `version.json` and a caller workflow. `v25.12-mtk-vendor` is a complete example.
- Documentation fixes are welcome too.

Commit messages follow `type(scope): subject`. Keep each pull request to one change. See [DEVELOPMENT.md](./DEVELOPMENT.md) for the details.

## Community

If BananaWRT saves you time, a ⭐️ on the repository helps more than you might think.

<p align="center">
  <a href="https://star-history.com/#SuperKali/BananaWRT&Date">
    <img src="https://api.star-history.com/svg?repos=SuperKali/BananaWRT&type=Date" alt="Star history">
  </a>
</p>

> **Milestone:** at 200 ⭐️ the remaining premium BananaWRT packages become public. You can also sponsor the project with the Sponsor button at the top of the page; the star count is just a way to see how much interest there is.

<p align="center">
  <img src="https://repobeats.axiom.co/api/embed/be7f3efd58c41ba325eff1a5b101c8e40956ff2e.svg" alt="Repobeats analytics">
</p>

## License

BananaWRT builds on ImmortalWRT and keeps the license of each component (mostly GPL-2.0). BananaWRT's own scripts, workflows and configuration are MIT licensed unless a file header says otherwise.

---

<div align="center">
  <sub>Copyright © 2024-2026 SuperKali</sub>
</div>
