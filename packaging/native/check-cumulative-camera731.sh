#!/usr/bin/env bash
# COPR only: verify the combined prepared inputs and actual production output.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
output=$(realpath -m "${2:?Production output}")
phase=${3:?prepared or linked}
profile=$kernel/native-profile
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
[[ $phase == prepared || $phase == linked ]]
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
printf '%s  %s\n' 739882b3a07fc6a701bae81ac6623a4b576871bd4289de3a095acabc20d49d34 \
 "$profile/native.config" | sha256sum -c --strict -
jq -e '.package_family=="senemos-uke-linux-kernel-mainline-unstable" and
 .kernel_abi_suffix=="-unstable" and .qualified_touch_layer==1 and
 .queued_kernel_layer==1 and .o82_memory_layer==1 and .ssc_transaction_layer==1 and
 .camcc_bootstrap_layer==1 and .cdsp_actlr_layer==1 and
 .o82_private_color_bundle_version==5 and .o82_color_initial_preset=="" and
 .o82_color_dma_enabled==false and .native_hdr_advertised==false and
 .camcc_probe_observation_abi==1 and .ssc_observation_abi==1 and
 .gmu_irq_owned_acknowledgement and .ssc_qmi_transaction_id_returns_id and
 .automatic_seamless_staging_required and .preserve_local_rollback_preference and
 .package_rollback_default=="enforced" and .front_eeprom_read_only and
 .speaker_controls_present_without_graph_admission and .speaker_protected_runtime_abi==1 and
 .speaker_protection_graph_admitted==false and .speaker_gain_ceiling==223 and
 .speaker_physical_protection_qualified==false and
 .speaker_legacy_fixture_layer_commit=="f05c32a879b9c56abe3531365f95b85684af4510" and
 .speaker_inherited_audio_fixtures_adapted==true and
 (.front_geni_dt_activation|not) and (.front_eeprom_dt_activation|not) and
 (.camera_sensor_dt_activation|not) and (.camera_capture_graph_activation|not) and
 (.cdsp_auto_boot|not) and (.physical_acceptance|not)' "$profile/source-composition.json" >/dev/null
