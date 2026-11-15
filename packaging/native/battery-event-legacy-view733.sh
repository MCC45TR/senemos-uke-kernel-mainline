#!/usr/bin/bash
# Data-only full19 source projection for retained sealed-source checks.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
profile=$kernel/native-profile
work=$kernel/native-generated/battery-event-health733
parent=$work/full19-view
file=drivers/power/supply/qcom_battmgr.c
contract=$profile/manifests/battery-event-health-20261111.json
if [[ ! -e $parent ]];then
 mkdir -p "$parent/$(dirname "$file")" "$parent/Documentation/ABI/testing" "$parent/native-generated"
 cp "$kernel/$file" "$parent/$file"
 while IFS= read -r patch;do git -C "$parent" apply -R --whitespace=error "$profile/$patch" >&2;done < <(jq -r '.patches|reverse[]' "$contract")
 cp "$kernel/drivers/power/supply/qcom_battmgr_uke_control.h" "$parent/drivers/power/supply/"
 cp "$kernel/Documentation/ABI/testing/sysfs-driver-uke-charge-online" "$parent/Documentation/ABI/testing/"
 ln -s "$profile" "$parent/native-profile"
 ln -s "$kernel/native-generated/charge-online733" "$parent/native-generated/charge-online733"
fi
printf '%s  %s\n' "$(jq -er '.source_units[0].before_sha256' "$contract")" "$parent/$file" | sha256sum -c --strict --quiet -
(cd "$parent";sha256sum -c --strict --quiet "$kernel/native-generated/charge-online733/applied.sha256")
printf '%s\n' "$parent"
