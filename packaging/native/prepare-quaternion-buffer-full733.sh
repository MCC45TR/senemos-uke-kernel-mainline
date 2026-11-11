#!/usr/bin/bash
# Keep source, actual linked output and existing-core admission distinct.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 || $# == 4 ]]
kernel=$(realpath "$1")
out=$(realpath -m "$2")
phase=$3
profile=$kernel/native-profile
contract=$profile/manifests/ssc-quaternion-buffer-20261110.json
work=$kernel/native-generated/ssc-quaternion-buffer733
file=drivers/iio/common/uke-ssc/uke-ssc-iio.c
if [[ $phase == source ]];then
 [[ ! -e $work ]]
 mkdir -p "$work"
 cp "$kernel/$file" "$work/before.c"
 printf '%s  %s\n' "$(jq -er '.source_units[0].before_sha256' "$contract")" "$kernel/$file" | sha256sum -c --strict --quiet -
 git -C "$kernel" apply --check --whitespace=error "$profile/src/sensors/0016-ssc-quaternion-scan-alignment.patch"
 git -C "$kernel" apply --whitespace=error "$profile/src/sensors/0016-ssc-quaternion-scan-alignment.patch"
 printf '%s  %s\n' "$(jq -er '.source_units[0].after_sha256' "$contract")" "$kernel/$file" | sha256sum -c --strict --quiet -
 (cd "$kernel";sha256sum "$file") > "$work/applied.sha256"
 parent=$(bash "$profile/packaging/native/quaternion-buffer-legacy-view733.sh" "$kernel")
 cmp "$work/before.c" "$parent/$file"
 bash "$profile/tests/ssc-quaternion-buffer.sh" "$kernel"
 printf 'Cumulative quaternion buffer source: exact full15 inverse, real IIO64-byte sizing, zero padding and8 regressions pass; no device acceptance.\n'
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
 grep -Eq '[[:space:]][tT][[:space:]]+ssc_read_raw_multi$' "$work/linked.symbols"
 for name in uke-ssc-rotv uke-ssc-game-rv uke-ssc-geomag-rv;do llvm-strings "$module" | grep -Fx "$name";done
 [[ $(modinfo -F vermagic "$module") == "$release "* ]]
 printf 'Cumulative quaternion buffer linked: actual new ARM64 SSC object/module and atomic reader retained; physical streams unaccepted.\n'
 exit 0
fi
[[ $phase == install && $# == 4 ]]
destination=$4/usr/share/senemos/uke/$release
cmp "$profile/source-composition.json" "$destination/source-composition.json"
jq -e '.ssc_quaternion_buffer_native_admitted and .ssc_quaternion_buffer_native_build==11299883 and .ssc_quaternion_scan_bytes==64 and .ssc_quaternion_timestamp_offset==32 and (.ssc_quaternion_buffer_physical_accepted|not) and .speaker_gain_ceiling==223' "$destination/source-composition.json" >/dev/null
install -m644 "$work/applied.sha256" "$destination/ssc-quaternion-buffer-source.sha256"
cmp "$work/applied.sha256" "$destination/ssc-quaternion-buffer-source.sha256"
printf 'Cumulative quaternion buffer package: final driver seal and native64-byte metadata in existing core; no new runtime family.\n'