cmp "$profile/src/camera/camcc-sm7675-data.h" "$kernel/drivers/clk/qcom/camcc-sm7675-data.h"
cmp "$profile/src/cdsp/uke-cdsp-smmu.c" "$kernel/drivers/iommu/arm/arm-smmu/uke-cdsp-smmu.c"
cmp "$profile/src/sensors/uke-ssc-iio.c" "$kernel/drivers/iio/common/uke-ssc/uke-ssc-iio.c"
cmp "$profile/src/audio/uke-fs19xx-runtime.c" "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
grep -Fx 'CFLAGS_uke-fs19xx-runtime.o += -DUKE_FS19XX_CONTROLS_ONLY' "$kernel/sound/soc/qcom/qdsp6/Makefile"
while IFS= read -r path; do
    [[ $path == src/display/* && $path != *.sh ]] || continue
    cmp "$profile/$path" "$kernel/drivers/gpu/drm/msm/disp/dpu1/${path##*/}"
done < <(jq -r '.imports[].path' "$profile/manifests/o82-memory-layer-20261105.json")
printf '%s  %s\n' df7ce54741d6a08c09ff607b86ce33c2057bb05c52b4d1a21d98b5be3395700e \
 "$kernel/drivers/media/i2c/ov08d10.c" | sha256sum -c --strict -
awk '/^static irqreturn_t a6xx_hfi_irq\(/ {emit=1} emit{print} emit&&/^}/{exit}' \
 "$kernel/drivers/gpu/drm/msm/adreno/a6xx_gmu.c" > "$work/irq.inc"
awk '/^static int a6xx_hfi_wait_for_msg_interrupt\(/ {emit=1} emit{print} emit&&/^}/{exit}' \
 "$kernel/drivers/gpu/drm/msm/adreno/a6xx_hfi.c" > "$work/wait.inc"
printf '%s  %s\n' 27090a6a64d647b12b24125bfe0ae5c3b22abbbc88f9c7202c8c921377a39ae3 "$work/irq.inc" \
 89cd584b2e2f874b7afa8e1a036a07ac5ae77a0802a82aa5e964a150751b3741 "$work/wait.inc" | sha256sum -c --strict -
node=/fragment@208/__overlay__/display-subsystem@ae00000/display-controller@ae01000
for supplier in 36 42; do
    overlay=$kernel/native-generated/display-$supplier.dtbo
    [[ $(fdtget -t s "$overlay" "$node" compatible) == qcom,sm7675-dpu ]]
    [[ $(fdtget -t x "$overlay" "$node" reg) == 'ae01000 8f000 aeb0000 1074 af80000 7000' ]]
done
if [[ $phase == prepared ]]; then
    printf '%s  %s\n' d7854b8571fd7cb4b61e6e958296b6691ada78d2a604663c168979121b3b3e7d \
     "$profile/tests/fixtures/inherited-audio-checks731.sh" | sha256sum -c --strict -
    (cd "$kernel"; CC=clang CXX=clang++ bash -euo pipefail "$profile/tests/fixtures/inherited-audio-checks731.sh")
    bash "$profile/tests/o82-touch-integrated731-contract.sh" "$kernel"
    bash "$profile/tests/o82-profile-loader-contract.sh" "$profile"
    bash "$profile/tests/o82-memory-bundle-contract.sh" "$profile"
    bash "$profile/tests/o82-lutbus-contract.sh"
    bash "$profile/tests/o82-regdma-transport-contract.sh" "$profile" "$kernel"
    bash "$profile/tests/o82-atomic-contract.sh" "$profile" "$kernel"
    for compiler in gcc clang; do
        CC=$compiler bash "$profile/tests/audio-controls-only-contract.sh" "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
        CC=$compiler bash "$profile/tests/audio-speaker-state-store-contract.sh" "$kernel"
    done
    for compiler in gcc clang; do
        CC=$compiler bash "$profile/tests/camcc-native731-contract.sh" "$kernel"
        CC=$compiler CAMCC_NATIVE_TEST_FLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
          bash "$profile/tests/camcc-native731-contract.sh" "$kernel"
    done
    printf 'Cumulative production preparation: exact qualified source/config/DT, retained gates and real callback models passed\n'
    exit 0
fi
[[ -s $output/arch/arm64/boot/Image ]]
[[ $(cat "$output/include/config/kernel.release") == "$(jq -er .kernel_release "$profile/source-composition.json")" ]]
for object in drivers/gpu/drm/msm/msm.o drivers/media/i2c/ov08d10.o \
 drivers/iio/common/uke-ssc/uke-ssc-iio.o drivers/clk/qcom/camcc-sm7675.o \
 drivers/iommu/arm/arm-smmu/arm-smmu-qcom.o sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o; do
    test -s "$output/$object"
    llvm-readelf -h "$output/$object" | grep -E 'Machine:.*AArch64'
done
! strings "$output/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o" | grep -F xiaomi,fs19xx-protected
llvm-nm --defined-only "$output/drivers/gpu/drm/msm/msm.o" > "$work/symbols"
for symbol in dpu_o82_lutbus_build dpu_o82_power_upload dpu_o82_profiles_load \
 dpu_o82_profiles_input dpu_o82_color_commit dpu_o82_upload a6xx_hfi_irq \
 a6xx_gmu_resume a6xx_hfi_set_freq msm_gpu_fault_crashstate_capture; do
    grep -E "[[:space:]][Tt][[:space:]]+$symbol$" "$work/symbols"
done
llvm-nm --undefined-only "$output/drivers/gpu/drm/msm/msm.o" > "$work/undefined"
! grep -E ' dpu_o82_(platform|regdma|upload|lutbus|power|color|profiles)_' "$work/undefined"
llvm-nm --defined-only "$output/drivers/iommu/arm/arm-smmu/arm-smmu-qcom.o" | \
 grep -E '[[:space:]][Tt][[:space:]]+qcom_uke_cdsp_init_context$'
for supplier in 36 42; do
    strings "$output/drivers/gpu/drm/msm/msm.o" | grep -Fx "qcom/sm7675/uke/o82-$supplier-color-v5.bin"
done
for module in drivers/gpu/drm/msm/msm.ko drivers/media/i2c/ov08d10.ko; do
    test -s "$output/$module"
    [[ $(modinfo -F vermagic "$output/$module") == "$(cat "$output/include/config/kernel.release") "* ]]
    signed=$output/boot-modules/lib/modules/$(cat "$output/include/config/kernel.release")/kernel/$module.zst
    test -s "$signed"
    [[ -n $(modinfo -F signer "$signed") ]]
done
printf 'Cumulative production Image and signed modules retain joint display/GMU/sensor/SSC/CAMCC/CDSP objects; physical acceptance remains open\n'
