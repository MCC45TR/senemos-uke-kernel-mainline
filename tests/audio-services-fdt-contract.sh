#!/usr/bin/env bash
# Synthetic host graph; never applies an overlay to a running device.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/base.dts" <<'DTS'
/dts-v1/;
/ {
 compatible = "xiaomi,uke";
 apps_smmu: iommu { #iommu-cells = <2>; };
 soc {
  remoteproc-adsp@03000000 {
   glink-edge {
    qcom,gpr {
     compatible = "qcom,gpr";
     spf_core { reg = <3>; compatible = "qcom,spf_core"; };
     q6prm { reg = <7>; compatible = "qcom,audio_prm"; };
    };
   };
  };
  slim@6C40000 { status = "disabled"; };
  i2c@88c000 { status = "disabled"; };
 };
};
DTS
printf '/dts-v1/;\n/plugin/;\n#include "%s/src/audio/sm7675-uke-audio-services.dtsi"\n' "$root" > "$work/overlay.dts"
cpp -nostdinc -undef -x assembler-with-cpp "$work/overlay.dts" > "$work/overlay.pp.dts"
dtc -q -@ -I dts -O dtb -o "$work/base.dtb" "$work/base.dts"
dtc -q -@ -I dts -O dtb -o "$work/overlay.dtbo" "$work/overlay.pp.dts"
fdtoverlay -i "$work/base.dtb" -o "$work/result.dtb" "$work/overlay.dtbo"
gpr=/soc/remoteproc-adsp@03000000/glink-edge/qcom,gpr
test "$(fdtget -t s "$work/result.dtb" "$gpr/service@1" compatible)" = qcom,q6apm
test "$(fdtget -t i "$work/result.dtb" "$gpr/service@1" reg)" = 1
test "$(fdtget -t s "$work/result.dtb" "$gpr/service@2" compatible)" = qcom,q6prm
test "$(fdtget -t i "$work/result.dtb" "$gpr/service@2" reg)" = 2
for child in dais bedais; do
 test "$(fdtget -t s "$work/result.dtb" "$gpr/service@1/$child" status)" = disabled
done
test "$(fdtget -t i "$work/result.dtb" "$gpr/spf_core" reg)" = 3
test "$(fdtget -t i "$work/result.dtb" "$gpr/q6prm" reg)" = 7
for node in slim@6C40000 i2c@88c000; do
 test "$(fdtget -t s "$work/result.dtb" "/soc/$node" status)" = disabled
done
profile=$root/audio-profile
[[ -f $profile ]] || profile=$root/packaging/native/audio-profile
test "$(cat "$profile")" = disabled
printf 'Audio service FDT: native 1/2, OEM 3/7 retained, both DAIs and physical buses disabled.\n'
