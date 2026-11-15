#!/usr/bin/bash
# Apply admitted native95 without changing hardware writers or the legacy ABI.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 || $# == 4 ]]
kernel=$(realpath "$1");out=$(realpath -m "$2");phase=$3
profile=$kernel/native-profile
contract=$profile/manifests/charge-observe-v2-20261111.json
work=$kernel/native-generated/charge-observe-full733
if [[ $phase == source ]];then
 [[ ! -e $work ]]
 mkdir -p "$work/before" "$work/inverse"
 while IFS=$'\t' read -r path before after;do
  if [[ $before == absent ]];then
   [[ ! -e $kernel/$path ]]
  else
   printf '%s  %s\n' "$before" "$kernel/$path" | sha256sum -c --strict --quiet -
   install -Dm644 "$kernel/$path" "$work/before/$path"
  fi
 done < <(jq -r '.source_units[]|[.path,.before_sha256,.after_sha256]|@tsv' "$contract")
 patch=$profile/$(jq -er .patch "$contract")
 git -C "$kernel" apply --check --whitespace=error "$patch"
 git -C "$kernel" apply --whitespace=error "$patch"
 while IFS=$'\t' read -r path after;do
  printf '%s  %s\n' "$after" "$kernel/$path" | sha256sum -c --strict --quiet -
  install -Dm644 "$kernel/$path" "$work/inverse/$path"
 done < <(jq -r '.source_units[]|[.path,.after_sha256]|@tsv' "$contract")
 git -c init.defaultBranch=senemos -C "$work/inverse" init -q
 git -C "$work/inverse" apply -R --whitespace=error "$patch"
 diff -qr "$work/before" "$work/inverse" --exclude=.git
 # Reuse the exact admitted actual-callback tests in the production source.
 for cc in gcc clang;do
  for sanitize in 0 1;do
   CC=$cc SANITIZE=$sanitize bash "$profile/tests/battery-protection-observe-v2.sh" "$kernel"
   CC=$cc SANITIZE=$sanitize bash "$profile/tests/battery-observed-thresholds.sh" "$kernel"
  done
 done
 (cd "$kernel";jq -r '.source_units[].path' "$contract" | xargs sha256sum) > "$work/applied.sha256"
 printf 'Cumulative protection observe source: admitted native95,full header/C/ABI inverse,four actual-callback modes and unchanged standard getters.\n'
 exit 0
fi
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
release=$(jq -er .kernel_release "$profile/source-composition.json")
[[ $release == "$(cat "$out/include/config/kernel.release")" ]]
if [[ $phase == linked ]];then
 llvm-readelf -h "$out/drivers/power/supply/qcom_battmgr.o" | grep -F AArch64
 for symbol in uke_charge_protection_state_show uke_charge_protection_observe_v2_show;do
  llvm-nm "$out/drivers/power/supply/qcom_battmgr.o" | grep -E "[[:space:]][a-zA-Z][[:space:]]$symbol$"
 done
 [[ $(modinfo -F vermagic "$out/drivers/power/supply/qcom_battmgr.ko") == "$release "* ]]
 grep -Fq '__ATTR(uke_charge_protection_observe_v2, 0400,' "$kernel/drivers/power/supply/qcom_battmgr_uke_control.h"
 grep -Fq '&dev_attr_uke_charge_protection_observe_v2.attr,' "$kernel/drivers/power/supply/qcom_battmgr.c"
 printf 'Cumulative protection observe linked: actual final ARM64 object,module,passive legacy and explicit root-only v2 symbols.\n'
 exit 0
fi
[[ $phase == install && $# == 4 ]]
destination=$4/usr/share/senemos/uke/$release
cmp "$profile/source-composition.json" "$destination/source-composition.json"
jq -e '.charge_protection_legacy_passive_v1 and .charge_protection_observe_v2 and .charge_protection_observe_native_build==11305076 and .charge_protection_observe_native_admitted and (.charge_protection_observe_physical_accepted|not) and .speaker_gain_ceiling==223' "$destination/source-composition.json" >/dev/null
install -m644 "$work/applied.sha256" "$destination/charge-observe-source.sha256"
cmp "$work/applied.sha256" "$destination/charge-observe-source.sha256"
printf 'Cumulative protection observe package: final source seals in existing core; no new RPM,writer,worker or physical protection claim.\n'
