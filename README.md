<div align="center">
  <img src="https://cdn.superkali.me/1113423827479274/bananawrt-logo.png" alt="BananaWRT Logo" width="350px" height="auto">
  <h2>BananaWRT</h2>
  
  [![Stable](https://img.shields.io/github/actions/workflow/status/SuperKali/BananaWRT/immortalwrt-builder-stable.yml?label=Stable&style=for-the-badge&logo=github)](https://github.com/SuperKali/BananaWRT/actions/workflows/immortalwrt-builder-stable.yml)
  [![Nightly](https://img.shields.io/github/actions/workflow/status/SuperKali/BananaWRT/immortalwrt-builder-nightly.yml?label=Nightly&style=for-the-badge&logo=github)](https://github.com/SuperKali/BananaWRT/actions/workflows/immortalwrt-builder-nightly.yml)
  [![Checker](https://img.shields.io/github/actions/workflow/status/SuperKali/BananaWRT/immortalwrt-checker.yml?label=Checker&style=for-the-badge&logo=github)](https://github.com/SuperKali/BananaWRT/actions/workflows/immortalwrt-checker.yml)
  
</div>


**BananaWRT** is a custom distribution based on **ImmortalWRT**, specifically optimized for the **Banana Pi R3 Mini** paired with the **Fibocom FM350** modem. This project leverages GitHub Actions for automated compilation, ensuring seamless and up-to-date builds.

## Features

- Optimized support for **Banana Pi R3 Mini** hardware.
- Support for the **Fibocom FM350** modem using mrhaav add-ons, such as (luci-proto-atc, atc-fib-fm350_gl)
- Automatic **APN** detection for quick and seamless configuration (atc-apn-database)
- Custom LPAC add-on for advanced eSIM management (lpac).
- Optimized support of 4IceG add-ons, such as (luci-app-3ginfo, modemband, etc).
- Automated builds using GitHub Actions with **multi-layer caching** (2-3x faster builds).
- Based on the stable and feature-rich **ImmortalWRT** distribution.

---

## Hardware Specifications

### Banana Pi R3 Mini
| Specification               | Details                                                                                 |
|-----------------------------|-----------------------------------------------------------------------------------------|
| **CPU**                     | MediaTek MT7986A (Filogic 830) Quad-core ARM Cortex-A53 up to 2GHz                      |
| **RAM**                     | 2GB DDR4                                                                                |
| **Storage**                 | 8GB eMMC flash, 128MB SPI NAND flash; supports M.2 NVMe SSD via M.2 Key-M slot          |
| **Networking**              | 2x 2.5GbE Ethernet ports via Airoha EN8811H controllers                                 |
| **Wi-Fi**                   | Dual-band Wi-Fi 6 (2.4GHz: 574Mbps, 5GHz: 2402Mbps) via MediaTek MT7976C                |
| **Expansion Slots**         | 1x M.2 Key-B (USB 3.0) for 5G NR module, 1x M.2 Key-M (PCIe 2.0 x2) for NVMe SSD        |
| **USB Ports**               | 1x USB 2.0 Type-A                                                                       |
| **SIM Support**             | 1x Nano SIM slot                                                                        |
| **Power Supply**            | 12V/1.67A DC input via USB Type-C PD                                                    |
 
### Fibocom FM350

| Specification                | Details                                       |
|------------------------------|-----------------------------------------------|
| **Modem Type**               | 5G NR Sub-6GHz / LTE / WCDMA                  |
| **Max Download Speed**       | 4.67 Gbps                                     |
| **Max Upload Speed**         | 1.25 Gbps                                     |
| **NR Bands**                 | n1/2/3/7/25/28/30/38/40/41/48/66/77/78/79     |
| **LTE Bands**                | b1/2/3/4/7/25/30/32/34/38/39/40/41/42/43/48/66|
| **Interface**                | M.2 Key-B (USB 3.1 Gen1) or (PCIe Gen3 x1)    |
| **GPS**                      | Supported                                     |
| **Power**                    | 3.3V DC                                       |

---

## ⚙️ GitHub Runner Self-Hosted

This repository uses self-hosted runners to enhance performance and control in CI/CD workflows.

### Runner Specifications

| Worker Name         | Architecture | CPU                | RAM   | Storage         | Network          | Location      |
| ------------------  | ------------ | ------------------ | ----- | --------------- | ---------------- | ------------- |
| **netcup-de-arm64** | ARM64        | 10-vCore, 3.0 GHz  | 16 GB | 1024 GB NvME    | 2.5 Gbps         | Germany       |

Each worker is optimized for specific CI/CD tasks and is managed by the development team to ensure reliability and performance. If you’d like to contribute a new worker, please open an issue in this repository to discuss the details and integration process.

A special thanks to the supporters who have donated a worker node, helping to strengthen the project.

---

## 🚀 Build System & Performance

BananaWRT uses an optimized build system with **multi-layer caching** for nightly builds to dramatically reduce compilation times:

| Build Type | Without Cache | With Cache (Nightly) | Time Saved |
|------------|---------------|----------------------|------------|
| First build | 60-90 min | 60-90 min | - |
| Subsequent builds | 60-90 min | **20-30 min** | **30-60 min** ⚡ |
| Config changes | 60-90 min | **30-45 min** | **15-45 min** ⚡ |

> **Note:** Cache is enabled only for nightly builds (weekly). Stable builds (monthly) run without cache as they often involve version upgrades.

### Cache Layers

- **📦 Downloads Cache**: Caches source tarballs (~1-3 GB, saves 5-10 min)
- **🔧 Toolchain Cache**: Caches compiled toolchain (~500MB-1.5GB, saves 15-30 min)
- **📚 Feeds Cache**: Caches package feeds (~100-300 MB, saves 2-5 min)

For detailed information about the caching system, see [Build Cache Documentation](docs/BUILD-CACHE.md).

---

## ⭐ Star History

If you find this project useful, consider giving it a star ⭐. It’s a great way to show your support and helps me stay motivated to improve and grow the project.

[![Star History Chart](https://api.star-history.com/svg?repos=SuperKali/BananaWRT&type=Date)](https://star-history.com/#SuperKali/BananaWRT&Date)

📌 Once the project reaches 200 stars ⭐, the customized packages will be released publicly. This does not mean the project is not fully open source; rather, it serves as a reminder of the immense effort behind it. Leaving a star is a simple way to show support for the maintainer. Those who wish to contribute financially can do so using the "Sponsor" button at the top.

## 📊 Repository Activity

![Alt](https://repobeats.axiom.co/api/embed/be7f3efd58c41ba325eff1a5b101c8e40956ff2e.svg "Repobeats analytics image")

## 🔧 Contributions

Contributions are welcome! Please open issues for bugs or feature requests and submit pull requests for code changes.


