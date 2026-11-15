#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Source, final embedded profile and physical HWKM operation are separate gates.
set -Eeuo pipefail
[[ ! -e /etc/senemos/kernel-update.conf && ($# == 3 || $# == 4) ]]
kernel=$(realpath "$1"); out=$(realpath -m "$2"); phase=$3
layer=$kernel/hwkm-early
work=$kernel/native-generated/hwkm-early733
contract=$layer/manifests/hwkm-early-20261115.json
camera=$kernel/crm-passive
release=$(jq -er .kernel_release "$kernel/native-profile/source-composition.json")
if [[ $phase == source ]]; then
 [[ $# == 4 && ! -e $work ]]
 base=$(realpath "$4")
 mkdir -p "$work/before"
 cmp "$layer/src/boot/dracut/uke-hwkm.conf" "$base/usr/lib/modprobe.d/uke-hwkm.conf"
 modprobe --showconfig --config "$base/usr/lib/modprobe.d/uke-hwkm.conf" > "$work/kmod.conf"
 [[ $(grep -c '^options qcom_ice ' "$work/kmod.conf") == 1 ]]
 grep -Fx 'options qcom_ice use_wrapped_keys=1' "$work/kmod.conf"
 for tree in "$kernel/native-profile/native.config" "$kernel/boot-recipe/packaging/native/native.config"; do
  for setting in CONFIG_INITRAMFS_FORCE=y CONFIG_CMDLINE_FORCE=y CONFIG_QCOM_INLINE_CRYPTO_ENGINE=m CONFIG_SCSI_UFS_CRYPTO=y CONFIG_BLK_INLINE_ENCRYPTION=y; do
   grep -Fx "$setting" "$tree"
  done
 done
 grep -Fx 'drivers/soc/qcom/qcom_ice.ko.zst' "$kernel/boot-recipe/src/boot/early-modules.list"
 while IFS=$'\t' read -r path digest; do
  if [[ $digest == absent ]]; then [[ ! -e $kernel/$path && ! -L $kernel/$path ]];
  else
   printf '%s  %s\n' "$digest" "$kernel/$path" | sha256sum -c --strict --quiet -
   install -Dm644 "$kernel/$path" "$work/before/$path"
  fi
 done < <(jq -er '.runtime_units[]|[.path,.before_sha256]|@tsv' "$camera/manifests/camera-crm-passive-20261114.json")
 bash "$camera/src/camera/provider/apply-crm-passive733.sh" "$kernel" "$camera"
 jq -r '.runtime_units[]|.after_sha256+"  "+.path' "$camera/manifests/camera-crm-passive-20261114.json" > "$work/after.sha256"
 bash "$camera/tests/camcc-crm-passive.sh" "$camera/oracle/camcc-cliffs.c" | tee "$work/camera-checks.txt"
 for compiler in gcc clang; do
  for sanitizer in plain address-undefined; do
   flags=
   if [[ $sanitizer == address-undefined ]]; then flags='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer'; fi
   CC="$compiler" CAMCC_NATIVE_TEST_FLAGS="$flags" CAMCC_NATIVE_MUTATIONS=1 \
    bash "$camera/tests/camcc-native731-contract.sh" "$kernel" | tee -a "$work/camera-checks.txt"
  done
 done
 bash "$kernel/native-profile/tests/camcc-quarantine-sleep.sh" | tee -a "$work/camera-checks.txt"
 touch "$work/source-complete"
 printf 'Early HWKM source: original kmod parses embedded opt-in; ICE=m/first-probe prerequisites and signed passive-camera source delta retained; no hardware key operation\n'
 exit 0
fi
[[ -f $work/source-complete ]]
(cd "$kernel"; sha256sum -c --strict --quiet "$work/after.sha256")
[[ $(cat "$out/include/config/kernel.release") == "$release" ]]
if [[ $phase == linked ]]; then
 [[ ! -e $work/linked.sha256 ]]
 cmp "$layer/src/boot/dracut/uke-hwkm.conf" "$out/boot-initramfs/usr/lib/modprobe.d/uke-hwkm.conf"
 [[ -s $out/boot-initramfs/usr/lib/modules/$release/kernel/drivers/soc/qcom/qcom_ice.ko.zst ]]
 modprobe --showconfig --config "$out/boot-initramfs/usr/lib/modprobe.d/uke-hwkm.conf" > "$work/final-kmod.conf"
 grep -Fx 'options qcom_ice use_wrapped_keys=1' "$work/final-kmod.conf"
 gzip -dc "$out/boot-initramfs.cpio.gz" | cpio -t --quiet > "$work/cpio-members.txt"
 member=$(grep -Ex '([.]/|/)?usr/lib/modprobe[.]d/uke-hwkm[.]conf' "$work/cpio-members.txt")
 [[ -n $member && $(printf '%s\n' "$member" | wc -l) == 1 ]]
 gzip -dc "$out/boot-initramfs.cpio.gz" | cpio -i --to-stdout --quiet "$member" > "$work/embedded-hwkm.conf"
 cmp "$work/embedded-hwkm.conf" "$layer/src/boot/dracut/uke-hwkm.conf"
 for setting in CONFIG_INITRAMFS_FORCE=y CONFIG_CMDLINE_FORCE=y CONFIG_QCOM_INLINE_CRYPTO_ENGINE=m CONFIG_SCSI_UFS_CRYPTO=y; do grep -Fx "$setting" "$out/.config"; done
 for symbol in qcom_ice_generate_key qcom_ice_prepare_key; do
  llvm-nm --defined-only "$out/drivers/soc/qcom/qcom_ice.o" | awk -v symbol="$symbol" '$NF==symbol{found=1}END{exit !found}'
 done
 grep -aqF firmware-enabled-refused "$out/drivers/clk/qcom/camcc-sm7675.o"
 (cd "$out"; sha256sum drivers/clk/qcom/camcc-sm7675.o drivers/soc/qcom/qcom_ice.o drivers/ufs/host/ufs-qcom.o \
  boot-initramfs.cpio.gz arch/arm64/boot/Image vmlinux .config) > "$work/linked.sha256"
 printf 'Actual full Image/ICE/UFS/CAMCC and forced embedded initramfs sealed; no physical HWKM or key-release acceptance\n'
 exit 0
fi
[[ -s $work/linked.sha256 ]]
(cd "$out"; sha256sum -c --strict --quiet "$work/linked.sha256")
if [[ $phase == sealed ]]; then printf 'Final HWKM/camera sources and output unchanged after inherited checks\n'; exit 0; fi
[[ $# == 4 && ($phase == install || $phase == check) ]]
root=$(realpath -m "$4"); identity=$root/usr/share/senemos/uke/$release
if [[ $phase == install ]]; then
 install -m644 "$work/after.sha256" "$identity/hwkm-camera-source.sha256"
 install -m644 "$work/linked.sha256" "$identity/hwkm-early-linked.sha256"
 install -m644 "$contract" "$identity/hwkm-early-delivery.json"
 jq -n --arg release "$release" '{schema_version:1,kernel_release:$release,parent_full_build:11322009,
  passive_camera_source_build:11327411,early_wrapped_profile_embedded:true,full26_source_checks_projected:true,
  actual_output_objects_never_replaced:true,original_full26_features_retained:true,
  crm_activation_allowed:false,hardware_key_generated:false,cold_boot_reuse_proved:false,
  encrypted_io_proved:false,automatic_unlock_proved:false,physical_acceptance:false,new_runtime_packages:0}' > "$identity/hwkm-early-full-qualification.json"
else
 cmp "$work/after.sha256" "$identity/hwkm-camera-source.sha256"
 cmp "$work/linked.sha256" "$identity/hwkm-early-linked.sha256"
 cmp "$contract" "$identity/hwkm-early-delivery.json"
 jq --arg release "$release" -e '.kernel_release==$release and .early_wrapped_profile_embedded and .actual_output_objects_never_replaced and (.automatic_unlock_proved|not) and (.physical_acceptance|not)' "$identity/hwkm-early-full-qualification.json" >/dev/null
fi
printf 'Existing core HWKM/camera %s evidence checked; physical key qualification remains open\n' "$phase"
