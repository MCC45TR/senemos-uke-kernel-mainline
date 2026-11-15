#!/usr/bin/bash
# COPR only: compile affected native units without building an Image.
set -Eeuo pipefail
[[ $# == 2 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1"); out=$(realpath -m "$2")
[[ ! -e $out ]]
bash "$kernel/native-profile/tests/reference-config734.sh" \
 "$kernel/native-generated/nfc-cdsp-before-reference/.config"
bash "$kernel/native-profile/tests/governor-config-contract.sh" \
 "$kernel/native-generated/nfc-cdsp-before-reference/.config" \
 "$kernel/native-generated/nfc-cdsp-reference/.config"
bash "$kernel/native-profile/src/display/apply-native-vrr734.sh" "$kernel"
bash "$kernel/native-profile/tests/vrr734-historical-source.sh" "$kernel"
mkdir "$out"
bash "$kernel/native-profile/tests/livepatch-config734.sh" "$kernel/scripts/config" "$kernel/native-profile/native.config"
tuple=$(bash "$kernel/native-profile/scripts/kernel-release.sh" json "$kernel/native-profile/manifests/cumulative-release.json")
[[ $(jq -er .version <<< "$tuple") == 7.3.4 ]]
release=$(jq -er .kernel_release <<< "$tuple")
localversion=$(jq -er .localversion <<< "$tuple")
cp "$kernel/native-profile/native.config" "$out/.config"
bash "$kernel/native-profile/src/livepatch/configure734.sh" "$kernel" "$out/.config" "$kernel/native-profile"
bash "$kernel/scripts/config" --file "$out/.config" --set-str INITRAMFS_SOURCE ''
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="$localversion" olddefconfig prepare modules_prepare
bash "$kernel/native-profile/tests/kernel-hardening-config-contract.sh" "$out/.config"
grep -Fxq 'CONFIG_LIVEPATCH=y' "$out/.config"
objects=(drivers/gpu/drm/msm/dsi/dsi_host.o drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.o
 drivers/gpu/drm/msm/dp/dp_mst_drm.o
 drivers/soc/qcom/pmic_glink_altmode.o
 drivers/gpu/drm/panel/panel-xiaomi-o82.o drivers/ufs/core/ufshcd.o
 drivers/tee/qcomtee/call.o drivers/tee/qcomtee/qtee-tpm-info.o
 sound/soc/qcom/qdsp6/q6apm.o
 drivers/leds/leds-uke-rgb.o
 drivers/power/supply/qcom_battmgr.o sound/soc/qcom/qdsp6/q6apm-dai.o
 kernel/livepatch/core.o kernel/livepatch/patch.o kernel/livepatch/shadow.o
 kernel/livepatch/state.o kernel/livepatch/transition.o
 certs/system_keyring.o certs/system_certificates.o
 drivers/media/platform/qcom/iris/qcom-iris.o
 sound/soc/qcom/uke-audio-card.o drivers/iio/common/uke-ssc/uke-ssc-iio.o)
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="$localversion" KCFLAGS=-Werror -j4 "${objects[@]}"
for object in "${objects[@]}"; do llvm-readelf -h "$out/$object" | grep -F AArch64; done
openssl x509 -in "$kernel/native-profile/src/livepatch/uke-livepatch-20261115.pem" -outform DER | cmp - "$out/certs/x509_certificate_list"
llvm-nm --undefined-only "$out/drivers/soc/qcom/pmic_glink_altmode.o" | grep -w system_freezable_wq
[[ $(cat "$out/include/config/kernel.release") == "$release" && ! -e $out/arch/arm64/boot/Image ]]
(cd "$out"; sha256sum "${objects[@]}") > "$out/native-objects.sha256"
sha256sum "$out/.config" > "$out/config.sha256"
paths=(Makefile drivers/nvmem/core.c)
for object in "${objects[@]}"; do
 case $object in drivers/media/platform/qcom/iris/qcom-iris.o|certs/system_certificates.o) continue;; esac
 paths+=("${object%.o}.c")
done
paths+=(drivers/media/platform/qcom/iris/iris_probe.c drivers/media/platform/qcom/iris/iris_vpu_common.c)
paths+=(certs/system_certificates.S)
(cd "$kernel"; sha256sum "${paths[@]}") > "$out/source.sha256"
printf 'Linux7.3.4 cumulative source, native LED and affected AArch64 objects including the full Iris composite passed; no Image, module load or firmware invocation\n'
