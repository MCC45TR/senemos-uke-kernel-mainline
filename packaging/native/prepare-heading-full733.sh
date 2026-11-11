#!/usr/bin/bash
# Cumulative source/link/package phases. Physical heading remains separate.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 || $# == 4 ]]
kernel=$(realpath "$1")
out=$(realpath -m "$2")
phase=$3
profile=$kernel/native-profile
contract=$profile/manifests/ssc-heading-20261110.json
work=$kernel/native-generated/ssc-heading733
file=drivers/iio/common/uke-ssc/uke-ssc-iio.c
if [[ $phase == source ]];then
 [[ ! -e $work ]]
 mkdir -p "$work"
 cp "$kernel/$file" "$work/before.c"
 printf '%s  %s\n' "$(jq -er '.source_units[0].before_sha256' "$contract")" "$kernel/$file" | sha256sum -c --strict --quiet -
 git -C "$kernel" apply --check --whitespace=error "$profile/src/sensors/0017-ssc-magnetic-heading.patch"
 git -C "$kernel" apply --whitespace=error "$profile/src/sensors/0017-ssc-magnetic-heading.patch"
 printf '%s  %s\n' "$(jq -er '.source_units[0].after_sha256' "$contract")" "$kernel/$file" | sha256sum -c --strict --quiet -
 for name in uke-ssc-heading.h uke-ssc-heading-input.h;do install -m644 "$profile/src/sensors/$name" "$kernel/drivers/iio/common/uke-ssc/$name";done
 (cd "$kernel";sha256sum "$file" drivers/iio/common/uke-ssc/uke-ssc-heading{,-input}.h) > "$work/applied.sha256"
 parent=$(bash "$profile/packaging/native/heading-legacy-view733.sh" "$kernel")
 cmp "$work/before.c" "$parent/$file"
 bash "$profile/tests/ssc-heading-math.sh"
 bash "$profile/tests/ssc-heading-callbacks.sh" "$kernel"
 printf 'Cumulative heading source: exact full16 inverse,integer projection,shared demand and all callback regressions pass; no physical acceptance.\n'
 exit 0
fi
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
release=$(jq -er .kernel_release "$profile/source-composition.json")
[[ $release == "$(cat "$out/include/config/kernel.release")" ]]
if [[ $phase == linked ]];then
 object=$out/drivers/iio/common/uke-ssc/uke-ssc.o
 module=$out/drivers/iio/common/uke-ssc/uke-ssc.ko
 llvm-readelf -h "$object" | grep -F AArch64
 llvm-nm "$object" > "$work/linked.symbols"
 for symbol in ssc_heading_read_raw ssc_heading_buffer_enable ssc_heading_buffer_disable ssc_read_raw_multi;do grep -Eq "[[:space:]][tT][[:space:]]+$symbol\$" "$work/linked.symbols";done
 for name in uke-ssc-magnetic-heading uke-ssc-rotv uke-ssc-game-rv uke-ssc-geomag-rv;do llvm-strings "$module" | grep -Fx "$name";done
 [[ $(modinfo -F vermagic "$module") == "$release "* ]]
 if grep -Eq '[[:space:]]U[[:space:]]+(atan2|sqrt|sin|cos|__.*(df|sf)3)$' "$work/linked.symbols";then exit 1;fi
 printf 'Cumulative heading linked: actual new ARM64 SSC module,standard heading and retained quaternion readers/no FPU pass; no physical acceptance.\n'
 exit 0
fi
[[ $phase == install && $# == 4 ]]
destination=$4/usr/share/senemos/uke/$release
cmp "$profile/source-composition.json" "$destination/source-composition.json"
jq -e '.ssc_heading_native_admitted and .ssc_heading_firmware_datatype=="rotv" and .ssc_heading_scan_bytes==16 and .ssc_heading_timestamp_offset==8 and .ssc_heading_raw_abi_unchanged and .ssc_heading_shared_last_owner_stop and (.ssc_heading_physical_accepted|not) and .speaker_gain_ceiling==223' "$destination/source-composition.json" >/dev/null
install -m644 "$work/applied.sha256" "$destination/ssc-heading-source.sha256"
cmp "$work/applied.sha256" "$destination/ssc-heading-source.sha256"
printf 'Cumulative heading package: final driver/header seals and native source metadata in existing core; no new runtime family.\n'
