#!/usr/bin/bash
# Data-only tests of the exact admitted native95 source and reverse view.
set -Eeuo pipefail
[[ $# == 3 ]]
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
actual=$(realpath "$1");profile=$(realpath "$2");old_abi=$(realpath "$3")
contract=$profile/manifests/charge-observe-v2-20261111.json
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
kernel=$work/kernel
mkdir -p "$kernel/native-generated"
while IFS= read -r path;do install -Dm644 "$actual/$path" "$kernel/$path";done < <(jq -r '.source_units[].path' "$contract")
install -Dm644 "$old_abi" "$kernel/Documentation/ABI/testing/sysfs-driver-uke-charge-online"
ln -s "$profile" "$kernel/native-profile"
seal(){ (cd "$kernel";jq -r '.source_units[]|.after_sha256+"  "+.path' "$contract" | sha256sum -c --strict --quiet -); }
seal
helper=$owner/packaging/native/charge-observe-legacy-view733.sh
parent=$(bash "$helper" "$kernel")
[[ $parent == "$(bash "$helper" "$kernel")" ]]
header=$parent/drivers/power/supply/qcom_battmgr_uke_control.h
cp "$header" "$work/header"
printf '\nUnreviewed parent\n' >> "$header"
if bash "$helper" "$kernel" > "$work/tampered-header.log" 2>&1;then exit 1;fi
cp "$work/header" "$header"
abi=$parent/Documentation/ABI/testing/sysfs-driver-uke-charge-online
mv "$abi" "$work/abi"
if bash "$helper" "$kernel" > "$work/partial-view.log" 2>&1;then exit 1;fi
install -Dm644 "$work/abi" "$abi"
[[ $parent == "$(bash "$helper" "$kernel")" ]]
seal
printf 'Actual native95 source unchanged; exact full22 inverse,idempotence,tampered-header and partial-view refusals pass.\n'
