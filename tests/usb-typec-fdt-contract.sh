#!/usr/bin/env bash
# Host-only actual FDT transforms on retained regular files; never a boot/device probe.
set -Eeuo pipefail
[[ $# == 4 && -d $1 && -f $2 && ! -L $2 && -d $3 && ! -e $4 ]] || exit 2
kernel=$(realpath "$1") input=$(realpath "$2") generated=$(realpath "$3")
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
out=$(realpath -m "$4")
[[ $(cat "$generated/usb-profile") == typec-v1 ]]
for name in ufs usb display; do [[ -f $generated/$name.dtbo && ! -L $generated/$name.dtbo ]]; done
mkdir -m700 "$out"
# Same O82 source without DP is a comparison baseline, not an admitted hardware DT.
cpp -nostdinc -undef -D__DTS__ -DO82_PANEL_VARIANT=42 -x assembler-with-cpp \
    -I "$kernel/include" "$root/src/display/sm7675-uke-native-display-oem-modes.dtso" > "$out/baseline.dts"
dtc -q -@ -I dts -O dtb -o "$out/baseline.dtbo" "$out/baseline.dts"
cat > "$out/entry.c" <<'C'
#include "uke-abl.c"
#include "uke-abl-native.h"
int uke_typec_native_fixture(void *fdt, void *overlay, size_t size)
{
    return uke_abl_native(fdt, overlay, size,
        "msm_drm.dsi_display0=qcom,mdss_dsi_o82_42_02_0b_dualdsi_dsc_vid:");
}
C
for source in "$kernel"/scripts/dtc/libfdt/*.c "$out/entry.c"; do
    "${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror \
        -I "$kernel/scripts/dtc/libfdt" -I "$root/src/boot" -I "$root/src/display" \
        -c "$source" -o "$out/$(basename "${source%.c}").o"
done
"${CXX:-c++}" -std=c++20 -O2 -Wall -Wextra -Werror -I "$kernel/scripts/dtc/libfdt" \
    -idirafter "$kernel/include" "$root/tests/usb-typec-fdt-check.cpp" "$out/"*.o -o "$out/usb-typec-fdt-check"
"$out/usb-typec-fdt-check" "$input" "$generated/ufs.dtbo" "$generated/usb.dtbo" \
    "$generated/display.dtbo" "$out/baseline.dtbo" "$out/admitted-full.dtb"
sha256sum "$root/src/boot/uke-abl.c" "$root/src/display/uke-abl-native.h" \
    "$root/tests/usb-typec-fdt-check.cpp" "$root/tests/usb-typec-fdt-contract.sh" \
    "$input" "$generated/ufs.dtbo" "$generated/usb.dtbo" "$generated/display.dtbo" \
    "$out/baseline.dtbo" "$out/admitted-full.dtb" > "$out/SHA256SUMS"
printf 'Full-profile host fixture completed; no tablet hardware acceptance\n'
