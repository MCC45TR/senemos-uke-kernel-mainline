#!/usr/bin/bash
# COPR only: additive compiled config layer with complete reference comparisons.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath -m "${2:?Production output}")
phase=${3:?seed, linked, install or check}
[[ $phase == seed || $phase == linked || $phase == install || $phase == check ]]
profile=$kernel/native-profile
contract=$profile/manifests/storage-config-delivery-20261111.json
meta=$profile/source-composition.json
work=$kernel/native-generated/storage-config-full733
jq -e '.storage_encryption_config_layer==1 and .storage_encryption_config_native_build==11307222 and
 .storage_encryption_native_admitted and .storage_encryption_enabled_in_full_candidate and
 (.storage_encryption_encrypted_io_accepted|not) and (.storage_encryption_tee_key_accepted|not) and
 .speaker_gain_ceiling==223' "$meta" >/dev/null
if [[ $phase == seed ]];then
 [[ ! -e $work ]]
 mkdir "$work"
 base_config=$(jq -er .base_native_config_sha256 "$contract")
 for file in "$profile/native.config" "$kernel/boot-recipe/packaging/native/native.config" "$out/.config";do
  printf '%s  %s\n' "$base_config" "$file" | sha256sum -c --strict --quiet -
 done
 (cd "$kernel";sha256sum native-profile/native.config boot-recipe/packaging/native/native.config) > "$work/base-inputs.sha256"
 node "$profile/packaging/native/prepare-storage-config733.mjs" "$out/.config" \
  "$profile/configs/storage-encryption733.config" "$profile/manifests/storage-config-layer-20261111.json" "$work/seed"
 cp "$work/seed/native.config" "$out/.config"
 mkdir "$work/reference-history" "$work/reference-candidates"
 # Original nfc-* and source-history inputs remain intact. These generated
 # manager references receive the same additive capability layer on both sides
 # of the retained whole-config comparison; preserve their exact preimages.
 roles=(before-native native before-cdsp cdsp before-waydroid waydroid)
 for role in "${roles[@]}";do
  input=$kernel/native-generated/migration-manager-$role/.config
  [[ -s $input ]]
  cp "$input" "$work/reference-history/$role.config"
  candidate=$work/reference-candidates/$role
  mkdir "$candidate"
  cp "$input" "$candidate/.config"
  while IFS=$'\t' read -r symbol value;do
   [[ $symbol =~ ^CONFIG_[A-Z0-9_]+$ && ($value == y || $value == m) ]]
   operation=--enable;[[ $value != m ]] || operation=--module
   bash "$kernel/scripts/config" --file "$candidate/.config" "$operation" "${symbol#CONFIG_}"
  done < <(jq -r '.changes[]|[.[0],.[2]]|@tsv' "$contract")
  make -s -C "$kernel" O="$candidate" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig
  node "$profile/tests/storage-full-config-delta733.mjs" "$input" "$candidate/.config" "$contract" "$work/$role.delta.json"
 done
 for role in "${roles[@]}";do
  cp "$work/reference-candidates/$role/.config" "$kernel/native-generated/migration-manager-$role/.config"
 done
 for role in native cdsp waydroid;do
  bash "$profile/tests/kernel-manager-config-contract.sh" \
   "$kernel/native-generated/migration-manager-before-$role/.config" \
   "$kernel/native-generated/migration-manager-$role/.config" "$profile/configs/kernel-manager/resources.config"
 done
 for prefix in before- '';do
  bash "$profile/tests/nfc-cohort-config731.sh" \
   "$kernel/native-generated/migration-manager-${prefix}native/.config" \
   "$kernel/native-generated/migration-manager-${prefix}waydroid/.config"
 done
 (cd "$work/reference-history";sha256sum *.config) > "$work/reference-history.sha256"
 touch "$work/seed-complete"
 printf 'Storage full seed: exact native seed and six encrypted manager references pass closed deltas;original histories and all old comparisons retained.\n'
 exit 0
