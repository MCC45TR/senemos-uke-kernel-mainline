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
bash "$profile/tests/gpu-load-contract.sh" "$kernel/drivers/gpu/drm/msm/msm_gpu_devfreq.c"
bash "$profile/tests/qup-interconnect-contract.sh" "$kernel/drivers/interconnect/qcom/qnoc-cliffs-usb.c" 1
bash "$profile/tests/wpss-proxy-contract.sh" "$kernel/drivers/remoteproc/qcom_q6v5_pas.c"
bash "$profile/tests/pas-firmware-lifetime-contract.sh" "$kernel/drivers/remoteproc/qcom_q6v5_pas.c"
bash "$profile/tests/pas-stop-contract.sh" "$kernel/drivers/remoteproc/qcom_q6v5_pas.c"
bash "$profile/tests/mdt-memory-admission-contract.sh" "$kernel/drivers/soc/qcom/mdt_loader.c"
export UKE_USB_PROFILE
UKE_USB_PROFILE=$(cat "$profile/usb-profile")
case $UKE_USB_PROFILE in peripheral|typec-v1) ;; *) exit 2;; esac
usb_cpp=()
[[ $UKE_USB_PROFILE != typec-v1 ]] || usb_cpp=(-DUKE_USB_TYPEC=1)
case $(cat "$profile/audio-profile") in
    disabled) ;;
    services-only) usb_cpp+=(-DUKE_AUDIO_SERVICES=1);;
    *) printf 'Unknown audio development profile\n' >&2; exit 2;;
esac
cp "$kernel/drivers/regulator/qcom-rpmh-regulator-uke.c" "$output/rpmh-regulator-before-native.c"
bash "$profile/src/boot/prepare-abl-source.sh" "$kernel" "$output"
bash "$profile/src/display/prepare-source.sh" "$kernel"
bash "$profile/tests/qup-interconnect-contract.sh" "$kernel/drivers/interconnect/qcom/qnoc-cliffs-usb.c" 1 1
bash "$profile/src/display/prepare-native-abl-source.sh" "$kernel" "$output" 42
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
printf 'Exact seven-mode O82-42 native source prepared; no private boot input\n'
