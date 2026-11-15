#!/usr/bin/env bash
# Native COPR only. Preserve historical reference configs and compare every role.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?prepared kernel}")
out=$(realpath -m "${2:?production output}")
profile=$kernel/native-profile
fragment=$profile/configs/kernel-manager/resources.config
for role in native cdsp waydroid; do
 before=$kernel/native-generated/migration-manager-before-$role
 after=$kernel/native-generated/migration-manager-$role
 [[ ! -e $before && ! -e $after ]]
 mkdir -p "$before"
 if [[ $role == native ]]; then
  cp "$profile/configs/migration-before-native.config" "$before/.config"
 else
  cp "$kernel/native-generated/nfc-$role-reference/.config" "$before/.config"
 fi
 bash "$kernel/scripts/config" --file "$before/.config" --set-str INITRAMFS_SOURCE ''
 make -s -C "$kernel" O="$before" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig
 bash "$profile/packaging/native/apply-kernel-manager-config.sh" "$kernel" "$before/.config" "$after/.config" "$fragment"
 make -s -C "$kernel" O="$after" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig
 bash "$profile/tests/kernel-manager-config-contract.sh" "$before/.config" "$after/.config" "$fragment"
done
# Retain the old full comparison, then require the equally complete new one.
bash "$profile/tests/nfc-cohort-config731.sh" \
 "$kernel/native-generated/migration-manager-before-native/.config" \
 "$kernel/native-generated/migration-manager-before-waydroid/.config"
bash "$profile/tests/nfc-cohort-config731.sh" \
 "$kernel/native-generated/migration-manager-native/.config" \
 "$kernel/native-generated/migration-manager-waydroid/.config"
printf 'Manager migration: all three normalized closed config deltas and both old/new full NFC comparisons pass\n'
