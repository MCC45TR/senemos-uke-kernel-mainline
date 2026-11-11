#!/usr/bin/bash
# Additive source, actual linked-output and existing-core package gates.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 || $# == 4 ]]
kernel=$(realpath "$1")
out=$(realpath -m "$2")
phase=$3
profile=$kernel/native-profile
work=$kernel/native-generated/ssc-quaternion733
if [[ $phase == source ]];then
 bash "$profile/src/sensors/apply-quaternion733.sh" "$kernel"
 bash "$profile/tests/ssc-quaternion.sh" "$kernel"
 dt-doc-validate "$kernel/Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml"
 bash "$profile/tests/quaternion-delivery-source.sh" "$kernel"
 printf 'Cumulative quaternion source: actual atomic XYZW callbacks, legacy64 scans, four inverses and binding pass; no physical acceptance.\n'
 exit 0
fi
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
release=$(jq -er .kernel_release "$profile/source-composition.json")
[[ $release == "$(cat "$out/include/config/kernel.release")" ]]
if [[ $phase == linked ]];then
 object=$out/drivers/iio/common/uke-ssc/uke-ssc.o
 module=$out/drivers/iio/common/uke-ssc/uke-ssc.ko
 llvm-readelf -h "$object" | grep -F AArch64
 llvm-readelf -h "$out/arch/arm64/kernel/uke-abl.o" | grep -F AArch64
 for name in uke-ssc-rotv uke-ssc-game-rv uke-ssc-geomag-rv;do
  llvm-strings "$object" | grep -Fx "$name"
  llvm-strings "$module" | grep -Fx "$name"
 done
 llvm-nm "$object" > "$work/production.symbols"
 grep -Eq '[[:space:]][tT][[:space:]]+ssc_read_raw_multi$' "$work/production.symbols"
 for symbol in input_register_device input_event;do grep -Eq "[[:space:]]U[[:space:]]+$symbol\$" "$work/production.symbols";done
 [[ $(modinfo -F vermagic "$module") == "$release "* ]]
 printf 'Cumulative quaternion linked: actual SSC/early-DT AArch64 objects, three firmware kinds, multi-value reader and production module ABI pass.\n'
 exit 0
fi
[[ $phase == install && $# == 4 ]]
destination=$4/usr/share/senemos/uke/$release
cmp "$profile/source-composition.json" "$destination/source-composition.json"
jq -e '.ssc_quaternion_native_admitted and .ssc_quaternion_native_build==11299414 and
 .ssc_quaternion_datatypes==["rotv","game_rv","geomag_rv"] and
 .ssc_quaternion_components==4 and .ssc_quaternion_atomic_direct and
 (.ssc_quaternion_physical_accepted|not) and .speaker_gain_ceiling==223' "$destination/source-composition.json" >/dev/null
install -m644 "$work/applied.sha256" "$destination/ssc-quaternion-source.sha256"
cmp "$work/applied.sha256" "$destination/ssc-quaternion-source.sha256"
printf 'Cumulative quaternion package: final source hashes and qualified source metadata in the existing core RPM; no new runtime family.\n'
