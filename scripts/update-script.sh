#!/bin/sh

VERSION=24.10.0-rc4

echo "Ensure all required files are present in the /tmp directory:"
echo " - immortalwrt-${VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-emmc-preloader.bin"
echo " - immortalwrt-${VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-emmc-bl31-uboot.fip"
echo " - immortalwrt-${VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-initramfs-recovery.itb"
echo " - immortalwrt-${VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-squashfs-sysupgrade.itb"
echo ""

echo "Press Enter to continue or CTRL+C to abort."
read dummy

EMMC_PRELOADER="/tmp/immortalwrt-${VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-emmc-preloader.bin"
EMMC_BL31_UBOOT="/tmp/immortalwrt-${VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-emmc-bl31-uboot.fip"
EMMC_INITRAMFS="/tmp/immortalwrt-${VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-initramfs-recovery.itb"
SYSUPGRADE_IMG="/tmp/immortalwrt-${VERSION}-mediatek-filogic-bananapi_bpi-r3-mini-squashfs-sysupgrade.itb"

if [ ! -f "$EMMC_PRELOADER" ]; then
  echo "Preloader file not found: $EMMC_PRELOADER"
  exit 1
fi

if [ ! -f "$EMMC_BL31_UBOOT" ]; then
  echo "BL31 U-Boot file not found: $EMMC_BL31_UBOOT"
  exit 1
fi

if [ ! -f "$EMMC_INITRAMFS" ]; then
  echo "Initramfs recovery file not found: $EMMC_INITRAMFS"
  exit 1
fi

if [ ! -f "$SYSUPGRADE_IMG" ]; then
  echo "Sysupgrade file not found: $SYSUPGRADE_IMG"
  exit 1
fi

echo 0 > /sys/block/mmcblk0boot0/force_ro

echo "Writing the preloader to /dev/mmcblk0boot0..."
dd if="$EMMC_PRELOADER" of=/dev/mmcblk0boot0
if [ $? -ne 0 ]; then
  echo "Error flashing the preloader."
  exit 1
fi
echo "Preloader written successfully."
sleep 2

echo "Writing the BL31 U-Boot to /dev/mmcblk0p3..."
dd if="$EMMC_BL31_UBOOT" of=/dev/mmcblk0p3
if [ $? -ne 0 ]; then
  echo "Error flashing the BL31 U-Boot."
  exit 1
fi
echo "BL31 U-Boot written successfully."
sleep 2

echo "Writing the initramfs recovery to /dev/mmcblk0p4..."
dd if="$EMMC_INITRAMFS" of=/dev/mmcblk0p4
if [ $? -ne 0 ]; then
  echo "Error flashing the initramfs recovery."
  exit 1
fi
echo "Initramfs recovery written successfully."
sleep 2

sync
echo "Writing completed successfully."

echo "Performing sysupgrade with the file $SYSUPGRADE_IMG..."
sysupgrade -F -c "$SYSUPGRADE_IMG"
if [ $? -ne 0 ]; then
  echo "Error during sysupgrade."
  exit 1
fi

echo "Sysupgrade completed successfully... Rebooting..."
