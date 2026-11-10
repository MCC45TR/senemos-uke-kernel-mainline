#!/usr/bin/bash
# One additive source/link/package layer over the qualified cumulative full17.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 || $# == 4 ]]
kernel=$(realpath "$1");out=$(realpath -m "$2");phase=$3
profile=$kernel/native-profile
contract=$profile/manifests/ssc-proximity-abi-20261110.json
work=$kernel/native-generated/ssc-proximity-abi733
driver=drivers/iio/common/uke-ssc/uke-ssc-iio.c
abi=Documentation/ABI/testing/sysfs-driver-uke-ssc-proximity-input
if [[ $phase == source ]];then
 [[ ! -e $work && ! -e $kernel/$abi ]]
 mkdir -p "$work"
 cp "$kernel/$driver" "$work/before.c"
 printf '%s  %s\n' "$(jq -er '.source_units[0].before_sha256' "$contract")" "$kernel/$driver" | sha256sum -c --strict --quiet -
 git -C "$kernel" apply --check --whitespace=error "$profile/src/sensors/0018-ssc-proximity-input-abi.patch"
 git -C "$kernel" apply --whitespace=error "$profile/src/sensors/0018-ssc-proximity-input-abi.patch"
 printf '%s  %s\n' "$(jq -er '.source_units[0].after_sha256' "$contract")" "$kernel/$driver" | sha256sum -c --strict --quiet -
 (cd "$kernel";sha256sum "$driver" "$abi") > "$work/applied.sha256"
 parent=$(bash "$profile/packaging/native/proximity-abi-legacy-view733.sh" "$kernel")
 cmp "$work/before.c" "$parent/$driver"
 [[ ! -e $parent/$abi ]]
 bash "$profile/tests/ssc-proximity-abi.sh" "$kernel"
 printf 'Cumulative proximity ABI source: complete full17 inverse,62 callbacks in four modes and versioned IIO classification; no physical acceptance.\n'
 exit 0
fi
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
release=$(jq -er .kernel_release "$profile/source-composition.json")
[[ $release == "$(cat "$out/include/config/kernel.release")" ]]
if [[ $phase == linked ]];then
 llvm-readelf -h "$out/drivers/iio/common/uke-ssc/uke-ssc.o" | grep -F AArch64
 llvm-nm "$out/drivers/iio/common/uke-ssc/uke-ssc.o" > "$work/linked.symbols"
 for symbol in ssc_proximity_input_abi_show dev_attr_ssc_proximity_input_abi ssc_proximity_open ssc_heading_read_raw ssc_read_raw_multi;do grep -Eq "[[:space:]][a-zA-Z][[:space:]]+$symbol\$" "$work/linked.symbols";done
 [[ $(modinfo -F vermagic "$out/drivers/iio/common/uke-ssc/uke-ssc.ko") == "$release "* ]]
 printf 'Cumulative proximity ABI linked: actual ARM64 capability,input and retained heading/quaternion module ABI pass; no physical acceptance.\n'
 exit 0
fi
[[ $phase == install && $# == 4 ]]
destination=$4/usr/share/senemos/uke/$release
cmp "$profile/source-composition.json" "$destination/source-composition.json"
jq -e '.ssc_proximity_input_abi==1 and .ssc_proximity_input_abi_native_admitted and .ssc_proximity_input_abi_legacy_raw_retained and (.ssc_proximity_input_abi_physical_accepted|not) and .speaker_gain_ceiling==223' "$destination/source-composition.json" >/dev/null
install -m644 "$work/applied.sha256" "$destination/ssc-proximity-input-abi-source.sha256"
cmp "$work/applied.sha256" "$destination/ssc-proximity-input-abi-source.sha256"
printf 'Cumulative proximity ABI package: final driver/document seals in existing core; original raw/input/firmware ownership retained.\n'
