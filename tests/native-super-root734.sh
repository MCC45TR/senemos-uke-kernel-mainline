#!/usr/bin/bash
# COPR only: exercise the prepared header, then compile its real ARM64 caller.
set -Eeuo pipefail
[[ $# == 2 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2")
here=$(cd -- "$(dirname -- "$0")" && pwd)
layer=$(cd -- "$here/.." && pwd)
result=$PWD/super-root734-result
[[ ! -e $result && ! -L $result && -f $out/.config ]]
bash "$layer/src/boot/super-root734/apply-source.sh" "$kernel" "$result"
mkdir -p "$result/legacy/src/boot" "$result/legacy/tests" "$result/headers"
cp "$result/parent-root-selector.h" "$result/legacy/src/boot/uke-root-selector.h"
cp "$kernel/native-profile/tests/root-selector-contract.cpp" "$result/legacy/tests/"
cp "$result/parent-root-selector.h" "$result/headers/uke-root-selector.h"
cp "$layer/src/boot/super-root734/uke-super-root-selector.h" "$result/headers/"
: > "$result/native-results.txt"
for compiler in g++ clang++;do
 for mode in plain sanitized;do
  flags=()
  [[ $mode != sanitized ]] || flags=(-fsanitize=address,undefined -fno-omit-frame-pointer)
  "$compiler" -std=c++20 -O2 -g -UNDEBUG -Wall -Wextra -Werror "${flags[@]}" \
   "$result/legacy/tests/root-selector-contract.cpp" -o "$result/legacy-check"
  readelf -h "$result/legacy-check" | grep -F AArch64
  timeout 15s "$result/legacy-check"
  "$compiler" -std=c++20 -O2 -g -UNDEBUG -Wall -Wextra -Werror "${flags[@]}" \
   -I"$result/headers" "$here/super-root734.cpp" -o "$result/rescue-check"
  readelf -h "$result/rescue-check" | grep -F AArch64
  timeout 15s "$result/rescue-check" >> "$result/native-results.txt"
 done
done
cat "$result/native-results.txt"
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror -j2 \
 arch/arm64/kernel/uke-abl.o arch/arm64/kernel/setup.o
for object in arch/arm64/kernel/uke-abl.o arch/arm64/kernel/setup.o;do
 llvm-readelf -h "$out/$object" | grep -F AArch64
done
bash "$kernel/native-profile/src/boot/check-root-capability.sh" "$out/arch/arm64/kernel/uke-abl.o"
bash "$here/check-super-root-note734.sh" "$out/arch/arm64/kernel/uke-abl.o"
llvm-nm "$out/arch/arm64/kernel/uke-abl.o" | awk '$NF=="uke_abl_prepare_cmdline"&&$(NF-1)=="T"{found=1}END{exit !found}'
llvm-nm "$out/arch/arm64/kernel/setup.o" | awk '$NF=="uke_abl_prepare_cmdline"&&$(NF-1)=="U"{found=1}END{exit !found}'
cmp "$result/parent-root-selector.h" "$kernel/arch/arm64/kernel/uke-root-selector.h"
(cd "$kernel";sha256sum -c --strict --quiet "$result/source.sha256")
(cd "$out";sha256sum arch/arm64/kernel/{uke-abl,setup}.o) > "$result/native-objects.sha256"
[[ $(grep -c '^PASS: super root' "$result/native-results.txt") == 4 && ! -e $out/arch/arm64/boot/Image ]]
jq -n --arg hash "$(sha256sum "$result/parent-root-selector.h" | cut -d' ' -f1)" \
 '{schema_version:1,prepared_parent_header_sha256:$hash,prepared_parent_header_preserved:true,
   compiler_modes:4,actual_arm64_objects:2,exact_old_and_new_capability_notes:true,
   readonly_rescue_parser_qualified:true,explicit_userdata_super_optin:true,
   seed_contract_bytes:4294967296,initrd_role_mapping_integrated:false,
   contains_kernel_image:false,physical_device_accessed:false,physical_acceptance:false}' > "$result/qualification.json"
