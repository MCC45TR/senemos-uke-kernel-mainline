#!/usr/bin/bash
# COPR only: resolve real reference profiles and compile the final native config.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath -m "${2:?Native output}")
profile=$kernel/native-profile
work=$kernel/native-generated/storage-cohort733
contract=$profile/manifests/storage-cohort-20261111.json
[[ ! -e $work && ! -e $out/.config ]]
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
sha256sum "$profile/native.config" "$kernel/boot-recipe/packaging/native/native.config" "$profile/source-composition.json" > "$kernel/native-generated/storage-cohort-parent.sha256"
cmp "$profile/native.config" "$kernel/boot-recipe/packaging/native/native.config"
node "$profile/tests/storage-cohort733.mjs" seed "$profile" "$work"
while IFS=$'\t' read -r role file;do
 mkdir "$work/before-$role" "$work/after-$role"
 cp "$profile/$file" "$work/before-$role/.config"
 cp "$work/seed-$role/.config" "$work/after-$role/.config"
 for phase in before after;do
  make -s -C "$kernel" O="$work/$phase-$role" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-23-unstable olddefconfig
  bash "$profile/tests/kernel-hardening-config-contract.sh" "$work/$phase-$role/.config"
 done
done < <(jq -r '.profiles[]|[.role,.path]|@tsv' "$contract")
node "$profile/tests/storage-cohort733.mjs" verify "$profile" "$work"
# Both sides get the same actual compiler. Retain each functional setting,
# governor delta and original pogo/toolchain comparison before admission.
for phase in before after;do
 bash "$profile/tests/governor-config-contract.sh" "$work/$phase-cdsp-before/.config" "$work/$phase-cdsp/.config"
done
# These immutable full23 references were checked in their original embedded
# initramfs context. The final nonembedded compiler configs are separate.
(cd "$kernel/native-generated/storage-cohort-history733";sha256sum -c --strict --quiet accepted.sha256)
# Exercise real refusal paths, keeping the accepted config files unchanged.
cp "$work/after-native/.config" "$work/accepted-native.config"
sed -i 's/^CONFIG_NR_CPUS=.*/CONFIG_NR_CPUS=4095/' "$work/after-native/.config"
if node "$profile/tests/storage-cohort733.mjs" verify "$profile" "$work" > "$work/unrelated-refusal.log" 2>&1;then
 echo 'Unrelated storage cohort config mutation admitted' >&2;exit 1
fi
cp "$work/accepted-native.config" "$work/after-native/.config"
cp "$work/after-cdsp/.config" "$work/accepted-cdsp.config"
sed -i 's/^CONFIG_CPU_FREQ_GOV_POWERSAVE=y$/CONFIG_CPU_FREQ_GOV_POWERSAVE=m/' "$work/after-cdsp/.config"
if node "$profile/tests/storage-cohort733.mjs" verify "$profile" "$work" > "$work/governor-refusal.log" 2>&1;then
 echo 'Lost governor capability admitted' >&2;exit 1
fi
cp "$work/accepted-cdsp.config" "$work/after-cdsp/.config"
node "$profile/tests/storage-cohort733.mjs" verify "$profile" "$work"
mkdir -p "$out"
cp "$work/after-native/.config" "$out/.config"
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-23-unstable -j4 modules_prepare
cmp "$work/after-native/.config" "$out/.config"
objects=(drivers/md/dm-crypt.o drivers/md/dm-inlinecrypt.o block/blk-crypto-fallback.o \
 fs/crypto/crypto.o fs/ext4/crypto.o fs/f2fs/file.o drivers/power/supply/qcom_battmgr.o)
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-23-unstable KCFLAGS=-Werror W=1 -j4 \
 "${objects[0]}" "${objects[1]}" "${objects[2]}" fs/crypto/ fs/ext4/ fs/f2fs/ "${objects[6]}"
for object in "${objects[@]}";do
 test -s "$out/$object"
 llvm-readelf -h "$out/$object" | grep -F AArch64
done
llvm-nm "$out/drivers/md/dm-crypt.o" | grep -E '[[:space:]]crypt_map$'
llvm-nm "$out/drivers/md/dm-inlinecrypt.o" | grep -E '[[:space:]]inlinecrypt_map$'
for filesystem in ext4 f2fs;do
 test -s "$out/fs/$filesystem/built-in.a"
 object=crypto.o
 [[ $filesystem != f2fs ]] || object=file.o
 llvm-nm "$out/fs/$filesystem/$object" | grep -E '[[:space:]]U[[:space:]]+fscrypt_' > "$work/$filesystem-fscrypt-imports.txt"
done
test -s "$out/fs/crypto/built-in.a"
for symbol in qcom_battmgr_uke_control_get_property uke_charge_protection_state_show uke_charge_protection_observe_v2_show;do
 llvm-nm "$out/drivers/power/supply/qcom_battmgr.o" | grep -E "[[:space:]][a-zA-Z][[:space:]]$symbol\$"
done
sha256sum -c --strict --quiet "$kernel/native-generated/storage-cohort-parent.sha256"
cmp "$work/after-native/.config" "$out/.config"
(cd "$out";sha256sum "${objects[@]}") > "$work/native-objects.sha256"
printf 'Actual storage cohort native: four resolved profiles/eight changes/six preserved pairwise deltas,two refusal controls,seven final-config AArch64 objects; no volume,key,encrypted I/O or full-kernel acceptance.\n'
