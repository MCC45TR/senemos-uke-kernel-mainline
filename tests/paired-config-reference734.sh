#!/usr/bin/bash
# Native COPR diagnostic: replay exact source preparation, resolve both old
# reference cohorts, and retain observations. No Image/module delivery or test
# admission is inferred from a successful diagnostic RPM build.
set -Eeuo pipefail
[[ $# == 3 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
parent=$(realpath "$1");candidate=$(realpath "$2");result=$(realpath -m "$3")
[[ ! -e $result && ! -L $result ]]
mkdir -p "$result"
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
for item in parent candidate;do
 archive=$parent;version=7.3.3
 [[ $item != candidate ]] || { archive=$candidate;version=7.3.4; }
 stage=$work/$item
 mkdir -p "$stage/"{SOURCES,BUILD,BUILDROOT,RPMS,SRPMS,SPECS} "$result/$item"
 rpm2cpio "$archive" | cpio -t --quiet > "$stage/paths"
 awk '{name=$0;sub(/^\.\//,"",name);if(name!~/^[A-Za-z0-9_.+-]+$/||seen[name]++)bad=1;count++}END{if(bad||count<10||count>64)exit 1}' "$stage/paths"
 rpm2cpio "$archive" | (cd "$stage/SOURCES";cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
 spec=$stage/SOURCES/senemos-uke-linux-kernel-mainline-unstable.spec
 # Nested -bp executes the published prep only, with its complete source
 # archive, patch/config/hash contracts and native source fixtures retained.
 rpmbuild -bp --nodeps --target aarch64 --define "_topdir $stage" \
  --define "_sourcedir $stage/SOURCES" "$spec" > "$result/$item/preparation.log" 2>&1
 mapfile -t kernels < <(find "$stage/BUILD" -type f -path "*/linux-$version/Makefile" -printf '%h\n')
 [[ ${#kernels[@]} == 1 ]]
 kernel=${kernels[0]}
 for role in cdsp waydroid cdsp-before;do
  ref=$kernel/native-generated/nfc-$role-reference
  mkdir -p "$ref"
  input=$kernel/native-profile/configs/nfc-$role-reference.config
  [[ $role != cdsp-before ]] || input=$kernel/native-profile/configs/governor-before-nfc-cdsp.config
  cp "$input" "$ref/.config"
  # This is the exact original source28 reference context. It is a config
  # string only; no initramfs is made or read by olddefconfig.
  bash "$kernel/scripts/config" --file "$ref/.config" --set-str INITRAMFS_SOURCE /builddir/build/native-kernel-out/boot-initramfs.cpio.gz
  make -s -C "$kernel" O="$ref" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig
  install -m644 "$ref/.config" "$result/$item/$role.config"
 done
 set +e
 bash "$kernel/native-profile/tests/cdsp-pogo-toolchain-contract.sh" "$result/$item/cdsp-before.config" > "$result/$item/toolchain-contract.log" 2>&1
 guard=$?
 bash "$kernel/native-profile/tests/governor-config-contract.sh" "$result/$item/cdsp-before.config" "$result/$item/cdsp.config" > "$result/$item/governor-contract.log" 2>&1
 governor=$?
 set -e
 [[ $guard == 0 || $guard == 1 ]]
 [[ $governor == 0 || $governor == 1 ]]
 jq -n --arg version "$version" --argjson guard "$guard" --argjson governor "$governor" \
  '{upstream_version:$version,toolchain_contract_exit:$guard,governor_contract_exit:$governor,source_preparation_completed:true,full_image_produced:false,hardware_qualified:false}' > "$result/$item/observation.json"
 # Retain the exact original guards for review; do not refresh their digest.
 install -m644 "$kernel/native-profile/tests/cdsp-pogo-config-contract.sh" "$kernel/native-profile/tests/cdsp-pogo-toolchain-contract.sh" "$result/$item/"
 # The frozen input SRPM and captured observations retain provenance; remove
 # only this owned prepared tree before allocating the second source tree.
 find "$stage" -depth -delete
done
node - "$result" <<'JS'
const fs=require('fs'),crypto=require('crypto'),root=process.argv[2];
function config(path){const out=new Map();for(const line of fs.readFileSync(path,'utf8').split('\n')){const m=line.match(/^(CONFIG_[A-Z0-9_]+)=(.+)$/)||line.match(/^# (CONFIG_[A-Z0-9_]+) is not set$/);if(m){if(out.has(m[1]))throw Error('Duplicate '+m[1]);out.set(m[1],m[2]??'n');}}if(out.size<1000)throw Error('Incomplete config');return out;}
const roles={};for(const role of ['cdsp','waydroid','cdsp-before']){const a=config(`${root}/parent/${role}.config`),b=config(`${root}/candidate/${role}.config`);roles[role]=[...new Set([...a.keys(),...b.keys()])].sort().flatMap(key=>a.get(key)===b.get(key)?[]:[{key,before:a.get(key)??null,after:b.get(key)??null}]);}
const observations=Object.fromEntries(['parent','candidate'].map(role=>[role,JSON.parse(fs.readFileSync(`${root}/${role}/observation.json`))]));
fs.writeFileSync(`${root}/paired-observation.json`,JSON.stringify({schema_version:1,scope:'Native diagnostic observation only; no full or hardware admission',observations,configuration_differences:roles,full_image_produced:false,source_native_qualification_claimed:false},null,2)+'\n');
JS
(cd "$result";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
printf 'Paired source preparation and independent reference configurations captured; historical guard outcomes are observations, not bypassed production acceptance.\n'
