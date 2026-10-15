#!/usr/bin/env bash
# Host-only candidate entry; leaves the normal ABL source and build untouched.
set -Eeuo pipefail
[[ $# == 3 && -d $1 && -d $2 && $3 =~ ^(36|42)$ ]] || exit 2
kernel=$(realpath "$1") output=$(realpath "$2") variant=$3
here=$(cd -- "$(dirname -- "$0")" && pwd)
[[ -s $kernel/drivers/gpu/drm/panel/panel-xiaomi-o82.c ]]
cmp "$here/../boot/uke-abl.c" "$kernel/arch/arm64/kernel/uke-abl.c"
patch=$here/../../patches/display/0002-arm64-uke-native-abl-entry.patch
git -C "$kernel" apply --check "$patch"
timing_patch=$here/../../patches/display/0005-native-dpu-dsc-active-width.patch
git -C "$kernel" apply --check "$timing_patch"
cpp -nostdinc -undef -D__DTS__ -DO82_PANEL_VARIANT="$variant" -x assembler-with-cpp \
    -I "$kernel/include" "$here/sm7675-uke-native-display.dtso" > "$output/display.dts"
dtc -q -@ -I dts -O dtb -o "$output/display.dtbo" "$output/display.dts"
if [[ $variant == 36 ]]; then suffix=36_02_0a; else suffix=42_02_0b; fi
{
    printf '#define UKE_NATIVE_PANEL_SELECTOR "msm_drm.dsi_display0=qcom,mdss_dsi_o82_%s_dualdsi_dsc_vid:"\n' "$suffix"
    printf 'static unsigned char uke_native_overlay[] __initdata __aligned(8) = {\n'
    od -An -v -tx1 "$output/display.dtbo" | sed -E 's/[a-f0-9]{2}/0x&,/g'
    printf '};\n'
} > "$output/uke-native-display.h"
install -m644 "$output/uke-native-display.h" "$kernel/arch/arm64/kernel/uke-native-display.h"
install -m644 "$here/uke-abl-native.h" "$kernel/arch/arm64/kernel/uke-abl-native.h"
git -C "$kernel" apply "$patch"
git -C "$kernel" apply "$timing_patch"
sha256sum "$here/uke-abl-native.h" "$patch" "$output/display.dtbo" \
    "$timing_patch" "$kernel/arch/arm64/kernel/uke-abl.c" > "$output/native-entry-SHA256SUMS"
printf 'Isolated native entry prepared for O82 %s; only the initial 60 Hz mode is exposed\n' "$suffix"
