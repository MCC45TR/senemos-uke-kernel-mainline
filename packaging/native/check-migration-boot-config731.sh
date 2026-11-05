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
cp "$kernel/native-generated/migration-manager-before-native/.config" "$stage/before"
cp "$kernel/native-generated/migration-manager-waydroid/.config" "$stage/reference"
for config in "$stage/before" "$stage/reference"; do
 bash "$kernel/scripts/config" --file "$config" --set-str INITRAMFS_SOURCE "$out/boot-initramfs.cpio.gz"
done
bash "$profile/tests/kernel-manager-config-contract.sh" "$stage/before" "$out/.config" \
 "$profile/configs/kernel-manager/resources.config"
bash "$profile/tests/nfc-cohort-config731.sh" "$out/.config" "$stage/reference"
printf 'Embedded boot config: closed manager delta and complete independent NFC/network comparison pass\n'
