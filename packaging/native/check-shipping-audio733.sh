#!/usr/bin/bash
# Actual production objects only. SSC source integrity has one cumulative owner.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
out=$(realpath "${2:?Native output}")
phase=${3:?objects or linked}
[[ $phase == objects || $phase == linked ]]
for name in uke-speaker-display.h uke-speaker-display-control.h; do
 cmp "$kernel/native-profile/src/audio/$name" "$kernel/sound/soc/qcom/$name"
done
card=$out/sound/soc/qcom/uke-audio-card.o
llvm-readelf -h "$card" | grep -F AArch64
llvm-nm "$card" > "$out/speaker-display-symbols.txt"
for symbol in uke_display_get uke_display_put;do grep -Eq " [Tt] $symbol$" "$out/speaker-display-symbols.txt";done
llvm-nm -u "$card" | grep -E ' U q6apm_fs19xx_fault$'
strings "$card" | grep -Fx 'Speaker Display Rotation'
grep -Fx CONFIG_SND_SOC_WCD939X=m "$out/.config"
for symbol in wcd939x_get_hph_type wcd939x_hph_impedance_get hph_type_detect_controls impedance_detect_controls; do
 llvm-nm "$out/sound/soc/codecs/wcd939x.o" | awk -v name="$symbol" '$2~/^[tTrRdD]$/&&$3==name{found=1}END{exit !found}'
done
if [[ $phase == linked ]];then
 module=$out/sound/soc/qcom/uke-audio-card.ko
 [[ -s $module ]]
 strings "$module" | grep -Fx 'Speaker Display Rotation'
 for symbol in wcd939x_get_hph_type wcd939x_hph_impedance_get hph_type_detect_controls impedance_detect_controls; do
  llvm-nm "$out/sound/soc/codecs/snd-soc-wcd939x.ko" | awk -v name="$symbol" '$2~/^[tTrRdD]$/&&$3==name{found=1}END{exit !found}'
 done
fi
printf 'Actual speaker display card control and WCD939x production objects passed:%s; physical routing and audio acceptance separate.\n' "$phase"
