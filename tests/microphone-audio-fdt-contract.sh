#!/usr/bin/env bash
# Resolve the combined graph in memory. Optional active DT remains read-only.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel tree}
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
bash "$root/tests/speaker-audio-fdt-contract.sh" "$kernel" microphones "$work/result.dtb"
check_native_output() {
 local routing output
 routing=$(fdtget -t s "$1" /sound-uke audio-routing)
 output=${routing##* }
 test "${routing% *}" = 'AMIC1 Analog Mic1 AMIC1 MIC BIAS1 TX SWR_INPUT0' || return 1
 # Resolve the board endpoint against this build's actual codec widgets.
 # The OEM aggregate WCD_TX_OUTPUT does not exist in native WCD939x.
 grep -Fq "SND_SOC_DAPM_OUTPUT(\"$output\")" "$kernel/sound/soc/codecs/wcd939x.c"
}
check_graph() {
 local f=$1 codec=/audio-codec reset l7 bob tx rx provider
 l7=$(fdtget -t s "$f" /__symbols__ pmxr2230_l7)
 bob=$(fdtget -t s "$f" /__symbols__ pmxr2230_bob)
 for spec in "$l7:1800000" "$bob:3296000"; do
  provider=${spec%:*}
  for limit in min max; do
   test "$(fdtget -t u "$f" "$provider" "regulator-$limit-microvolt")" = "${spec##*:}"
  done
 done
 l7=$(fdtget -t x "$f" "$l7" phandle)
 bob=$(fdtget -t x "$f" "$bob" phandle)
 for supply in rxtx io buck px; do
  test "$(fdtget -t x "$f" "$codec" "vdd-$supply-supply")" = "$l7"
 done
 test "$(fdtget -t x "$f" "$codec" vdd-mic-bias-supply)" = "$bob"
 for bias in 1 2 3 4; do
  test "$(fdtget -t u "$f" "$codec" "qcom,micbias$bias-microvolt")" = 2750000
 done
 reset=$(fdtget -t s "$f" /__symbols__ uke_codec_reset)
 test "$(fdtget -t s "$f" "$reset" compatible)" = xiaomi,uke-wcd939x-codec-reset
 test "$(fdtget -t x "$f" "$codec" resets)" = "$(fdtget -t x "$f" "$reset" phandle) 0"
 if fdtget "$f" "$codec" reset-gpios >/dev/null 2>&1; then exit 1; fi
 tx=/soc/soundwire@6d30000
 rx=/soc/soundwire@6ad0000
 test "$(fdtget -t x "$f" "$tx" reg)" = '6d30000 10000'
 test "$(fdtget -t x "$f" "$rx" reg)" = '6ad0000 10000'
 test "$(fdtget -t u "$f" "$tx" interrupts)" = '0 496 4 0 0 520 4 0'
 test "$(fdtget -t u "$f" "$rx" interrupts)" = '0 155 4 0'
 for pair in tx:6ae0000 rx:6ac0000; do
  provider=$rx
  [[ ${pair%:*} != tx ]] || provider=$tx
  test "$(fdtget -t x "$f" "$provider" clocks)" = "$(fdtget -t x "$f" "/soc/codec@${pair##*:}" phandle)"
 done
 test "$(fdtget -t u "$f" "$tx/codec@0,3" reg)" = '0 3'
 test "$(fdtget -t u "$f" "$rx/codec@0,4" reg)" = '0 4'
 test "$(fdtget -t s "$f" "$tx/codec@0,3" compatible)" = sdw20217010e00
 test "$(fdtget -t s "$f" "$rx/codec@0,4" compatible)" = sdw20217010e00
 test "$(fdtget -t u "$f" "$tx/codec@0,3" qcom,tx-port-mapping)" = '2 2 3 4'
 test "$(fdtget -t x "$f" "$codec" qcom,tx-device)" = "$(fdtget -t x "$f" "$tx/codec@0,3" phandle)"
 test "$(fdtget -t x "$f" "$codec" qcom,rx-device)" = "$(fdtget -t x "$f" "$rx/codec@0,4" phandle)"
 test "$(fdtget -t u "$f" /soc/pinctrl@6e80000/tx-swr-active-state/data-pins drive-strength)" = 4
 test "$(fdtget -t s "$f" /soc/pinctrl@6e80000/tx-swr-active-state/data-pins pins)" = 'gpio1 gpio2 gpio14'
 test "$(fdtget -t u "$f" /soc/pinctrl@6e80000/rx-swr-active-state/data-pins drive-strength)" = 2
 test "$(fdtget -t s "$f" /soc/pinctrl@6e80000/rx-swr-active-state/data-pins pins)" = 'gpio4 gpio5'
 test "$(fdtget -t x "$f" /sound-uke/microphone-dai-link/codec sound-dai)" = "$(fdtget -t x "$f" "$codec" phandle) 1 $(fdtget -t x "$f" "$tx" phandle) 1 $(fdtget -t x "$f" /soc/codec@6ae0000 phandle) 0"
 local be=/soc/remoteproc-adsp@03000000/glink-edge/qcom,gpr/service@1/bedais
 test "$(fdtget -t x "$f" /sound-uke/microphone-dai-link/cpu sound-dai)" = "$(fdtget -t x "$f" "$be" phandle) 78"
 check_native_output "$f"
}
check_graph "$work/result.dtb"
cp "$work/result.dtb" "$work/oem-only-output.dtb"
fdtput -t s "$work/oem-only-output.dtb" /sound-uke audio-routing \
 AMIC1 'Analog Mic1' AMIC1 'MIC BIAS1' 'TX SWR_INPUT0' WCD_TX_OUTPUT
if check_native_output "$work/oem-only-output.dtb"; then
 printf 'An output absent from the native codec was accepted\n' >&2
 exit 1
fi
printf 'Native codec output resolved; the historical OEM-only output is rejected.\n'
if [[ -n ${2:-} ]]; then
 printf '/dts-v1/;\n/plugin/;\n#include "%s/src/audio/sm7675-uke-audio-services.dtsi"\n#include "%s/src/audio/sm7675-uke-speaker-audio.dtsi"\n#include "%s/src/audio/sm7675-uke-microphone-audio.dtsi"\n' "$root" "$root" "$root" > "$work/overlay.dts"
 cpp -nostdinc -undef -x assembler-with-cpp -I "$kernel/include" "$work/overlay.dts" > "$work/overlay.pp.dts"
 dtc -q -@ -I dts -O dtb -o "$work/overlay.dtbo" "$work/overlay.pp.dts"
 fdtoverlay -i "$2" -o "$work/active-adapted.dtb" "$work/overlay.dtbo"
 check_graph "$work/active-adapted.dtb"
 printf 'Active-DT copy: supply phandles and fixed voltage bounds preserved; memory only.\n'
fi
printf 'Microphone FDT: supplies, coordinated reset, both slaves, pins, IRQs and mono backend passed; no device activation.\n'
