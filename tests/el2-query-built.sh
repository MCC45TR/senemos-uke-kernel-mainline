#!/usr/bin/env bash
# Executed by Actions after native compilation, never on the tablet.
set -Eeuo pipefail
[[ $# == 4 ]] || exit 64
kernel=$(realpath "$1") out=$(realpath "$2")
buildroot=$(realpath "$3") release=$4
grep -Fx 'CONFIG_QCOM_UKE_EL2_QUERY=y' "$out/.config"
grep -Fx 'CONFIG_KVM=y' "$out/.config"
! grep -Eq '^CONFIG_QCOM_UKE_(EL2_ENTRY|GUNYAH_EXIT)=y$' "$out/.config"
grep -F 'UKE_EL2_QUERY: query-only' "$kernel/drivers/firmware/qcom/uke-el2-query.h"
bash "$kernel/native-profile/tests/kernel-hardening-config-contract.sh" "$out/.config"
bash "$kernel/native-profile/tests/kernel-module-signatures-contract.sh" "$kernel" \
    "$buildroot/usr/lib/modules/$release" \
    "$buildroot/usr/share/senemos/uke/$release/module-signing.x509"
"$out/boot-image" inspect "$out/linux.img"
"$out/boot-image" inspect "$out/userdata.img"
[[ $(make -s -C "$kernel" O="$out" LOCALVERSION="-${release#*-}" kernelrelease) == "$release" ]]
[[ ! -e $buildroot/usr/lib/senemos/default-boot.img ]]
[[ -L $buildroot/usr/lib/senemos/kvm-default-boot.img ]]
jq -e '.automatic_kernel_activation == false' \
    "$buildroot/usr/share/senemos/uke/kvm-singleboot.json" >/dev/null
strings "$out/vmlinux" | grep -F 'UKE_EL2_QUERY: query-only'
printf 'Query-only kernel, signed modules, exact ABI and boot containers passed\n'
