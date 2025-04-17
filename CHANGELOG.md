# 📦 CHANGELOG

All notable changes to **BananaWRT** will be documented in this file.

---

## [2025-04-17]

### 🧩 Additional Packages

- 🔼 Bump: `banana-utils` to v1.09 by @SuperKali  
- 🛠️ `banana-utils`: Optimizing banana-restore process by @SuperKali  
- 🔄 `luci-app-fan`: Updated warn and crit values of notifications by @SuperKali  
- 🔄 `luci-app-fan`: Remove invalid translation by @SuperKali  
- 🌟 Feat: improve `luci-app-fan` UI and notifications by @SuperKali  
- 🐛 Bump versioning of `linkup-optimization` and luci-app-sms-tool and fix default tty port for send AT command and SMS by @SuperKali  

### 🍌 BananaWRT Core

- 🧪 CHANGELOG: revert to test by @SuperKali  
- ⏪ CHANGELOG: revert previous commit and try another method by @SuperKali  
- 🗑️ CHANGELOG: remove safe directory by @SuperKali  
- 🐛 CHANGELOG: fixing additional pack checks by @SuperKali  
- 🔄 Docs: Update CHANGELOG for 2025-04-17 (#43) by @SuperKali  
- 🐛 CHANGELOG: fixing wrong issue to get information by @SuperKali  
- 🐛 CHANGELOG: fixing some issues 1 by @SuperKali  
- 🐛 CHANGELOG: fixing some issues by @SuperKali  
- 🐛 CHANGELOG: fix issue on formatting commit message by @SuperKali  
- ➕ CHANGELOG: Adding automatic changelog updater by @SuperKali  
- 🔼 Bump ImmortalWRT to version v24.10.1 (#40) by @SuperKali  
- ➕ CHANGELOG: added the release of 2025-04-16 by @SuperKali  

---


## [2025-04-12]

### 🧩 Additional Packages

- 🔼 `luci-app-fan`: bump version to **v1.0.11** & improve time range button layout on mobile by @SuperKali  
- 🔼 `luci-app-fan`: bump version to **v1.0.10** by @SuperKali  
- 🔼 `luci-app-fan`: bump version to **v1.0.9** by @SuperKali  
- 📊 `luci-app-fan`: add temperature history chart by @SuperKali  
- 🫥 `luci-app-fan`: hide average temperature when modem is not monitored by @SuperKali  
- 🔼 `luci-app-fan`: bump version to **v1.0.8** by @SuperKali  
- ⚙️ `luci-app-fan`: add option to disable modem temperature monitoring by @SuperKali  
- 🔧 `banana-utils` & `linkup-optimization`: bump versioning, moved hostname logic to `banana-utils` and changed hostname from **LinkUP** to **BananaWRT** by @SuperKali  
- 📝 README: added `luci-app-fan` to packages list by @SuperKali  

---

## [2025-04-09]

### 🧩 Additional Packages

- 🐛 `luci-app-fan`: fix permission on install by @SuperKali  
- 🛠️ `luci-app-fan`: temporarily removed "Do not monitor modem" from CBI by @SuperKali  
- 🚀 `luci-app-fan`: first release – includes backend control script and LuCI interface by @SuperKali  

### 🍌 BananaWRT Core

- 🌬️ Add first support to a brand new fan control interface by @SuperKali  
- 🐞 issue_templates: add bug report template, inspired from ImmortalWRT by @SuperKali  
- 📜 Added CODE_OF_CONDUCT.md by @SuperKali  
- 🔗 CHANGELOG: fix wrong link in BananaWRT section by @SuperKali  
- 📄 release-template: added redirect link to changelog by @SuperKali  
- ♻️ Align script from banana-utils by @SuperKali  

---

## [2025-04-07]

### 🧩 Additional Packages

- ➕ Added condition to remove the log file if it exists on every `sysupgrade` execution by @SuperKali  
- 🔼 Bumped `banana-utils` to **v1.05** by @SuperKali  
- 🛠️ Fixed unsupported parameter usage in `sh` scripts by @SuperKali  
- ℹ️ Added more detailed information on package restore process by @SuperKali  
- ⏱️ Reverted sleep time to **10 seconds** in relevant scripts by @SuperKali  
- 🐛 Fixed issue during package installation by @SuperKali  
- 🛠️ Fixed unknown options and enabled service start at boot by @SuperKali  
- ♻️ Initial support for automatic restoration of overlay packages by @SuperKali  
- 📄 Updated `README` documentation for better clarity by @SuperKali  
- 🔄 Created a separate package to handle functionalities previously bundled with `linkup-optimization` by @SuperKali  
- 🔧 Bumped `modemband` and `linkup-optimization`; added **caching** and **overheat protection** on fan control by @SuperKali  
- 🔁 Bumped `linkup-optimization`: introduced support to update packages via `banana-update` by @SuperKali  
- 📝 Adjusted default configuration for `3g-info` utility by @SuperKali  

### 🍌 BananaWRT Core

- 🛠️ Fixed self-hosted (manual) workflow failures by @SuperKali  
- 🔧 Updated **stable** and **nightly** build configurations by @SuperKali  
- ➕ Added support in `userscript` to update `additional_pack` from repository without updating the entire board by @SuperKali  
- 📦 Bumped `actions/upload-artifact` from `4.6.1` to `4.6.2` (#29) by @dependabot[bot]  
- 🔄 Updated GitHub worker list from `README` by @SuperKali  
- 🧹 Added cleanup input to `self-hosted` workflow by @SuperKali  
- ➕ Re-added x86 worker to the workflow list by @SuperKali  
- 🗑️ Removed deprecated runner info from documentation by @SuperKali  
- 🛠️ Fixed missing functions in update script and added `--reset` flag to restore full configuration by @SuperKali  
- 📢 Added more detailed explanations in feature section by @SuperKali  

---

🛠️ Maintained with ❤️ by [BananaWRT](https://github.com/SuperKali/BananaWRT)  
📅 Release date: **April 17, 2025**