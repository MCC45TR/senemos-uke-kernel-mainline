#!/usr/bin/bash
# COPR cumulative source, linked-module and existing-core metadata checks.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 || $# == 4 ]]
kernel=$(realpath "$1")
out=$(realpath -m "$2")
phase=$3
profile=$kernel/native-profile
work=$kernel/native-generated/ssc-gravity733
if [[ $phase == source ]];then
 bash "$profile/src/sensors/apply-gravity733.sh" "$kernel"
 bash "$profile/tests/ssc-gravity.sh" "$kernel"
 dt-doc-validate "$kernel/Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml"
 bash "$profile/tests/gravity-delivery-source.sh" "$kernel" "$out"
 printf 'Cumulative gravity source: actual six-value callbacks, standard linear axes, four inverses and binding pass; no physical acceptance.\n'
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
 llvm-strings "$object" | grep -F 'uke-ssc-gravity'
 llvm-nm "$object" > "$work/production.symbols"
 for symbol in input_register_device input_event;do
  grep -Eq "[[:space:]]U[[:space:]]+$symbol\$" "$work/production.symbols"
 done
 [[ $(modinfo -F vermagic "$module") == "$release "* ]]
 printf 'Cumulative gravity linked: actual SSC/early-DT AArch64 objects, retained proximity imports and production module ABI pass.\n'
 exit 0
fi
[[ $phase == install && $# == 4 ]]
destination=$4/usr/share/senemos/uke/$release
cmp "$profile/source-composition.json" "$destination/source-composition.json"
jq -e '.ssc_gravity_native_admitted and .ssc_gravity_native_build==11296588 and
 .ssc_gravity_channels==6 and .ssc_gravity_standard_linear_axes and
 (.ssc_gravity_physical_accepted|not) and .speaker_gain_ceiling==223' "$destination/source-composition.json" >/dev/null
install -m644 "$work/applied.sha256" "$destination/ssc-gravity-source.sha256"
cmp "$work/applied.sha256" "$destination/ssc-gravity-source.sha256"
printf 'Cumulative gravity package: source hashes and qualified six-channel metadata in the existing core RPM; no new runtime family.\n'
