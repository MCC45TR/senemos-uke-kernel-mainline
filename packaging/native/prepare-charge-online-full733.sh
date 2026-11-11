#!/usr/bin/bash
# Additive source/link/package checks; no physical actuator qualification.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 || $# == 4 ]]
kernel=$(realpath "$1");out=$(realpath -m "$2");phase=$3
profile=$kernel/native-profile
contract=$profile/manifests/charge-online-cap-20261111.json
work=$kernel/native-generated/charge-online733
patch=$profile/src/power/0002-uke-existing-cap-online-reapply.patch
abi=$(jq -er .abi_document.path "$contract")
if [[ $phase == source ]];then
 [[ ! -e $work && ! -e $kernel/$abi ]]
 mkdir -p "$work"
 while IFS=$'\t' read -r path digest;do
  printf '%s  %s\n' "$digest" "$kernel/$path" | sha256sum -c --strict --quiet -
  install -Dm644 "$kernel/$path" "$work/before/$path"
 done < <(jq -r '.source_units[]|[.path,.before_sha256]|@tsv' "$contract")
 git -C "$kernel" apply --check --whitespace=error "$patch"
 git -C "$kernel" apply --whitespace=error "$patch"
 while IFS=$'\t' read -r path digest;do
  printf '%s  %s\n' "$digest" "$kernel/$path" | sha256sum -c --strict --quiet -
  install -Dm644 "$kernel/$path" "$work/inverse/$path"
 done < <(jq -r '.source_units[]|[.path,.after_sha256]|@tsv' "$contract")
 printf '%s  %s\n' "$(jq -er .abi_document.sha256 "$contract")" "$kernel/$abi" | sha256sum -c --strict --quiet -
 install -Dm644 "$kernel/$abi" "$work/inverse/$abi"
 git -C "$work/inverse" init -q
 git -C "$work/inverse" apply -R --whitespace=error "$patch"
 while IFS= read -r path;do cmp "$work/before/$path" "$work/inverse/$path";done < <(jq -r '.source_units[].path' "$contract")
 [[ ! -e $work/inverse/$abi ]]
 (cd "$kernel";jq -r '.source_units[].path,.abi_document.path' "$contract" | xargs sha256sum) > "$work/applied.sha256"
 bash "$profile/tests/charge-online-cap.sh" "$kernel"
 printf 'Cumulative online cap source: full18 inverse,fixed70/80 callbacks and no-replay regressions pass; no physical cutoff acceptance.\n'
 exit 0
fi
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
release=$(jq -er .kernel_release "$profile/source-composition.json")
[[ $release == "$(cat "$out/include/config/kernel.release")" ]]
if [[ $phase == linked ]];then
 object=$out/drivers/power/supply/qcom_battmgr.o
 module=$out/drivers/power/supply/qcom_battmgr.ko
 llvm-readelf -h "$object" | grep -F AArch64
 llvm-nm "$object" > "$work/linked.symbols"
 for symbol in uke_charge_apply_existing_cap_online_store dev_attr_uke_charge_apply_existing_cap_online uke_charge_apply_existing_cap_store;do
  grep -Eq "[[:space:]][a-zA-Z][[:space:]]+$symbol\$" "$work/linked.symbols"
 done
 [[ $(modinfo -F vermagic "$module") == "$release "* ]]
 llvm-strings "$module" | grep -F 'existing 70/80 online request: SOC='
 printf 'Cumulative online cap linked: actual ARM64 battery module,new fixed request and retained offline ABI pass; actuator effect unverified.\n'
 exit 0
fi
[[ $phase == install && $# == 4 ]]
destination=$4/usr/share/senemos/uke/$release
cmp "$profile/source-composition.json" "$destination/source-composition.json"
jq -e '.charge_existing_band_online_v1 and .charge_existing_band_online_native_admitted and .charge_existing_band_online_no_replay and (.charge_existing_band_online_physical_accepted|not) and .speaker_gain_ceiling==223' "$destination/source-composition.json" >/dev/null
install -m644 "$work/applied.sha256" "$destination/charge-existing-band-online-source.sha256"
cmp "$work/applied.sha256" "$destination/charge-existing-band-online-source.sha256"
printf 'Cumulative online cap package: exact power-source/ABI seals in existing core; no runtime package,service or policy added.\n'
