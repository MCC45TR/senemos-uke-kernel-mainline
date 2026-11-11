#!/usr/bin/bash
# COPR only: qualify demand reads over the actual full21 battery header.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 2 ]]
kernel=$(realpath "$1");out=$(realpath -m "$2")
profile=$kernel/native-profile
contract=$profile/manifests/charge-demand-20261111.json
work=$kernel/native-generated/charge-demand733
file=drivers/power/supply/qcom_battmgr_uke_control.h
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
printf '%s  %s\n' "$(jq -er .unchanged_driver_sha256 "$contract")" "$kernel/drivers/power/supply/qcom_battmgr.c" | sha256sum -c --strict --quiet -
for cc in gcc clang;do
 for sanitize in 0 1;do
  CC=$cc SANITIZE=$sanitize bash "$profile/tests/battery-demand-observation.sh" "$kernel"
  CC=$cc SANITIZE=$sanitize bash "$profile/tests/battery-observed-thresholds.sh" "$kernel"
 done
done
ulimit -c 0
for mutation in omit-refresh hide-error;do
 bad=$work/$mutation
 mkdir -p "$bad/$(dirname "$file")"
 node - "$kernel/$file" "$bad/$file" "$mutation" <<'NODE'
const fs=require('fs'),[input,output,mode]=process.argv.slice(2),s=fs.readFileSync(input,'utf8'),a=s.indexOf('static ssize_t uke_charge_protection_state_show('),b=s.indexOf('\nstatic DEVICE_ATTR_RO(uke_charge_protection_state);',a);
if(a<0||b<0)throw Error('Actual show function missing');
let f=s.slice(a,b),old,next;
if(mode==='omit-refresh'){old='\tif (!valid) {';next='\tif (false && !valid) {';}
else if(mode==='hide-error'){old='\t\t\treturn ret;';next='\t\t\treturn 0;';}else throw Error('Unknown mutation');
if(f.split(old).length!==2)throw Error('Mutation anchor');f=f.replace(old,()=>next);fs.writeFileSync(output,s.slice(0,a)+f+s.slice(b));
NODE
 status=0
 CC=gcc SANITIZE=0 bash "$profile/tests/battery-demand-observation.sh" "$bad" > "$bad/result.log" 2>&1 || status=$?
 [[ $status == 134 ]]
 printf 'Demand protection mutant refused:%s/status%s.\n' "$mutation" "$status"
done
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-21-unstable KCFLAGS=-Werror W=1 -j4 drivers/power/supply/qcom_battmgr.o
llvm-readelf -h "$out/drivers/power/supply/qcom_battmgr.o" | grep -F AArch64
(cd "$kernel";sha256sum "$file" drivers/power/supply/qcom_battmgr.c) > "$work/applied.sha256"
printf 'Actual demand protection native: four compiler/sanitizer modes,two fault controls,whole full21 header inverse and ARM64 battery object. No timer,SET,lease,daemon retirement or physical safety acceptance.\n'
