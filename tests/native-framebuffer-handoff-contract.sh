#!/usr/bin/env bash
# Test the exact native-only FDT transform with synthetic, non-hardware blobs.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/input.dts" <<'DTS'
/dts-v1/;
/ {
    compatible="xiaomi,uke";
    chosen {
        bootargs="msm_drm.dsi_display0=qcom,mdss_dsi_o82_42_02_0b_dualdsi_dsc_vid:";
        stdout-path="/chosen/framebuffer@1000";
        framebuffer@1000 {
            compatible="simple-framebuffer";status="okay";
            reg=<0x1000 0x1000>;width=<16>;height=<16>;stride=<64>;
            format="a8r8g8b8";backlight=<1>;
        };
    };
    soc {
        qcom,qupv3_0_geni_se@ac0000 { i2c@a80000 { ktz8866@11 {
            compatible="xiaomi,uke-ktz8866-primary";phandle=<1>;
        }; }; };
        display_gpio_regulator_vsp {compatible="regulator-fixed";phandle=<2>;};
        display_gpio_regulator_vsn {compatible="regulator-fixed";phandle=<3>;};
    };
    __symbols__ {};
};
DTS
cat > "$work/overlay.dts" <<'DTS'
/dts-v1/;
/plugin/;
/ {fragment@0 {target-path="/soc";__overlay__ {
    display-subsystem@ae00000 { dsi@ae94000 { panel@0 {test,native-panel;};};};
};};};
DTS
dtc -q -@ -I dts -O dtb "$work/input.dts" -o "$work/input.dtb"
dtc -q -@ -I dts -O dtb "$work/overlay.dts" -o "$work/overlay.dtbo"
"${CXX:-g++}" -std=c++20 -O2 -Wall -Wextra -Werror -UNDEBUG "$root/tests/abl-native-check.cpp" -lfdt -o "$work/check"
"$work/check" "$work/input.dtb" "$work/overlay.dtbo" "$work/output.dtb"
[[ $(fdtget -t s "$work/input.dtb" /chosen/framebuffer@1000 status) == okay ]]
[[ $(fdtget -t s "$work/input.dtb" /chosen stdout-path) == /chosen/framebuffer@1000 ]]
printf 'Actual native handoff: inherited fb disabled only after admitted overlay, no pixel/geometry changes, original input preserved and seven refusal cases passed; host only\n'
