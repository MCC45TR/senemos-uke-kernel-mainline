#!/usr/bin/bash
# Source/link/package qualification of the two admitted metadata/event changes.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 || $# == 4 ]]
kernel=$(realpath "$1");out=$(realpath -m "$2");phase=$3
profile=$kernel/native-profile
contract=$profile/manifests/battery-event-health-20261111.json
work=$kernel/native-generated/battery-event-health733
file=drivers/power/supply/qcom_battmgr.c
if [[ $phase == source ]];then
 [[ ! -e $work ]]
 mkdir -p "$work/inverse/$(dirname "$file")"
 printf '%s  %s\n' "$(jq -er '.source_units[0].before_sha256' "$contract")" "$kernel/$file" | sha256sum -c --strict --quiet -
 cp "$kernel/$file" "$work/before.c"
 while IFS= read -r patch;do git -C "$kernel" apply --check --whitespace=error "$profile/$patch";git -C "$kernel" apply --whitespace=error "$profile/$patch";done < <(jq -r '.patches[]' "$contract")
 printf '%s  %s\n' "$(jq -er '.source_units[0].after_sha256' "$contract")" "$kernel/$file" | sha256sum -c --strict --quiet -
 cp "$kernel/$file" "$work/inverse/$file"
 while IFS= read -r patch;do git -C "$work/inverse" apply -R --whitespace=error "$profile/$patch";done < <(jq -r '.patches|reverse[]' "$contract")
 cmp "$work/before.c" "$work/inverse/$file"
 (cd "$kernel";sha256sum "$file") > "$work/applied.sha256"
 printf 'Cumulative battery event/health source: exact full19 inverse and admitted status/counter source; no electrical acceptance.\n'
 exit 0
fi
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
release=$(jq -er .kernel_release "$profile/source-composition.json")
[[ $release == "$(cat "$out/include/config/kernel.release")" ]]
if [[ $phase == linked ]];then
 llvm-readelf -h "$out/drivers/power/supply/qcom_battmgr.o" | grep -F AArch64
 [[ $(modinfo -F vermagic "$out/drivers/power/supply/qcom_battmgr.ko") == "$release "* ]]
 printf 'Cumulative battery event/health linked: actual ARM64 battery object/module and final source seal; fixed-cap controls retained,physical effect unaccepted.\n'
 exit 0
fi
[[ $phase == install && $# == 4 ]]
destination=$4/usr/share/senemos/uke/$release
cmp "$profile/source-composition.json" "$destination/source-composition.json"
jq -e '.battery_status_event_v1 and .reported_zero_cycle_count and .battery_event_health_native_build==11302971 and .speaker_gain_ceiling==223 and (.battery_event_health_physical_accepted|not)' "$destination/source-composition.json" >/dev/null
install -m644 "$work/applied.sha256" "$destination/battery-event-health-source.sha256"
cmp "$work/applied.sha256" "$destination/battery-event-health-source.sha256"
printf 'Cumulative battery event/health package: source seal in existing core,all prior hardware fields retained; no new runtime or charging policy.\n'
