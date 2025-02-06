#!/bin/sh

VERSION=24.10.0
EMMC_PRELOADER="/tmp/immortalwrt-${VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-emmc-preloader.bin"
EMMC_BL31_UBOOT="/tmp/immortalwrt-${VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-emmc-bl31-uboot.fip"
EMMC_INITRAMFS="/tmp/immortalwrt-${VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-initramfs-recovery.itb"
SYSUPGRADE_IMG="/tmp/immortalwrt-${VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-squashfs-sysupgrade.itb"


echo -e "\033[1;36m"
echo "    ____                               _       ______  ______"
echo "   / __ )____ _____  ____ _____  ____ | |     / / __ \/_  __/"
echo "  / __  / __ \`/ __ \/ __ \`/ __ \/ __ \`/ | /| / / /_/ / / /   "
echo " / /_/ / /_/ / / / / /_/ / / / / /_/ /| |/ |/ / _, _/ / /    "
echo "/_____/\__,_/_/ /_/\__,_/_/ /_/\__,_/ |__/|__/_/ |_| /_/     "
echo -e "\033[1;33m          BananaWrt - The Ultimate System Updater 🚀       \033[0m"
echo ""
echo -e "\033[1;33m Ensure all required files are present in the \033[1;31m/tmp\033[1;33m directory:"
echo -e " - immortalwrt-\033[1;36m${VERSION}\033[1;33m-mediatek-filogic-bananapi_bpi-r3-mini-emmc-preloader.bin"
echo -e " - immortalwrt-\033[1;36m${VERSION}\033[1;33m-mediatek-filogic-bananapi_bpi-r3-mini-emmc-bl31-uboot.fip"
echo -e " - immortalwrt-\033[1;36m${VERSION}\033[1;33m-mediatek-filogic-bananapi_bpi-r3-mini-initramfs-recovery.itb"
echo -e " - immortalwrt-\033[1;36m${VERSION}\033[1;33m-mediatek-filogic-bananapi_bpi-r3-mini-squashfs-sysupgrade.itb"
echo -e "\033[0m"

echo ""
echo -e "\033[1;33m Press Enter to continue or CTRL+C to abort."
echo -e "\033[0m"
read dummy

log_info() {
  echo -e "\033[1;36m[INFO] $1\033[0m"
}

log_success() {
  echo -e "\033[1;32m[SUCCESS] $1\033[0m"
}

log_error() {
  echo -e "\033[1;31m[ERROR] $1\033[0m"
}

version_greater() {
  printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1 | grep -q "^$2$"
}

check_and_update_compat_version() {
  REQUIRED_VERSION="$1"
  CURRENT_VERSION=$(uci get system.@system[0].compat_version 2>/dev/null || echo "0.0")

  if version_greater "$REQUIRED_VERSION" "$CURRENT_VERSION"; then
    log_info "Updating compat_version from $CURRENT_VERSION to $REQUIRED_VERSION..."
    uci set system.@system[0].compat_version="$REQUIRED_VERSION"
    uci commit system
    log_success "compat_version updated to $REQUIRED_VERSION."
  else
    log_info "Current compat_version ($CURRENT_VERSION) is already compatible or greater."
  fi
}

log_info "Checking required files..."
for file in "$EMMC_PRELOADER" "$EMMC_BL31_UBOOT" "$EMMC_INITRAMFS" "$SYSUPGRADE_IMG"; do
  if [ ! -f "$file" ]; then
    log_error "Required file not found: $file"
    exit 1
  fi
done
log_success "All required files are present."

log_info "Enabling write access to /dev/mmcblk0boot0..."
echo 0 > /sys/block/mmcblk0boot0/force_ro
if [ $? -ne 0 ]; then
  log_error "Failed to enable write access to /dev/mmcblk0boot0."
  exit 1
fi
log_success "Write access to /dev/mmcblk0boot0 enabled."

flash_partition() {
  PARTITION="$1"
  IMAGE="$2"
  log_info "Clearing the partition $PARTITION..."
  dd if=/dev/zero of="$PARTITION" bs=1M count=4
  if [ $? -ne 0 ]; then
    log_error "Error clearing the partition $PARTITION."
    exit 1
  fi

  log_info "Writing $IMAGE to $PARTITION..."
  dd if="$IMAGE" of="$PARTITION" bs=1M
  if [ $? -ne 0 ]; then
    log_error "Error flashing $IMAGE to $PARTITION."
    exit 1
  fi
  log_success "$IMAGE written successfully to $PARTITION."
}

flash_partition /dev/mmcblk0boot0 "$EMMC_PRELOADER"
flash_partition /dev/mmcblk0p3 "$EMMC_BL31_UBOOT"
flash_partition /dev/mmcblk0p4 "$EMMC_INITRAMFS"

sync
log_success "Writing completed successfully."

log_info "Performing sysupgrade check with the file $SYSUPGRADE_IMG..."
SYSUPGRADE_LOG=$(sysupgrade -T "$SYSUPGRADE_IMG" 2>&1)
echo "$SYSUPGRADE_LOG"

if echo "$SYSUPGRADE_LOG" | grep -q "The device is supported, but the config is incompatible"; then
  REQUIRED_VERSION=$(echo "$SYSUPGRADE_LOG" | grep "incompatible" | awk -F'->' '{print $2}' | awk -F')' '{print $1}' | tr -d '[:space:]')
  if [ -n "$REQUIRED_VERSION" ]; then
    log_info "Detected required compat_version: $REQUIRED_VERSION"
    check_and_update_compat_version "$REQUIRED_VERSION"
  else
    log_error "Failed to detect compat_version. Exiting."
    exit 1
  fi
fi

log_info "Performing sysupgrade with the file $SYSUPGRADE_IMG..."
sysupgrade "$SYSUPGRADE_IMG"
if [ $? -ne 0 ]; then
  log_error "Error during sysupgrade."
  exit 1
fi

log_success "Sysupgrade completed successfully. Rebooting..."
