# 📦 CHANGELOG

All notable changes to **BananaWRT** will be documented in this file.

---
## [2026-04-22]

### 🧩 Additional Packages

- 🛠️ workflows: raise container pid/ulimit caps for sdk builds by @SuperKali  
- 🛠️ workflows: inline builder image ref (env not allowed in container.image) by @SuperKali  
- 🛠️ workflows: run builds inside the bananawrt builder container by @SuperKali  
- 💅 `luci-app-3ginfo`-lite: import ui redesign from v25.12-snap by @SuperKali  
- 🛠️ workflows: skip apk signing-key injection for ipk builds by @SuperKali  
- 🛠️ workflows: rewrite feeds.conf.default to pin additional_pack at main by @SuperKali  
- 🛠️ workflows: dynamic runner selection across self-hosted and github-hosted by @SuperKali  
- 🐛 `banana-utils`: fix apk feed url to use flat packages.adb layout by @SuperKali  
- 🐛 `luci-app-3ginfo`-lite: fix fm350-gl 5g nr sinr formula by @SuperKali  
- 🐛 `luci-app-3ginfo`-lite: fix missing nr signal stats for fm160 by @SuperKali  
- ➕ `luci-app-3ginfo`-lite: add tri cascade vos_5g / compal rxm-g1 modem definition by @SuperKali  
- ➕ `luci-app-3ginfo`-lite: add tri cascade vos_5g / compal rxm-g1 modem definition by @SuperKali  

### 🍌 BananaWRT Core

