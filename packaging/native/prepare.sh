#!/usr/bin/env bash
# Prepare native source; the boot producer separately generates its initramfs.
set -Eeuo pipefail
kernel=$(realpath "${1:?Pass prepared kernel}")
profile=$(cd -- "$(dirname -- "$0")" && pwd)
output=$kernel/native-generated
mkdir -p "$output"
(cd "$profile"; sha256sum --check --strict --quiet SHA256SUMS)
export UKE_LLCC_PROFILE
UKE_LLCC_PROFILE=$(cat "$profile/llcc-profile")
case $UKE_LLCC_PROFILE in disabled|native-v1) ;; *) echo 'Unknown LLCC package profile' >&2; exit 2;; esac
bash "$profile/tests/wcd939x-status-contract.sh"
bash "$profile/tests/wlan-regulator-lifetime-contract.sh" "$kernel"
bash "$profile/tests/altmode-worker-contract.sh" "$kernel/drivers/soc/qcom/pmic_glink_altmode.c"
bash "$profile/tests/ucsi-partner-mode-contract.sh" "$kernel/drivers/usb/typec/ucsi/ucsi.c"
bash "$profile/tests/usb-qmp-mux-contract.sh" "$kernel/drivers/phy/qualcomm/phy-qcom-qmp-combo.c"
bash "$profile/tests/dispcc-dp-votes-contract.sh" "$profile/src/display/uke-dispcc-votes.c"
bash "$profile/tests/dp-aux-ddc-contract.sh" "$kernel/drivers/gpu/drm/msm/dp/dp_aux.c" "$kernel/drivers/gpu/drm/display/drm_dp_helper.c"
bash "$profile/tests/gpu-load-contract.sh" "$kernel/drivers/gpu/drm/msm/msm_gpu_devfreq.c"
bash "$profile/tests/gpu-fault-capture-contract.sh" "$kernel/drivers/gpu/drm/msm/msm_gpu.c"
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
bash "$profile/tests/light-cleanup.sh" "$kernel/drivers/leds/flash/leds-qcom-flash.c"
git -C "$kernel" apply --check "$profile/patches/boot/0011-qcom-flash-torch-steps.patch"
git -C "$kernel" apply "$profile/patches/boot/0011-qcom-flash-torch-steps.patch"
bash "$profile/tests/light-brightness.sh" "$kernel/drivers/leds/flash/leds-qcom-flash.c"
bash "$profile/src/display/prepare-source.sh" "$kernel"
bash "$profile/tests/dp-hdr-contract.sh" "$kernel"
bash "$profile/tests/dp-connector-state-contract.sh" "$kernel/drivers/gpu/drm/msm/dp/dp_drm.c"
bash "$profile/tests/dp-lane-limit-contract.sh" "$kernel"
bash "$profile/src/input/prepare-source.sh" "$kernel"
bash "$profile/src/display/prepare-native-abl-source.sh" "$kernel" "$output" 42
if [[ $(cat "$profile/audio-profile") == hdmi-only ]]; then
    git -C "$kernel" apply --check "$profile/patches/boot/0009-uke-displayport-dma-scope.patch"
    git -C "$kernel" apply "$profile/patches/boot/0009-uke-displayport-dma-scope.patch"
    bash "$profile/tests/dp-audio-admission-contract.sh" "$kernel"
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
    bash "$profile/tests/dp-audio-fdt-contract.sh" "$kernel"
    bash "$profile/tests/dp-audio-topology-contract.sh"
fi
printf 'Exact seven-mode O82-42 native source prepared; no private boot input\n'
