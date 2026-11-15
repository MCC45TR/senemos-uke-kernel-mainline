#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Native COPR objects only; never load a module or access a key/device.
set -Eeuo pipefail
[[ $# == 2 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1"); out=$(realpath -m "$2")
[[ ! -e $out ]]
mkdir "$out"
cp "$kernel/native-profile/native.config" "$out/.config"
bash "$kernel/scripts/config" --file "$out/.config" --set-str INITRAMFS_SOURCE ''
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-27-unstable olddefconfig prepare modules_prepare
bash "$kernel/native-profile/tests/kernel-hardening-config-contract.sh" "$out/.config"
objects=(drivers/soc/qcom/qcom_ice.o drivers/firmware/qcom/qcom_scm.o drivers/ufs/host/ufs-qcom.o \
 block/blk-crypto.o drivers/md/dm-inlinecrypt.o drivers/clk/qcom/camcc-sm7675.o)
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-27-unstable KCFLAGS=-Werror -j4 "${objects[@]}"
for object in "${objects[@]}"; do
 llvm-readelf -h "$out/$object" | grep -F AArch64
done
for symbol in qcom_ice_generate_key qcom_ice_prepare_key qcom_ice_get_supported_key_type; do
 llvm-nm --defined-only "$out/drivers/soc/qcom/qcom_ice.o" | awk -v symbol="$symbol" '$NF==symbol{found=1}END{exit !found}'
done
for symbol in qcom_scm_has_wrapped_key_support qcom_scm_generate_ice_key qcom_scm_prepare_ice_key; do
 llvm-nm --defined-only "$out/drivers/firmware/qcom/qcom_scm.o" | awk -v symbol="$symbol" '$NF==symbol{found=1}END{exit !found}'
done
for symbol in qcom_ice_generate_key qcom_ice_prepare_key; do
 llvm-nm --undefined-only "$out/drivers/ufs/host/ufs-qcom.o" | awk -v symbol="$symbol" '$NF==symbol{found=1}END{exit !found}'
done
grep -aqF 'Using HWKM. Supporting wrapped keys only.' "$out/drivers/soc/qcom/qcom_ice.o"
grep -aqF firmware-enabled-refused "$out/drivers/clk/qcom/camcc-sm7675.o"
[[ $(cat "$out/include/config/kernel.release") == 7.3.3-27-unstable ]]
[[ ! -e $out/arch/arm64/boot/Image ]]
(cd "$out"; sha256sum "${objects[@]}" .config) > "$kernel/native-generated/hwkm-early733/native-objects.sha256"
printf 'Actual candidate27 ICE/SCM/UFS/block/dm-inlinecrypt/CAMCC AArch64 objects passed-Werror; no Image, module load, firmware call or hardware key proof\n'
