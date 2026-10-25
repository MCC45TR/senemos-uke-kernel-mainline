#!/usr/bin/env bash
# Prepare native source; the boot producer separately generates its initramfs.
set -Eeuo pipefail
kernel=$(realpath "${1:?Pass prepared kernel}")
profile=$(cd -- "$(dirname -- "$0")" && pwd)
el2_profile=$(cat "$profile/el2-profile")
case $el2_profile in
    normal) ;;
    el2-require) bash "$profile/src/boot/prepare-el2-source.sh" "$kernel";;
    *) echo "Unadmitted EL2 profile: $el2_profile" >&2; exit 2;;
esac
output=$kernel/native-generated
mkdir -p "$output"
(cd "$profile"; sha256sum --check --strict --quiet SHA256SUMS)
export UKE_LLCC_PROFILE
UKE_LLCC_PROFILE=$(cat "$profile/llcc-profile")
case $UKE_LLCC_PROFILE in disabled|native-v1) ;; *) echo 'Unknown LLCC package profile' >&2; exit 2;; esac
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/wcd939x-status-contract.sh"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/wlan-regulator-lifetime-contract.sh" "$kernel"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/altmode-worker-contract.sh" "$kernel/drivers/soc/qcom/pmic_glink_altmode.c"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/ucsi-partner-mode-contract.sh" "$kernel/drivers/usb/typec/ucsi/ucsi.c"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/usb-qmp-mux-contract.sh" "$kernel/drivers/phy/qualcomm/phy-qcom-qmp-combo.c"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/dispcc-dp-votes-contract.sh" "$profile/src/display/uke-dispcc-votes.c"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/dp-aux-ddc-contract.sh" "$kernel/drivers/gpu/drm/msm/dp/dp_aux.c" "$kernel/drivers/gpu/drm/display/drm_dp_helper.c"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/gpu-load-contract.sh" "$kernel/drivers/gpu/drm/msm/msm_gpu_devfreq.c"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/gpu-fault-capture-contract.sh" "$kernel/drivers/gpu/drm/msm/msm_gpu.c"
export UKE_USB_PROFILE
UKE_USB_PROFILE=$(cat "$profile/usb-profile")
case $UKE_USB_PROFILE in peripheral|typec-v1) ;; *) exit 2;; esac
usb_cpp=()
[[ $UKE_USB_PROFILE != typec-v1 ]] || usb_cpp=(-DUKE_USB_TYPEC=1)
case $(cat "$profile/audio-profile") in
    disabled) ;;
    services-only) usb_cpp+=(-DUKE_AUDIO_SERVICES=1);;
    registration-only) usb_cpp+=(-DUKE_AUDIO_SERVICES=1 -DUKE_AUDIO_CARD=1);;
    hdmi-only) usb_cpp+=(-DUKE_AUDIO_SERVICES=1 -DUKE_AUDIO_HDMI=1);;
    *) printf 'Unknown audio development profile\n' >&2; exit 2;;
esac
install -m644 "$profile/src/audio/uke-audio-card.c" "$kernel/sound/soc/qcom/uke-audio-card.c"
alsatplg -c "$profile/src/audio/POCO-Pad-X1-AudioReach.conf" \
    -o "$output/POCO-Pad-X1-AudioReach-tplg.bin"
alsatplg -c "$profile/src/audio/POCO-Pad-X1-HDMI.conf" \
    -o "$output/POCO-Pad-X1-HDMI-tplg.bin"
cp "$kernel/drivers/regulator/qcom-rpmh-regulator-uke.c" "$output/rpmh-regulator-before-native.c"
bash "$profile/src/boot/prepare-abl-source.sh" "$kernel" "$output"
git -C "$kernel" apply --check "$profile/patches/boot/0010-qcom-flash-bounded-cleanup.patch"
git -C "$kernel" apply "$profile/patches/boot/0010-qcom-flash-bounded-cleanup.patch"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/light-cleanup.sh" "$kernel/drivers/leds/flash/leds-qcom-flash.c"
git -C "$kernel" apply --check "$profile/patches/boot/0011-qcom-flash-torch-steps.patch"
git -C "$kernel" apply "$profile/patches/boot/0011-qcom-flash-torch-steps.patch"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/light-brightness.sh" "$kernel/drivers/leds/flash/leds-qcom-flash.c"
bash "$profile/src/leds/prepare-source.sh" "$kernel"
bash "$profile/src/display/prepare-source.sh" "$kernel"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/dpu-color-topology-contract.sh" "$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_crtc.c"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/firmware-connector-identity-contract.sh" "$kernel/drivers/gpu/drm/sysfb/simpledrm.c"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/output-bits-contract.sh" "$kernel"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/dpu-output-affinity-contract.sh" "$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_kms.c"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/ucsi-debugfs-bounds-contract.sh" "$kernel/drivers/usb/typec/ucsi/debugfs.c"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/dpu-mixer-reservation-contract.sh" "$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_rm.c"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/dp-hdr-contract.sh" "$kernel"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/dsi-connector-state-contract.sh" "$kernel"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/dsi-color-depth-contract.sh" "$kernel/drivers/gpu/drm/msm/dsi/dsi_manager.c"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/dp-connector-state-contract.sh" "$kernel/drivers/gpu/drm/msm/dp/dp_drm.c"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/dp-stream-lifetime-contract.sh" "$kernel"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/dp-lane-limit-contract.sh" "$kernel"
bash "$profile/src/input/prepare-source.sh" "$kernel"
bash "$profile/src/display/prepare-native-abl-source.sh" "$kernel" "$output" 42
if [[ $(cat "$profile/audio-profile") == hdmi-only ]]; then
    git -C "$kernel" apply --check "$profile/patches/boot/0009-uke-displayport-dma-scope.patch"
    git -C "$kernel" apply "$profile/patches/boot/0009-uke-displayport-dma-scope.patch"
    [[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/dp-audio-admission-contract.sh" "$kernel"
    sha256sum "$profile/patches/boot/0009-uke-displayport-dma-scope.patch" >> "$output/abl-source-SHA256SUMS"
fi
# Replace only the generated graph with the explicit exact seven-mode profile.
cpp -nostdinc -undef -D__DTS__ -DO82_PANEL_VARIANT=42 -x assembler-with-cpp \
    "${usb_cpp[@]}" \
    -I "$kernel/include" "$profile/src/display/sm7675-uke-native-display-oem-modes.dtso" > "$output/display.dts"
dtc -q -@ -I dts -O dtb -o "$output/display.dtbo" "$output/display.dts"
{
    printf '#define UKE_NATIVE_PANEL_SELECTOR "msm_drm.dsi_display0=qcom,mdss_dsi_o82_42_02_0b_dualdsi_dsc_vid:"\n'
    printf 'static unsigned char uke_native_overlay[] __initdata __aligned(8) = {\n'
    od -An -v -tx1 "$output/display.dtbo" | sed -E 's/[a-f0-9]{2}/0x&,/g'
    printf '};\n'
} > "$kernel/arch/arm64/kernel/uke-native-display.h"
fdtdump "$output/display.dtbo" 2>/dev/null | grep -E '^[[:space:]]+xiaomi,oem-refresh-modes;' >/dev/null
if [[ $(cat "$profile/audio-profile") == hdmi-only ]]; then
    [[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/dp-audio-fdt-contract.sh" "$kernel"
    [[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$profile/tests/dp-audio-topology-contract.sh"
fi
printf 'Exact seven-mode O82-42 native source prepared; no private boot input\n'
