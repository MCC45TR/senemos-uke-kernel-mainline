#!/usr/bin/bash
# Real upstream objects on the COPR worker; no target block device/key operation.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath "${2:?Existing native output}")
profile=$kernel/native-profile
work=$kernel/native-generated/storage-encryption733
[[ ! -e $work ]]
mkdir "$work"
cp "$out/.config" "$work/before.config"
while IFS='=' read -r symbol value;do
 [[ $symbol == \#* || -z $symbol ]] && continue
 [[ $symbol =~ ^CONFIG_[A-Z0-9_]+$ && ($value == y || $value == m) ]]
 operation=--enable
 [[ $value != m ]] || operation=--module
 bash "$kernel/scripts/config" --file "$out/.config" "$operation" "${symbol#CONFIG_}"
done < "$profile/configs/storage-encryption733.config"
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig
node "$profile/tests/storage-encryption-config733.mjs" "$work/before.config" "$out/.config" "$profile/configs/storage-encryption733.config" "$work/delta.tsv"
bash "$profile/tests/kernel-hardening-config-contract.sh" "$out/.config"
release=$(jq -er .full_release "$profile/manifests/cumulative-release.json")
objects=(drivers/md/dm-crypt.o drivers/md/dm-inlinecrypt.o block/blk-crypto-fallback.o \
 fs/crypto/crypto.o fs/ext4/crypto.o fs/f2fs/file.o)
# Built-in composite names are flattened into the directory archive. Request
# those directories and verify their real crypto constituents, not a nonexistent
# module-style fscrypto.o/ext4.o/f2fs.o target for CONFIG_*_FS=y.
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="-$release-unstable" KCFLAGS=-Werror W=1 -j4 \
 "${objects[0]}" "${objects[1]}" "${objects[2]}" fs/crypto/ fs/ext4/ fs/f2fs/
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
cp "$out/.config" "$work/candidate.config"
printf 'Actual AArch64 dm-crypt/inlinecrypt, blk-crypto fallback, fscrypt and EXT4/F2FS integration objects passed; no encrypted I/O, keys, mount, TEE command or device acceptance.\n'
