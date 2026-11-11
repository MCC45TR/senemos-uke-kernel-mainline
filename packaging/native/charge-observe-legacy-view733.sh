#!/usr/bin/bash
# Exact full22 source view for historical gates; final output stays native95.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1");profile=$kernel/native-profile
work=$kernel/native-generated/charge-observe-full733
parent=$work/full22-view
contract=$profile/manifests/charge-observe-v2-20261111.json
if [[ ! -e $parent ]];then
 mkdir -p "$parent/drivers/power/supply" "$parent/Documentation/ABI/testing" "$parent/native-generated"
 while IFS= read -r path;do install -Dm644 "$kernel/$path" "$parent/$path";done < <(jq -r '.source_units[].path' "$contract")
 git -c init.defaultBranch=senemos -C "$parent" init -q
 git -C "$parent" apply -R --whitespace=error "$profile/$(jq -er .patch "$contract")" >&2
 cp "$kernel/Documentation/ABI/testing/sysfs-driver-uke-charge-online" "$parent/Documentation/ABI/testing/"
 ln -s "$profile" "$parent/native-profile"
 for directory in charge-demand733 charge-standard733 charge-online733 battery-event-health733;do
  ln -s "$kernel/native-generated/$directory" "$parent/native-generated/$directory"
 done
fi
while IFS=$'\t' read -r path before;do
 if [[ $before == absent ]];then [[ ! -e $parent/$path ]];else
  printf '%s  %s\n' "$before" "$parent/$path" | sha256sum -c --strict --quiet -
 fi
done < <(jq -r '.source_units[]|[.path,.before_sha256]|@tsv' "$contract")
printf '%s\n' "$parent"
