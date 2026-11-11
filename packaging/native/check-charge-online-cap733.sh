#!/usr/bin/bash
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 2 ]]
kernel=$(realpath "$1");out=$(realpath -m "$2")
profile=$kernel/native-profile
contract=$profile/manifests/charge-online-cap-20261111.json
work=$kernel/native-generated/charge-online733
[[ ! -e $work ]]
mkdir -p "$work"
abi=$(jq -er .abi_document.path "$contract")
[[ ! -e $kernel/$abi ]]
while IFS=$'\t' read -r path digest;do
 printf '%s  %s\n' "$digest" "$kernel/$path" | sha256sum -c --strict --quiet -
 install -Dm644 "$kernel/$path" "$work/before/$path"
done < <(jq -r '.source_units[]|[.path,.before_sha256]|@tsv' "$contract")
git -C "$kernel" apply --check --whitespace=error "$profile/src/power/0002-uke-existing-cap-online-reapply.patch"
git -C "$kernel" apply --whitespace=error "$profile/src/power/0002-uke-existing-cap-online-reapply.patch"
while IFS=$'\t' read -r path digest;do
 printf '%s  %s\n' "$digest" "$kernel/$path" | sha256sum -c --strict --quiet -
 install -Dm644 "$kernel/$path" "$work/inverse/$path"
done < <(jq -r '.source_units[]|[.path,.after_sha256]|@tsv' "$contract")
printf '%s  %s\n' "$(jq -er .abi_document.sha256 "$contract")" "$kernel/$abi" | sha256sum -c --strict --quiet -
install -Dm644 "$kernel/$abi" "$work/inverse/$abi"
git -C "$work/inverse" init -q
git -C "$work/inverse" apply -R --whitespace=error "$profile/src/power/0002-uke-existing-cap-online-reapply.patch"
while IFS= read -r path;do cmp "$work/before/$path" "$work/inverse/$path";done < <(jq -r '.source_units[].path' "$contract")
[[ ! -e $work/inverse/$abi ]]
bash "$profile/tests/charge-online-cap.sh" "$kernel"
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-18-unstable KCFLAGS=-Werror W=1 -j4 drivers/power/supply/qcom_battmgr.o
llvm-readelf -h "$out/drivers/power/supply/qcom_battmgr.o" | grep -F AArch64
llvm-nm "$out/drivers/power/supply/qcom_battmgr.o" > "$work/symbols"
for symbol in uke_charge_apply_existing_cap_online_store dev_attr_uke_charge_apply_existing_cap_online;do
 grep -Eq "[[:space:]][a-zA-Z][[:space:]]+$symbol\$" "$work/symbols"
done
(cd "$kernel";jq -r '.source_units[].path,.abi_document.path' "$contract" | xargs sha256sum) > "$work/applied.sha256"
printf 'Actual online cap native: complete full18 inverse,four callback modes,eight regression refusals and fresh ARM64 battery object; no actuator acceptance.\n'
