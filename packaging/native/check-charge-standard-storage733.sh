#!/usr/bin/bash
# COPR only: real power-supply getters and additive storage capability objects.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 2 ]]
kernel=$(realpath "$1");out=$(realpath -m "$2")
profile=$kernel/native-profile
contract=$profile/manifests/charge-standard-storage-20261111.json
work=$kernel/native-generated/charge-standard-storage733
file=drivers/power/supply/qcom_battmgr_uke_control.h
cfile=drivers/power/supply/qcom_battmgr.c
[[ ! -e $work ]]
mkdir -p "$work/inverse/$(dirname "$file")"
printf '%s  %s\n' "$(jq -er '.source_units[0].before_sha256' "$contract")" "$kernel/$file" | sha256sum -c --strict --quiet -
printf '%s  %s\n' "$(jq -er .unchanged_driver_sha256 "$contract")" "$kernel/$cfile" | sha256sum -c --strict --quiet -
cp "$kernel/$file" "$work/before.h"
patch=$profile/$(jq -er .patch "$contract")
git -C "$kernel" apply --check --whitespace=error "$patch"
git -C "$kernel" apply --whitespace=error "$patch"
printf '%s  %s\n' "$(jq -er '.source_units[0].after_sha256' "$contract")" "$kernel/$file" | sha256sum -c --strict --quiet -
cp "$kernel/$file" "$work/inverse/$file"
git -C "$work/inverse" apply -R --whitespace=error "$patch"
cmp "$work/before.h" "$work/inverse/$file"
for cc in gcc clang;do for sanitize in 0 1;do CC=$cc SANITIZE=$sanitize bash "$profile/tests/battery-observed-thresholds.sh" "$kernel";done;done
ulimit -c 0
for mutation in missing_getter unsupported_bounds;do
 bad=$work/refused-$mutation
 mkdir -p "$bad/$(dirname "$file")"
 cp "$kernel/$file" "$bad/$file"
 cp "$kernel/$cfile" "$bad/$cfile"
 node - "$bad/$file" "$mutation" <<'NODE'
const fs=require('fs'),[p,mutation]=process.argv.slice(2),s=fs.readFileSync(p,'utf8');let next;
if(mutation==='missing_getter'){const a='if (ret == -ENODATA)\n\t\tret = qcom_battmgr_uke_observed_threshold';if(s.split(a).length!==2)throw Error('Getter boundary');next=s.replace(a,a.replace('ENODATA','ENOSYS'));}
else{const pattern=/if \(start >= end \|\| end > CHARGE_CTRL_END_THR_MAX \|\|[\s\S]*?end < CHARGE_CTRL_END_THR_MIN\)\)\)/g;if([...s.matchAll(pattern)].length!==1)throw Error('Bound boundary');next=s.replace(pattern,'if (start >= end || end > 100)');}fs.writeFileSync(p,next);
NODE
 status=0
 CC=gcc SANITIZE=0 bash "$profile/tests/battery-observed-thresholds.sh" "$bad" > "$bad/result.log" 2>&1 || status=$?
 [[ $status == 134 ]]
 printf 'Observed threshold regression refused:%s/status%s.\n' "$mutation" "$status"
done
bash "$profile/packaging/native/check-storage-encryption733.sh" "$kernel" "$out"
# The battery object must use this same final candidate configuration.
rm -f "$out/drivers/power/supply/qcom_battmgr.o"
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-20-unstable KCFLAGS=-Werror W=1 -j4 drivers/power/supply/qcom_battmgr.o
llvm-readelf -h "$out/drivers/power/supply/qcom_battmgr.o" | grep -F AArch64
llvm-nm "$out/drivers/power/supply/qcom_battmgr.o" | grep -E '[[:space:]][a-zA-Z][[:space:]]qcom_battmgr_uke_control_get_property$'
printf '%s  %s\n' "$(jq -er .unchanged_driver_sha256 "$contract")" "$kernel/$cfile" | sha256sum -c --strict --quiet -
(cd "$kernel";sha256sum "$file" "$cfile") > "$work/applied.sha256"
printf 'Actual standard charge/storage native: whole full20 header inverse,four callback modes/two regressions,final-config ARM64 battery and six encryption objects; no charging SET,volume,key or physical acceptance.\n'
