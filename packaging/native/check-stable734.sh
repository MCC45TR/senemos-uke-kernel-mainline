#!/usr/bin/bash
# COPR only: compile affected native units without building an Image.
set -Eeuo pipefail
[[ $# == 2 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1"); out=$(realpath -m "$2")
[[ ! -e $out ]]
mkdir "$out"
tuple=$(bash "$kernel/native-profile/scripts/kernel-release.sh" json "$kernel/native-profile/manifests/cumulative-release.json")
[[ $(jq -er .kernel_release <<< "$tuple") == 7.3.4-1-unstable ]]
cp "$kernel/native-profile/native.config" "$out/.config"
bash "$kernel/scripts/config" --file "$out/.config" --set-str INITRAMFS_SOURCE ''
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-1-unstable olddefconfig prepare modules_prepare
bash "$kernel/native-profile/tests/kernel-hardening-config-contract.sh" "$out/.config"
objects=(drivers/gpu/drm/msm/dsi/dsi_host.o drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.o
 drivers/soc/qcom/pmic_glink_altmode.o
 drivers/gpu/drm/panel/panel-xiaomi-o82.o drivers/ufs/core/ufshcd.o
 drivers/tee/qcomtee/call.o drivers/tee/qcomtee/qtee-tpm-info.o
 sound/soc/qcom/uke-audio-card.o drivers/iio/common/uke-ssc/uke-ssc-iio.o)
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-1-unstable KCFLAGS=-Werror -j4 "${objects[@]}"
for object in "${objects[@]}"; do llvm-readelf -h "$out/$object" | grep -F AArch64; done
llvm-nm --undefined-only "$out/drivers/soc/qcom/pmic_glink_altmode.o" | grep -w system_freezable_wq
[[ $(cat "$out/include/config/kernel.release") == 7.3.4-1-unstable && ! -e $out/arch/arm64/boot/Image ]]
(cd "$out"; sha256sum "${objects[@]}") > "$out/native-objects.sha256"
sha256sum "$out/.config" > "$out/config.sha256"
paths=(Makefile drivers/nvmem/core.c)
for object in "${objects[@]}"; do paths+=("${object%.o}.c"); done
(cd "$kernel"; sha256sum "${paths[@]}") > "$out/source.sha256"
printf 'Linux7.3.4 cumulative source and nine affected AArch64 objects passed; no Image, module load or firmware invocation\n'
