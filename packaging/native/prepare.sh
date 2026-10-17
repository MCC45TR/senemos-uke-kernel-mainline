#!/usr/bin/env bash
# Prepare native source; the boot producer separately generates its initramfs.
set -Eeuo pipefail
kernel=$(realpath "${1:?Pass prepared kernel}")
profile=$(cd -- "$(dirname -- "$0")" && pwd)
output=$kernel/native-generated
mkdir -p "$output"
(cd "$profile"; sha256sum --check --strict --quiet SHA256SUMS)
bash "$profile/src/boot/prepare-abl-source.sh" "$kernel" "$output"
bash "$profile/src/display/prepare-source.sh" "$kernel"
bash "$profile/src/display/prepare-native-abl-source.sh" "$kernel" "$output" 42
# Replace only the generated graph with the explicit exact seven-mode profile.
cpp -nostdinc -undef -D__DTS__ -DO82_PANEL_VARIANT=42 -x assembler-with-cpp \
    -I "$kernel/include" "$profile/src/display/sm7675-uke-native-display-oem-modes.dtso" > "$output/display.dts"
dtc -q -@ -I dts -O dtb -o "$output/display.dtbo" "$output/display.dts"
{
    printf '#define UKE_NATIVE_PANEL_SELECTOR "msm_drm.dsi_display0=qcom,mdss_dsi_o82_42_02_0b_dualdsi_dsc_vid:"\n'
    printf 'static unsigned char uke_native_overlay[] __initdata __aligned(8) = {\n'
    od -An -v -tx1 "$output/display.dtbo" | sed -E 's/[a-f0-9]{2}/0x&,/g'
    printf '};\n'
} > "$kernel/arch/arm64/kernel/uke-native-display.h"
fdtdump "$output/display.dtbo" 2>/dev/null | grep -Eq '^[[:space:]]+xiaomi,oem-refresh-modes;'
printf 'Exact seven-mode O82-42 native source prepared; no private boot input\n'
