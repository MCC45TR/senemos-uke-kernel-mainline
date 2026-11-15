#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
[[ $# == 2 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1"); out=$(realpath -m "$2")
[[ ! -e $out ]]
mkdir "$out"
cp "$kernel/native-profile/native.config" "$out/.config"
bash "$kernel/scripts/config" --file "$out/.config" --set-str INITRAMFS_SOURCE ''
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-28-unstable olddefconfig prepare modules_prepare
bash "$kernel/native-profile/tests/kernel-hardening-config-contract.sh" "$out/.config"
grep -Fx CONFIG_QCOMTEE=m "$out/.config"
objects=(drivers/tee/qcomtee/call.o drivers/tee/qcomtee/qtee-tpm-info.o drivers/tee/qcomtee/core.o)
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-28-unstable KCFLAGS=-Werror -j4 "${objects[@]}"
for object in "${objects[@]}"; do llvm-readelf -h "$out/$object" | grep -F AArch64; done
for symbol in uke_qtee_tpm_info_attach uke_qtee_tpm_info_detach; do
 llvm-nm --defined-only "$out/drivers/tee/qcomtee/qtee-tpm-info.o" | awk -v symbol="$symbol" '$NF==symbol{found=1}END{exit !found}'
 llvm-nm --undefined-only "$out/drivers/tee/qcomtee/call.o" | awk -v symbol="$symbol" '$NF==symbol{found=1}END{exit !found}'
done
llvm-nm --undefined-only "$out/drivers/tee/qcomtee/qtee-tpm-info.o" > "$kernel/native-generated/qtee-information733/imports.txt"
if grep -E 'tpm2?_startup|tpm_chip_register|tee_client_object_invoke_func|qcom_scm_ice' "$kernel/native-generated/qtee-information733/imports.txt"; then exit 1; fi
[[ $(cat "$out/include/config/kernel.release") == 7.3.3-28-unstable && ! -e $out/arch/arm64/boot/Image ]]
(cd "$out"; sha256sum "${objects[@]}" .config) > "$kernel/native-generated/qtee-information733/native-objects.sha256"
printf 'Actual QTEE call/core/information ARM64 objects passed-Werror; no Image, module load or firmware invocation\n'