- 🐛 fix(ci): use github_token for package version deletion by @SuperKali  
- 🛠️ dockerfile: pin builder user to uid 1001 to match ubuntu-latest by @SuperKali  
- 🛠️ dockerfile: dynamic uid remap entrypoint with gosu by @SuperKali  
- 🐛 fix(container): fix uid mismatch between container user and self-hosted runner by @SuperKali  
- 🐛 fix(ci): declare actions:write on callers so run pruning works by @SuperKali  
- 🐛 fix(ci): grant actions:write so workflow-history pruning can delete by @SuperKali  
- 🐛 fix(package): neutralise sigpipe (141) from head in pipefail shell by @SuperKali  
- 🐛 fix(package): correctly detect kernel version by @SuperKali  
- 🐛 fix(ci): reuse pre-arch-split caches on x64 via conditional fallback by @SuperKali  
- 🐛 fix(build): multiple correctness issues found during audit by @SuperKali  
- 🐛 fix(ci): upload both .ipk and .apk additional_pack artefacts by @SuperKali  
- 🐛 fix(build): make ccache opt-in, default off by @SuperKali  
- 🐛 fix(build): verbose fallback for ccache pre-build failure by @SuperKali  
- 🐛 fix(build): pre-build tools/ccache to avoid liblzo race by @SuperKali  
- 🔄 feat(ci): runner maintenance + ghcr cleanup + tighter artifact retention by @SuperKali  
- 🐛 fix(ui): enable ansi colors in ci log viewers by @SuperKali  
- ♻️ refactor(ci): sdk builder on compile.sh + retire setup-env.sh by @SuperKali  
- 🐛 fix(docker): drop default ubuntu user before creating builder by @SuperKali  
- 🐛 fix(ci): lowercase image name for oci references by @SuperKali  
- 🏗️ feat(build): compile.sh orchestrator + docker builder image by @SuperKali  
- 🐛 fix(v25.12): strip broken video feed from feeds.conf.default by @SuperKali  
- 🔄 feat(ci): dynamic runner selection with github-hosted fallback by @SuperKali  
- 🛠️ workflows: expose architecture input on nightly dispatcher by @SuperKali  
- 🧹 chore: point feed_branch to main for all version lines by @SuperKali  
- 🔼 build(deps): bump softprops/action-gh-release from 2.6.1 to 3.0.0 (#127) by @dependabot[bot]  
- 🔄 update immortalwrt v25.12 to version v25.12.0-rc2 (#128) by @SuperKali  
- 🔄 docs: update changelog for 2026-03-26 (#124) by @SuperKali  
- 🐛 use directory listing url format for firmware download link by @SuperKali  

---

## [2026-03-26]

### 🧩 Additional Packages

- 🔄 workflows: update github actions to latest versions by @SuperKali  
- 🔄 `banana-utils`: sync banana-update and use sdk-master-index for workflows by @SuperKali  
- 🔼 quectel-cm: bump cmake_minimum_required to 3.5 by @SuperKali  
- 🌟 `luci-app-3ginfo`-lite: improve modem temperature detection with multi-level fallback by @SuperKali  
- 🛠️ `luci-app-3ginfo`-lite: migrate icons from png to svg by @SuperKali  
- 📦 sync package versions for apk format support by @SuperKali  
- 🔄 banana-update: show other tracks and allow config preserve on cross-version by @SuperKali  
- 🛠️ workflows: always inject apk key and move detect after defconfig by @SuperKali  
- 🛠️ workflows: write apk key to private-key.pem and inject before compile by @SuperKali  
- 🐛 workflows: fix apk key path and openssl config for sdk builds by @SuperKali  
- 🐛 workflows: fix ftp deploy deleting keys by syncing both before upload by @SuperKali  
- 🛠️ workflows: use sdk-master-index.json for sdk resolution by @SuperKali  
- ➕ `banana-utils`: add dual ipk/apk support and update banana-update by @SuperKali  
- 🐛 `luci-app-fan`: fix save & apply not applying changes by @SuperKali  
- ⚙️ `luci-app-fan`: migrate config page from lua cbi to js client-side view by @SuperKali  

### 🍌 BananaWRT Core

- 🔄 update-script: show other tracks and allow config preserve on cross-version by @SuperKali  
- 🧹 chore: remove ledtrig-netdev kernel patch, no longer needed by @SuperKali  
- 🐛 use directory listing url format for firmware download link by @SuperKali  
- ➕ feat(ci): add ftp retention policy, keep max 4 builds per track and cleanup old ones by @SuperKali  
- 📢 feat(changelog): support multiple feed branches for multi-version by @SuperKali  
- 🐛 fix(ci): exclude sdk/imagebuilder/toolchain from firmware upload, include all other target files by @SuperKali  
- 🐛 fix(ci): install lftp before ftp upload if not available by @SuperKali  
- 🏗️ revert(config): remove ccache, causes liblzo build failure by @SuperKali  
- 🐛 fix(ci): use ubuntu-latest for x64 builds, self-hosted for arm64 by @SuperKali  
- 🐛 fix(ci): pre-cleanup old build dir and sudo rm for ccache leftovers by @SuperKali  
- 🐛 fix(ci): handle flat artifact layout in sdk upload step by @SuperKali  
- ⚙️ feat(config): enable ccache for faster rebuilds by @SuperKali  
- ♻️ refactor: resolve versions from version.json instead of hardcoding by @SuperKali  
- 🐛 use semicolon for feed branch syntax and bump nightly to 25.12.0-rc1 by @SuperKali  
- 🔼 fota from repo.superkali.me with cross-version upgrade by @SuperKali  
- 🛠️ multi-version checker, promotion workflow and sdk trigger by @SuperKali  
- 🏗️ reusable build workflow with ftp firmware upload by @SuperKali  
- ➕ add version-aware patch-manager, metadata and feed branch support by @SuperKali  
- ♻️ refactor: restructure config and patches for multi-version support by @SuperKali  
- 🔼 build(deps): bump softprops/action-gh-release from 2.5.0 to 2.6.1 (#122) by @dependabot[bot]  
- 🔼 build(deps): bump actions/upload-artifact from 6 to 7 (#120) by @dependabot[bot]  
- 🔼 build(deps): bump actions/download-artifact from 7 to 8 (#121) by @dependabot[bot]  
- 🔄 update immortalwrt stable to version 24.10.5 by @SuperKali  
- 🐛 fix(ci): improve sdk artifact copy logic with debugging and fallback paths by @SuperKali  
- 🔼 bump immortalwrt to version v24.10.5 (#119) by @SuperKali  

---

## [2025-12-21]

### 🧩 Additional Packages

- 🔼 build(deps): bump actions/upload-artifact from 5.0.0 to 6.0.0 (#19) by @dependabot[bot]  
- 🔼 build(deps): bump actions/download-artifact from 6.0.0 to 7.0.0 (#18) by @dependabot[bot]  
- 🔼 build(deps): bump actions/checkout from 6.0.0 to 6.0.1 (#17) by @dependabot[bot]  

### 🍌 BananaWRT Core

- ⏪ revert "dts: export gpio 20 for m.2 5g modem power control" by @SuperKali  
- 🔼 build(deps): bump actions/upload-artifact from 5 to 6 (#117) by @dependabot[bot]  
- 🔼 build(deps): bump peter-evans/create-pull-request from 7 to 8 (#116) by @dependabot[bot]  
- 🔼 build(deps): bump actions/download-artifact from 6 to 7 (#115) by @dependabot[bot]  
- 🛠️ dts: export gpio 20 for m.2 5g modem power control by @SuperKali  
- 🔼 build(deps): bump softprops/action-gh-release from 2.4.2 to 2.5.0 (#113) by @dependabot[bot]  
- 🔄 docs: update changelog for 2025-12-05 (#114) by @SuperKali  

---

## [2025-12-05]

### 🧩 Additional Packages

- 🗑️ atc-fib-fm350_gl: remove sms handling to avoid conflicts by @SuperKali  
- 🐛 `luci-app-sms`-tool-js: fix sms display and enable message merging by @SuperKali  
- 🔼 build(deps): bump actions/checkout from 5.0.0 to 6.0.0 (#16) by @dependabot[bot]  

### 🍌 BananaWRT Core

- 🔼 build(deps): bump actions/checkout from 5 to 6 (#111) by @dependabot[bot]  
- 🔄 chore: update bpi-r3-mini dts files pulled from upstream by @SuperKali  
- 🔼 build(deps): bump softprops/action-gh-release from 2.4.1 to 2.4.2 (#109) by @dependabot[bot]  

---

## [2025-11-03]

### 🧩 Additional Packages

- 🔼 build(deps): bump mattraks/delete-workflow-runs from 2.0.6 to 2.1.0 (#12) by @dependabot[bot]  
- 🔼 build(deps): bump actions/download-artifact from 5.0.0 to 6.0.0 (#13) by @dependabot[bot]  
- 🔼 build(deps): bump actions/upload-artifact from 4.6.2 to 5.0.0 (#14) by @dependabot[bot]  

### 🍌 BananaWRT Core

- 🔼 bump immortalwrt stable to version 24.10.4 by @SuperKali  
- 🐛 sdk artifacts ftp upload with rsync by @SuperKali  
- 🔼 bump immortalwrt to version v24.10.4 (#105) by @SuperKali  
- 🔼 build(deps): bump actions/download-artifact from 5 to 6 (#102) by @dependabot[bot]  
- 🔼 build(deps): bump mattraks/delete-workflow-runs from 2.0.6 to 2.1.0 (#103) by @dependabot[bot]  
- 🔼 build(deps): bump actions/upload-artifact from 4 to 5 (#104) by @dependabot[bot]  
- 🔄 docs: update changelog for 2025-10-20 (#101) by @SuperKali  

---

## [2025-10-20]

### 🧩 Additional Packages

- 🐛 quectel-cm: fix no internet detection by @SuperKali  
- 🐛 `banana-utils`: fix missing dependency by @SuperKali  
- 🔼 workflow: bump version of matrix builder by @SuperKali  
- ➕ `banana-utils`: add timeout on banner and bump version by @SuperKali  

### 🍌 BananaWRT Core

- 🔼 build(deps): bump softprops/action-gh-release from 2.3.4 to 2.4.1 (#100) by @dependabot[bot]  
- 🔼 build(deps): bump softprops/action-gh-release from 2.3.3 to 2.3.4 (#99) by @dependabot[bot]  
- 🔼 bump immortalwrt stable to version v24.10.3 by @SuperKali  

---

## [2025-09-24]

### 🧩 Additional Packages

- 🔼 build(deps): bump actions/download-artifact from 4.3.0 to 5.0.0 (#9) by @dependabot[bot]  
- 🔼 build(deps): bump actions/checkout from 4.2.2 to 5.0.0 (#10) by @dependabot[bot]  
- 🔼 build(deps): bump samkirkland/ftp-deploy-action from 4.3.5 to 4.3.6 (#11) by @dependabot[bot]  

### 🍌 BananaWRT Core

- 🔼 bump immortalwrt to version v24.10.3 (#95) by @SuperKali  
- 🔼 build(deps): bump softprops/action-gh-release from 2.3.2 to 2.3.3 (#93) by @dependabot[bot]  
- 🔼 build(deps): bump actions/setup-python from 5 to 6 (#94) by @dependabot[bot]  
- 🐛 stable - prevent ethernet led from blinking unexpectedly by @SuperKali  
- 🔄 docs: update changelog for 2025-08-30 (#92) by @SuperKali  

---

## [2025-08-30]

### 🍌 BananaWRT Core

- ➕ workflow: add nproc option on selfhost by @SuperKali  
- 🐛 prevent ethernet led from blinking unexpectedly by @SuperKali  
- 🔄 docs: update changelog for 2025-08-29 (#91) by @SuperKali  

---

## [2025-08-29]

### 🍌 BananaWRT Core

- 🐛 patch-manager: fix count files by @SuperKali  
- 🐛 patch-manager: fix patch dir by @SuperKali  
- 🐛 patch-manager: fix source to formatter.sh by @SuperKali  
- 🐛 patch-manager: fix source to formatter.sh by @SuperKali  
- ➕ scripts: add patch-manager to handle all custom stuff by @SuperKali  
- 🐛 patch: fix space on name of the driver by @SuperKali  
- ➕ kernel: add new directory for add custom kernel configuration and add a following patch by @SuperKali  

---

## [2025-08-23]

### 🧩 Additional Packages

- ➕ `luci-app-fan`: add pwm inverted option by @SuperKali  

---

## [2025-08-19]

### 🧩 Additional Packages

- ➕ `luci-app-fan`: add support to fibocom fm160 by @SuperKali  
- 🐛 `luci-app-fan`: fix at+temp for fibocom fm350 by @SuperKali  
- ➕ `luci-app-fan`: add at+temp command on fm350 by @SuperKali  
- 🐛 quectel-cm: fix wrong dependency by @SuperKali  
- ➕ `luci-app-fan`: add automatic modem detection by @SuperKali  

### 🍌 BananaWRT Core

- 🔼 build(deps): bump actions/checkout from 4 to 5 (#88) by @dependabot[bot]  
- 🔄 docs: update changelog for 2025-08-18 (#87) by @SuperKali  

---

## [2025-08-18]

### 🧩 Additional Packages

- 🐛 fix quectel/fibocom pcie issues by @SuperKali  
- 🛠️ testing configuration if it works or not on quectel-cm by @SuperKali  
- 🛠️ quectel-cm: fixing issue that sometime connection not working by @SuperKali  
- ➕ luci-proto-quectel: add support for mhi devices (pcie) by @SuperKali  

### 🍌 BananaWRT Core

- 🔼 build(deps): bump actions/download-artifact from 4 to 5 (#86) by @dependabot[bot]  

---

## [2025-08-01]

### 🧩 Additional Packages

- 🔼 `luci-app-3ginfo` and hide temperature when is zero by @SuperKali  
- 🛠️ `luci-app-3ginfo`-lite: correct grammar issue by @SuperKali  
- 🛠️ adding new packages: luci-proto-quectel & quectel-cm by @SuperKali  

### 🍌 BananaWRT Core

- 🗑️ scripts: remove luci-proto-quectel & quectel-cm from stock packages by @SuperKali  
- 🏗️ workflow: build sdk matrix, change ftp action to manual command by @SuperKali  
- 🔄 docs: update changelog for 2025-07-12 (#84) by @SuperKali  

---

## [2025-07-12]

### 🍌 BananaWRT Core

- 🔼 bump (stable) immortalwrt to version v24.10.2 by @SuperKali  
- 🛠️ workflow: sdk added nproc input by @SuperKali  

---

## [2025-06-26]

### 🍌 BananaWRT Core

- 🔼 bump immortalwrt to version v24.10.2 (#80) by @SuperKali  
- 🔄 docs: update changelog for 2025-06-19 (#79) by @SuperKali  

---

## [2025-06-19]

### 🧩 Additional Packages

- 🐛 3ginfo: fix netdrv value to retrieve qmi protocol for fibocom fm160 by @SuperKali  
- ➕ modem: add first support to fibocom fm160-eau on 3ginfo-lite & `modemband` package by @SuperKali  
- 🐛 `linkup-optimization`: fix locatime by timezone by @SuperKali  

### 🍌 BananaWRT Core

- 🔼 build(deps): bump softprops/action-gh-release from 2.2.2 to 2.3.2 (#77) by @dependabot[bot]  

---

## [2025-06-08]

### 🧩 Additional Packages

- 🛠️ `banana-utils`: added the current firmware information on banana-updater script by @SuperKali  
- 🔼 `luci-app-fan` and allow to compile for all devices by @SuperKali  
- 🗑️ atc-fib-fm350_gl: remove detect_and_set_apn from unnecessary checks by @SuperKali  

### 🍌 BananaWRT Core

- 🔄 scripts: updated banana-update script from `banana-utils` package by @SuperKali  

---

## [2025-06-01]

### 🧩 Additional Packages

- 🐛 workflow: fix builder packages by @SuperKali  
- 🐛 atc-apn-database: fix compile on arm64 by @SuperKali  
- 🐛 workflows: fix permission on script execution by @SuperKali  
- 🛠️ workflows: renamed some script with new's by @SuperKali  
- 🐛 atc-fib-fm350_gl: fix minor issue when debug is enabled by @SuperKali  

### 🍌 BananaWRT Core

- 🐛 changelog: fix some issue on changelog  generator by @SuperKali  
- 🐛 changelog: trying to fix duplicated commits by @SuperKali  
- 🛠️ scripts: checks if file exist by @SuperKali  
- 🐛 dts: add missing #address-cells and #size-cells to fix the dtc warnings by @SuperKali  
- 🗑️ scripts: remove empty space on metadata generator by @SuperKali  
- 🐛 scripts: fix error on source formatter.sh by @SuperKali  
- 🐛 metadata: fix formatter source by @SuperKali  
- 🐛 workflows: fix create release tag by @SuperKali  
- 🏗️ scripts: added formatted info on build workflow by @SuperKali  
- ➕ scripts: add packages mapping to avoid errors by @SuperKali  
- 🐛 scripts: fix some issue on setup script by @SuperKali  
- 🛠️ scripts: better check if packages is already installed by @SuperKali  
- 🛠️ workflow: aligned all script for generate bananawrt metadata by @SuperKali  
- 🗑️ workflow: remove print empty release tag by @SuperKali  
- 🛠️ workflow: testing metadata generator into the bananawrt system by @SuperKali  
- 🛠️ scripts: moved to the correct directory and named with correctly name by @SuperKali  

---


## [2025-05-21]

### 🧩 Additional Packages

- 🗑️ Atc-apn-database and atc-fib-fm350_gl: remove unnecessary information by @SuperKali  
- 🐛 Atc-apn-database & atc-fib-fm350_gl, minor fixes by @SuperKali  
- ➕ Atc-apn-database: Bump version and added MIT License by @SuperKali  
- 🔄 `linkup-optimization`: Removed wifi config and updated network conf by @SuperKali  

---


## [2025-05-11]

### 🧩 Additional Packages

- ➕ Added support for automatic APN detection by using atc-apn-database package by @SuperKali  
- ➕ Luci-proto-atc & atc-fib-fm350: clean up and add check if apn is already configured by @SuperKali  
- 🔼 Bump: `linkup-optimization` to 2.23 by @SuperKali  
- 🗑️ `linkup-optimization`: Remove default apn by @SuperKali  
- 🐛 ATC: minor fixes on apn auto detection by @SuperKali  
- 🐛 ATC: minor fixes on apn auto detection by @SuperKali  
- 🐛 ATC: fix some issue on apn auto detection by @SuperKali  
- 📢 ATC: first support to auto apn connection by @SuperKali  
- 🔼 Bumps: `linkup-optimization` and luci-app-sms-tool and revert AT port to ttyUSB1 by @SuperKali  

---


## [2025-05-04]

### 🧩 Additional Packages

- 🔄 `luci-app-3ginfo`: Remove adb dependency by @SuperKali  

---


## [2025-05-01]

### 🍌 BananaWRT Core

- 🔼 Bump stable version to v24.10.1 by @SuperKali  
- 🔄 Docs: Update CHANGELOG for 2025-04-24 (#54) by @SuperKali  
- 🔼 Bump actions/download-artifact from 4.2.1 to 4.3.0 (#6) by @dependabot[bot]  

---


## [2025-04-24]

### 🧩 Additional Packages

- 🐛 `banana-utils`: Fix hostname function. by @SuperKali  
- 🌟 `luci-app-fan`: Improve hardware path detection in uci-defaults script by @SuperKali  
- 🐛 `luci-app-fan`: Fix some stuff by @SuperKali  
- 🔄 `luci-app-fan`: Remove warning if pwm_enable not exist and remove the box from UI by @SuperKali  
- 🐛 `luci-app-fan`: Fix an issue if pwm enable is missing by @SuperKali  
- 🐛 `banana-utils`: Fix repository configuration. by @SuperKali  

### 🍌 BananaWRT Core

- 🔼 Bump actions/setup-python from 4 to 5 (#50) by @dependabot[bot]  
- 🔼 Bump softprops/action-gh-release from 2.2.1 to 2.2.2 (#51) by @dependabot[bot]  
- 🔄 Docs: Update CHANGELOG for 2025-04-18 (#48) by @SuperKali  

---


## [2025-04-18]

### 🧩 Additional Packages

- 🐛 `banana-utils`: Fix repository configuration. by @SuperKali  

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
📅 Release date: **April 22, 2026**