#!/usr/bin/env bash
# COPR only: require the complete retained parent and exact admitted additions.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?prepared kernel}")
out=$(realpath -m "${2:?native output}")
phase=${3:?prepared, objects or linked}
profile=$kernel/native-profile
[[ $phase == prepared || $phase == objects || $phase == linked ]]
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
jq -e '.migration_parent_build==11263248 and .kernel_migration_layer==1 and
 .ssc_stk3bcx_als_layer==1 and .ssc_sip1328_als_layer==1 and .ssc_mount_matrix_layer==1 and
 .ssc_early_sample_layer==2 and .ssc_early_sample_requires_ack and
 .kernel_manager_resources_layer==1 and .hall_startup_layer==1 and
 .speaker_protected_layer_commit=="c2932addf1f9b885a9a559b40d1ce5b7d43fe98b" and
 .speaker_profile_mode=="protected-223" and .speaker_protection_graph_admitted and
 .speaker_gain_ceiling==223 and (.speaker_physical_protection_qualified|not) and
 (.native_hdr_advertised|not) and (.o82_color_dma_enabled|not) and
 (.camera_capture_graph_activation|not) and (.front_eeprom_dt_activation|not) and
 .front_eeprom_read_only and (.cdsp_auto_boot|not) and
 .automatic_seamless_staging_required and .preserve_local_rollback_preference and
 .package_rollback_default=="enforced" and (.normal_kernel_promotion|not)' \
 "$profile/source-composition.json" >/dev/null
cmp "$profile/src/sensors/uke-ssc-iio.c" "$kernel/drivers/iio/common/uke-ssc/uke-ssc-iio.c"
cmp "$profile/src/boot/uke-hardware.h" "$kernel/arch/arm64/kernel/uke-hardware.h"
printf '%s  %s\n' c7a271fb57d329cdbc31f0d8876af4c4ef95ee16e880137e7fd003a8f45630fd \
 "$profile/src/sensors/uke-ssc-iio.c" | sha256sum -c --strict -
printf '%s  %s\n' 14a7922f690bf1615ffa925e14e7da612da4d2c0e6338710662f3de0856c7cb3 \
 "$kernel/drivers/input/misc/qcom-smp2p-switch.c" | sha256sum -c --strict -
if [[ $phase == prepared ]]; then
 for compiler in gcc clang; do
  CC=$compiler bash "$profile/tests/hall-startup-contract.sh" "$kernel/drivers/input/misc/qcom-smp2p-switch.c"
  CC=$compiler HALL_TEST_FLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
   bash "$profile/tests/hall-startup-contract.sh" "$kernel/drivers/input/misc/qcom-smp2p-switch.c"
 done
 bash "$profile/tests/hall-startup-controls.sh" "$kernel"
 for order in metadata-first vectors-first; do
  bash "$profile/tests/ssc-rear-als-contract.sh" "$profile" "$kernel" "$order"
 done
 bash "$profile/tests/ssc-mount-matrix.sh"
 for compiler in g++ clang++; do CXX=$compiler bash "$profile/tests/hardware-dt.sh"; done
 printf 'Migration prepared: exact retained SSC, Hall and protected223 sources; physical gates remain open\n'
 exit 0
fi
initramfs=''
[[ $phase != linked ]] || initramfs=$out/boot-initramfs.cpio.gz
grep -Fx "CONFIG_INITRAMFS_SOURCE=\"$initramfs\"" "$out/.config"
before=$kernel/native-generated/migration-manager-$phase-before
reference=$kernel/native-generated/migration-manager-$phase-waydroid
mkdir -p "$before" "$reference"
cp "$kernel/native-generated/migration-manager-before-native/.config" "$before/.config"
cp "$kernel/native-generated/migration-manager-waydroid/.config" "$reference/.config"
for config in "$before/.config" "$reference/.config"; do
 bash "$kernel/scripts/config" --file "$config" --set-str INITRAMFS_SOURCE "$initramfs"
done
bash "$profile/tests/kernel-manager-config-contract.sh" \
 "$before/.config" "$out/.config" \
 "$profile/configs/kernel-manager/resources.config"
bash "$profile/tests/nfc-cohort-config731.sh" "$out/.config" \
 "$reference/.config"
bash "$profile/tests/kernel-hardening-config-contract.sh" "$out/.config"
objects=(drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o \
 sound/soc/codecs/fs19xx.o sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o arch/arm64/kernel/uke-abl.o)
for object in "${objects[@]}"; do
 test -s "$out/$object"
 llvm-readelf -h "$out/$object" | grep -E 'Machine:.*AArch64'
done
if [[ $phase == linked ]]; then
 test -s "$out/arch/arm64/boot/Image"
 [[ $(cat "$out/include/config/kernel.release") == "$(jq -er .kernel_release "$profile/source-composition.json")" ]]
 bash "$profile/packaging/native/check-speaker-inclusion.sh" "$kernel" linked "$out"
 for module in drivers/iio/common/uke-ssc/uke-ssc.ko sound/soc/codecs/snd-soc-fs19xx.ko \
  sound/soc/qcom/qdsp6/snd-q6apm.ko; do
  test -s "$out/$module"
  [[ $(modinfo -F vermagic "$out/$module") == "$(cat "$out/include/config/kernel.release") "* ]]
 done
fi
printf 'Migration %s: retained kernel interfaces, all three manager configurations, actual native objects and protection gates pass\n' "$phase"
