#!/usr/bin/bash
# Deliver admitted demand reads; retain the legacy guard and physical gates.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 || $# == 4 ]]
kernel=$(realpath "$1");out=$(realpath -m "$2");phase=$3
profile=$kernel/native-profile
contract=$profile/manifests/charge-demand-20261111.json
work=$kernel/native-generated/charge-demand733
file=drivers/power/supply/qcom_battmgr_uke_control.h
cfile=drivers/power/supply/qcom_battmgr.c
if [[ $phase == source ]];then
 [[ ! -e $work ]]
 mkdir -p "$work/inverse/$(dirname "$file")"
 printf '%s  %s\n' "$(jq -er '.source_units[0].before_sha256' "$contract")" "$kernel/$file" | sha256sum -c --strict --quiet -
 cp "$kernel/$file" "$work/before.h"
 patch=$profile/$(jq -er .patch "$contract")
 git -C "$kernel" apply --check --whitespace=error "$patch"
 git -C "$kernel" apply --whitespace=error "$patch"
 printf '%s  %s\n' "$(jq -er '.source_units[0].after_sha256' "$contract")" "$kernel/$file" | sha256sum -c --strict --quiet -
 cp "$kernel/$file" "$work/inverse/$file"
 git -c init.defaultBranch=senemos -C "$work/inverse" init -q
 git -C "$work/inverse" apply -R --whitespace=error "$patch"
 cmp "$work/before.h" "$work/inverse/$file"
 printf '%s  %s\n' "$(jq -er .unchanged_driver_sha256 "$contract")" "$kernel/$cfile" | sha256sum -c --strict --quiet -
 (cd "$kernel";sha256sum "$file" "$cfile") > "$work/applied.sha256"
 printf 'Cumulative demand protection source: complete full21 header inverse and admitted native93 reads; no new writer or physical cutoff acceptance.\n'
 exit 0
fi
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
release=$(jq -er .kernel_release "$profile/source-composition.json")
[[ $release == "$(cat "$out/include/config/kernel.release")" ]]
if [[ $phase == linked ]];then
 llvm-readelf -h "$out/drivers/power/supply/qcom_battmgr.o" | grep -F AArch64
 llvm-nm "$out/drivers/power/supply/qcom_battmgr.o" | grep -E '[[:space:]][a-zA-Z][[:space:]]uke_charge_protection_state_show$'
 [[ $(modinfo -F vermagic "$out/drivers/power/supply/qcom_battmgr.ko") == "$release "* ]]
 printf 'Cumulative demand protection linked: actual ARM64 battery object/module and final header/C seals; physical enforcement remains unaccepted.\n'
 exit 0
fi
[[ $phase == install && $# == 4 ]]
destination=$4/usr/share/senemos/uke/$release
cmp "$profile/source-composition.json" "$destination/source-composition.json"
jq -e '.charge_demand_snapshot_v1 and .charge_demand_native_build==11304264 and .charge_demand_native_admitted and (.charge_demand_physical_protection_accepted|not) and .speaker_gain_ceiling==223' "$destination/source-composition.json" >/dev/null
install -m644 "$work/applied.sha256" "$destination/charge-demand-source.sha256"
cmp "$work/applied.sha256" "$destination/charge-demand-source.sha256"
printf 'Cumulative demand protection package: final battery header/C seal in existing core; no new runtime,service,desktop fork or automatic SET.\n'