fi
[[ -f $work/seed-complete ]]
(cd "$kernel";sha256sum -c --strict --quiet "$work/base-inputs.sha256")
(cd "$work/reference-history";sha256sum -c --strict --quiet "$work/reference-history.sha256")
release=$(jq -er .kernel_release "$meta")
[[ $release == "$(cat "$out/include/config/kernel.release")" ]]
if [[ $phase == linked ]];then
 [[ ! -e $work/qualification.json ]]
 before=$work/actual-linked-base
 mkdir "$before"
 cp "$profile/native.config" "$before/.config"
 bash "$kernel/scripts/config" --file "$before/.config" --set-str INITRAMFS_SOURCE "$out/boot-initramfs.cpio.gz"
 make -s -C "$kernel" O="$before" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig
 node "$profile/tests/storage-full-config-delta733.mjs" "$before/.config" "$out/.config" "$contract" "$work/linked.delta.json"
 objects=(drivers/md/dm-crypt.o drivers/md/dm-inlinecrypt.o block/blk-crypto-fallback.o \
  fs/crypto/crypto.o fs/ext4/crypto.o fs/f2fs/file.o drivers/power/supply/qcom_battmgr.o \
  crypto/essiv.o crypto/xts.o)
 for object in "${objects[@]}";do
  test -s "$out/$object"
  llvm-readelf -h "$out/$object" | grep -F AArch64
 done
 for module in drivers/md/dm-crypt drivers/md/dm-inlinecrypt crypto/essiv;do
  [[ $(modinfo -F vermagic "$out/$module.ko") == "$release "* ]]
  signed=$out/boot-modules/lib/modules/$release/kernel/$module.ko.zst
  [[ -s $signed && -n $(modinfo -F signer "$signed") ]]
 done
 grep -Fx 'kernel/crypto/xts.ko' "$out/modules.builtin"
 [[ ! -e $out/boot-modules/lib/modules/$release/kernel/crypto/xts.ko.zst ]]
 llvm-nm "$out/drivers/md/dm-crypt.o" | grep -E '[[:space:]]crypt_map$'
 llvm-nm "$out/drivers/md/dm-inlinecrypt.o" | grep -E '[[:space:]]inlinecrypt_map$'
 for filesystem in ext4 f2fs;do
  object=crypto.o;[[ $filesystem != f2fs ]] || object=file.o
  llvm-nm "$out/fs/$filesystem/$object" | grep -E '[[:space:]]U[[:space:]]+fscrypt_' > "$work/$filesystem-imports.txt"
 done
 grep -E ' [Tt] fscrypt_get_encryption_info$' "$out/System.map"
 test -s "$out/fs/crypto/built-in.a"
 test -s "$out/arch/arm64/boot/Image"
 node - "$contract" "$out/.config" "$work/qualification.json" "$release" <<'NODE'
const fs=require('fs'),crypto=require('crypto'),[c,f,p,release]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(c)),hash=x=>crypto.createHash('sha256').update(fs.readFileSync(x)).digest('hex');fs.writeFileSync(p,JSON.stringify({schema:1,kernel_release:release,source_check:m.proof.build,source_receipt_sha256:m.proof.receipt_sha256,base_native_config_sha256:m.base_native_config_sha256,seed_config_sha256:m.seed_config_sha256,resolved_config_sha256:hash(f),exact_changes:m.changes,manager_references:6,actual_arm64_objects:9,signed_crypto_modules:3,xts_builtin_verified:true,all_other_effective_options_retained:true,encrypted_io_accepted:false,tee_keys_accepted:false,encrypted_boot_accepted:false,new_runtime_packages:0},null,2)+'\n');
NODE
 (cd "$out";sha256sum "${objects[@]}" .config) > "$work/native-objects.sha256"
 printf 'Storage full linked: exact eight-option delta,nine ARM64 crypto/fs/battery objects,three signed crypto modules and built-in XTS;no encrypted I/O,key or boot acceptance.\n'
 exit 0
fi
[[ $# == 4 && -s $work/qualification.json ]]
destination=$4/usr/share/senemos/uke/$release
if [[ $phase == install ]];then
 install -m644 "$work/qualification.json" "$destination/storage-config-qualified.json"
 install -m644 "$work/native-objects.sha256" "$destination/storage-config-native.sha256"
fi
cmp "$work/qualification.json" "$destination/storage-config-qualified.json"
cmp "$work/native-objects.sha256" "$destination/storage-config-native.sha256"
cmp "$out/.config" "$4/usr/lib/modules/$release/config"
cmp "$meta" "$destination/source-composition.json"
printf 'Storage full package:%s: exact config/objects admission in existing core;no new runtime or physical encryption claim.\n' "$phase"
