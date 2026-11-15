#!/usr/bin/bash
# COPR only: preserve the passive ABI and qualify explicit active observation.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 2 ]]
kernel=$(realpath "$1");out=$(realpath -m "$2")
profile=$kernel/native-profile
contract=$profile/manifests/charge-observe-v2-20261111.json
work=$kernel/native-generated/charge-observe733
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
file=drivers/power/supply/qcom_battmgr_uke_control.h
passive=$kernel/native-generated/charge-demand733/before.h
printf '%s  %s\n' e0d82e37df7b91c23aa6668ce779960cfd63b74ac0995acbd965bffcbd889c06 "$passive" | sha256sum -c --strict --quiet -
node - "$passive" "$kernel/$file" <<'NODE'
const fs=require('fs'),assert=require('assert');
const extract=p=>{const s=fs.readFileSync(p,'utf8'),a=s.indexOf('static ssize_t uke_charge_protection_state_show('),b=s.indexOf('\nstatic DEVICE_ATTR_RO(uke_charge_protection_state);',a);assert(a>=0&&b>a);return s.slice(a,b);};
assert.equal(extract(process.argv[2]),extract(process.argv[3]));
console.log('Legacy protection state callback exactly matches the passive full21 function.');
NODE
for cc in gcc clang;do
 for sanitize in 0 1;do
  CC=$cc SANITIZE=$sanitize bash "$profile/tests/battery-protection-observe-v2.sh" "$kernel"
  CC=$cc SANITIZE=$sanitize bash "$profile/tests/battery-observed-thresholds.sh" "$kernel"
 done
done
ulimit -c 0
for mutation in legacy-get hidden-provenance;do
 bad=$work/$mutation
 mkdir -p "$bad/$(dirname "$file")"
 cp "$kernel/drivers/power/supply/qcom_battmgr.c" "$bad/$(dirname "$file")/qcom_battmgr.c"
 node - "$kernel/$file" "$work/before/$file" "$bad/$file" "$mutation" <<'NODE'
const fs=require('fs'),assert=require('assert'),[input,prior,output,mode]=process.argv.slice(2);let s=fs.readFileSync(input,'utf8');
if(mode==='legacy-get'){
 const old=fs.readFileSync(prior,'utf8'),anchor='static ssize_t uke_charge_protection_state_show(',end='\nstatic DEVICE_ATTR_RO(uke_charge_protection_state);';
 const a=s.indexOf(anchor),b=s.indexOf(end,a),x=old.indexOf(anchor),y=old.indexOf(end,x);assert(a>=0&&b>a&&x>=0&&y>x);s=s.slice(0,a)+old.slice(x,y)+s.slice(b);
}else if(mode==='hidden-provenance'){
 const old='\t\trefreshed = true;';assert.equal(s.split(old).length,2);s=s.replace(old,()=> '\t\trefreshed = false;');
}else throw Error(mode);
fs.writeFileSync(output,s);
NODE
 status=0
 CC=gcc SANITIZE=0 bash "$profile/tests/battery-protection-observe-v2.sh" "$bad" > "$bad/result.log" 2>&1 || status=$?
 [[ $status == 134 ]]
 printf 'Protection observation mutant refused:%s/status%s.\n' "$mutation" "$status"
done
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-22-unstable KCFLAGS=-Werror W=1 -j4 drivers/power/supply/qcom_battmgr.o
llvm-readelf -h "$out/drivers/power/supply/qcom_battmgr.o" | grep -F AArch64
(cd "$kernel";jq -r '.source_units[].path' "$contract" | xargs sha256sum) > "$work/applied.sha256"
printf 'Actual protection observe v2 native: passive legacy identity,four compiler/sanitizer modes,two fault controls,whole full22 header/C/ABI inverse and ARM64 battery object. No SET,timer,new runtime or physical safety acceptance.\n'
