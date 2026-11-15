#!/usr/bin/env bash
# COPR only: close the effective boot configuration after embedding initramfs.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?prepared kernel}")
out=$(realpath "${2:?boot output}")
profile=$kernel/native-profile
grep -Fx "CONFIG_INITRAMFS_SOURCE=\"$out/boot-initramfs.cpio.gz\"" "$out/.config"
stage=$(mktemp -d "$kernel/native-generated/migration-boot.XXXXXX")
trap 'find "$stage" -depth -delete' EXIT
mkdir "$stage/before" "$stage/reference"
cp "$kernel/native-generated/migration-manager-before-native/.config" "$stage/before/.config"
cp "$kernel/native-generated/migration-manager-waydroid/.config" "$stage/reference/.config"
for directory in "$stage/before" "$stage/reference"; do
 bash "$kernel/scripts/config" --file "$directory/.config" --set-str INITRAMFS_SOURCE "$out/boot-initramfs.cpio.gz"
 make -s -C "$kernel" O="$directory" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig
done
bash "$profile/tests/kernel-manager-config-contract.sh" "$stage/before/.config" "$out/.config" \
 "$profile/configs/kernel-manager/resources.config"
bash "$profile/tests/nfc-cohort-config731.sh" "$out/.config" "$stage/reference/.config"
printf 'Embedded boot config: closed manager delta and complete independent NFC/network comparison pass\n'
