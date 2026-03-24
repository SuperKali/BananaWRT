<div align="center">
  <img src="https://cdn.superkali.me/1113423827479274/bananawrt-logo.png" alt="BananaWRT Logo" width="350px" height="auto">
  <h1>BananaWRT</h1>
  <p><em>A custom ImmortalWRT distribution optimized for Banana Pi R3 Mini and Fibocom FM350</em></p>

  [![Stable](https://img.shields.io/github/actions/workflow/status/SuperKali/BananaWRT/immortalwrt-builder-stable.yml?label=Stable&style=for-the-badge&logo=github)](https://github.com/SuperKali/BananaWRT/actions/workflows/immortalwrt-builder-stable.yml)
  [![Nightly](https://img.shields.io/github/actions/workflow/status/SuperKali/BananaWRT/immortalwrt-builder-nightly.yml?label=Nightly&style=for-the-badge&logo=github)](https://github.com/SuperKali/BananaWRT/actions/workflows/immortalwrt-builder-nightly.yml)
  [![Checker](https://img.shields.io/github/actions/workflow/status/SuperKali/BananaWRT/immortalwrt-checker.yml?label=Checker&style=for-the-badge&logo=github)](https://github.com/SuperKali/BananaWRT/actions/workflows/immortalwrt-checker.yml)

</div>

---

## Overview

**BananaWRT** is a specialized OpenWRT distribution built on top of **ImmortalWRT**, designed specifically for the **Banana Pi R3 Mini** router combined with the **Fibocom FM350** 5G modem. The project leverages GitHub Actions for continuous integration and automated builds, ensuring users always have access to the latest stable and nightly releases.

## Key Features

### Hardware Optimization
- **Native support** for Banana Pi R3 Mini hardware platform
- **Full integration** with Fibocom FM350 5G NR modem (firmware 81600.0000.00.29.24.02+)
- **Advanced modem management** via mrhaav's add-ons (`luci-proto-atc`, `atc-fib-fm350_gl`)

### Connectivity Features
- **Automatic APN detection** for seamless carrier configuration (`atc-apn-database`)
- **Advanced eSIM management** with custom LPAC integration
- **Comprehensive modem tools** from 4IceG project (`luci-app-3ginfo`, `modemband`, and more)

### Build System
- **Multi-version support** — simultaneous support for multiple ImmortalWRT releases (e.g., v24.10 stable + v25.12 nightly)
- **Automated CI/CD pipeline** using GitHub Actions with reusable workflows
- **Firmware distribution** via [repo.superkali.me](https://repo.superkali.me/bananawrt/firmware/) with automatic retention
- **Automatic version bumping** — detects new upstream ImmortalWRT releases and creates bump PRs
- **Automated promotion** — workflow to promote nightly to stable and set up the next nightly version

### Release Tracks

| Track | Description | Schedule |
|-------|-------------|----------|
| **Stable** | Production-ready builds from a proven ImmortalWRT release | Monthly |
| **Nightly** | Builds from the latest ImmortalWRT release for early testing | Weekly |

Each version line (e.g., `v24.10`, `v25.12`) has its own configuration, patches, and feed branch. Version metadata is stored in `config/<version>/version.json`.

---

## Hardware Specifications

### Banana Pi R3 Mini

| Component | Specification |
|-----------|---------------|
| **SoC** | MediaTek MT7986A (Filogic 830) - Quad-core ARM Cortex-A53 @ 2.0GHz |
| **RAM** | 2GB DDR4 |
| **Storage** | 8GB eMMC, 128MB SPI NAND, M.2 Key-M for NVMe |
| **Ethernet** | 2× 2.5GbE (Airoha EN8811H) |
| **Wi-Fi** | Wi-Fi 6 Dual-band (MediaTek MT7976C) - 574/2402 Mbps |
| **Expansion** | M.2 Key-B (USB 3.0) for 5G, M.2 Key-M (PCIe 2.0 x2) for NVMe |
| **Power** | 12V/1.67A via USB Type-C PD |

### Fibocom FM350 5G Modem

> [!IMPORTANT]
> This distribution supports FM350 modems with firmware version **81600.0000.00.29.23.xx** or later.
>
> Download firmware: **[FM350 Repository](https://share.superkali.me/s/7SxD8MpKYEigFKF)**
>
> **Serial Interfaces:** AT commands are accessible via `ttyUSB1` and `ttyUSB3`

| Specification | Details |
|---------------|---------|
| **Technology** | 5G NR Sub-6GHz / LTE / WCDMA |
| **Speed** | 4.67 Gbps DL / 1.25 Gbps UL |
| **5G Bands** | n1/2/3/7/25/28/30/38/40/41/48/66/77/78/79 |
| **LTE Bands** | b1/2/3/4/7/25/30/32/34/38/39/40/41/42/43/48/66 |
| **Interface** | M.2 Key-B (USB 3.1 Gen1 / PCIe Gen3 x1) |

---

## Downloads

Firmware binaries are hosted on **[repo.superkali.me](https://repo.superkali.me/bananawrt/firmware/)** and can be downloaded directly or via the built-in FOTA update system.

| Resource | URL |
|----------|-----|
| **Firmware** | [repo.superkali.me/bananawrt/firmware/](https://repo.superkali.me/bananawrt/firmware/) |
| **Packages** | [repo.superkali.me/releases/](https://repo.superkali.me/releases/) |
| **SDK** | [repo.superkali.me/bananawrt/sdk/](https://repo.superkali.me/bananawrt/sdk/) |

### On-Device Update

Use the built-in update script to upgrade your device:

```bash
# Full OTA update (download + flash)
bananawrt-update fota

# Package updates only
bananawrt-update packages

# Dry run (simulate without changes)
bananawrt-update fota --dry-run
```

The FOTA system automatically detects your current version and shows compatible releases. Cross-version upgrades (e.g., v24.10 → v25.12) are supported with explicit confirmation and factory reset.

---

## Infrastructure

### Self-Hosted Build Runners

To ensure optimal build performance and reliability, this project utilizes self-hosted GitHub Actions runners:

| Runner Name         | Architecture | CPU               | RAM   | Storage      | Network  | Location |
|---------------------|--------------|-------------------|-------|--------------|----------|----------|
| **netcup-de-arm64** | ARM64        | 10-vCore @ 3.0GHz | 16 GB | 1024 GB NVMe | 2.5 Gbps | Germany  |

Each runner is professionally managed and optimized for CI/CD workloads. If you're interested in contributing hardware resources, please open an issue to discuss integration.

**Special thanks** to all supporters who have donated computing resources to this project.

---

## Community & Support

### Star History

Your support helps drive this project forward. If you find BananaWRT useful, please consider giving it a star ⭐

[![Star History Chart](https://api.star-history.com/svg?repos=SuperKali/BananaWRT&type=Date)](https://star-history.com/#SuperKali/BananaWRT&Date)

> **Milestone Goal:** Once we reach **200 stars**, additional customized packages will be released publicly.
>
> This project is fully open source—the star milestone simply recognizes the significant effort involved in maintaining and improving BananaWRT. For financial support, use the **Sponsor** button at the top of the page.

### Repository Activity

![Repository Activity](https://repobeats.axiom.co/api/embed/be7f3efd58c41ba325eff1a5b101c8e40956ff2e.svg "Repobeats analytics image")

---

## Contributing

Contributions are welcome and appreciated! Here's how you can help:

- **Report bugs** by opening an issue with detailed reproduction steps
- **Request features** through the issue tracker
- **Submit pull requests** for bug fixes or enhancements
- **Improve documentation** to help other users

Please ensure your contributions follow the project's coding standards and include appropriate documentation.

---

## License

This project is based on ImmortalWRT and follows the same licensing terms. See individual components for their specific licenses.

---

<div align="center">
  <sub>Built with ❤️ by the BananaWRT community</sub>
</div>
