#!/usr/bin/bash
# Source-only full21 header for retained gates; actual output stays unchanged.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
profile=$kernel/native-profile
work=$kernel/native-generated/charge-demand733
parent=$work/full21-view
file=drivers/power/supply/qcom_battmgr_uke_control.h
contract=$profile/manifests/charge-demand-20261111.json
if [[ ! -e $parent ]];then
 mkdir -p "$parent/$(dirname "$file")" "$parent/Documentation/ABI/testing" "$parent/native-generated"
 cp "$kernel/$file" "$parent/$file"
 git -c init.defaultBranch=senemos -C "$parent" init -q
 git -C "$parent" apply -R --whitespace=error "$profile/$(jq -er .patch "$contract")" >&2
 cp "$kernel/drivers/power/supply/qcom_battmgr.c" "$parent/drivers/power/supply/"
 cp "$kernel/Documentation/ABI/testing/sysfs-driver-uke-charge-online" "$parent/Documentation/ABI/testing/"
 ln -s "$profile" "$parent/native-profile"
 for directory in charge-standard733 charge-online733 battery-event-health733;do
  ln -s "$kernel/native-generated/$directory" "$parent/native-generated/$directory"
 done
fi
printf '%s  %s\n' "$(jq -er '.source_units[0].before_sha256' "$contract")" "$parent/$file" | sha256sum -c --strict --quiet -
printf '%s  %s\n' "$(jq -er .unchanged_driver_sha256 "$contract")" "$parent/drivers/power/supply/qcom_battmgr.c" | sha256sum -c --strict --quiet -
printf '%s\n' "$parent"
