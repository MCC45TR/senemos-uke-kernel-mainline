#!/usr/bin/env bash
# Host-only packet decoder negatives; never writes a device or runs OEM code.
set -Eeuo pipefail
[[ $# == 4 && -x $1 && -s $2 && -s $3 && ! -e $4 ]] || exit 2
binary=$1 input=$2 expected=$3 out=$4
mkdir -p "$out"
"$binary" "$input" > "$out/data.h"
cmp "$expected" "$out/data.h"
panel=/soc/qcom,mdss_mdp@ae00000/qcom,mdss_dsi_o82_36_02_0a_dualdsi_dsc_vid/qcom,mdss-dsi-display-timings/timing@120
for scenario in truncated malformed width depth packet-type packet-size packet-channel packet-flags packet-delay; do
    cp "$input" "$out/$scenario.dtb"
    case $scenario in
        truncated) truncate -s 39 "$out/$scenario.dtb";;
        malformed) printf INVALID | dd of="$out/$scenario.dtb" conv=notrunc status=none;;
        width) fdtput -t u "$out/$scenario.dtb" "$panel" qcom,mdss-dsi-panel-width 1601;;
        depth) fdtput -t u "$out/$scenario.dtb" "$panel" qcom,mdss-dsc-bit-per-component 8;;
        packet-type) fdtput -t bx "$out/$scenario.dtb" "$panel" qcom,mdss-dsi-on-command 06 00 00 00 00 00 01 11;;
        packet-size) fdtput -t bx "$out/$scenario.dtb" "$panel" qcom,mdss-dsi-on-command 39 00 00 00 00 00 02 11;;
        packet-channel) fdtput -t bx "$out/$scenario.dtb" "$panel" qcom,mdss-dsi-on-command 39 00 01 00 00 00 01 11;;
        packet-flags) fdtput -t bx "$out/$scenario.dtb" "$panel" qcom,mdss-dsi-on-command 39 00 00 01 00 00 01 11;;
        packet-delay) fdtput -t bx "$out/$scenario.dtb" "$panel" qcom,mdss-dsi-on-command 39 00 00 00 ff 00 01 11;;
    esac
    if "$binary" "$out/$scenario.dtb" > "$out/$scenario.h"; then exit 1; fi
    [[ ! -s $out/$scenario.h ]]
done
ln -s data.h "$out/symlink.dtb"
if "$binary" "$out/symlink.dtb" > "$out/symlink.h"; then exit 1; fi
[[ ! -s $out/symlink.h ]]
printf 'O82 OEM output equality and ten bounded DT/packet/symlink rejection cases: passed\n'
