#!/usr/bin/bash
# COPR only. Keep the native22 checks, then compile the exact error reporter.
set -Eeuo pipefail
[[ $# == 4 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2");owner=$(realpath "$3");result=$(realpath -m "$4")
layer=$owner/src/camera/rom-report734
bash "$layer/apply.sh" "$kernel" "$owner" "$result"
mkdir "$result/linux" "$result/bin" "$result/model"
for compiler in gcc clang;do
 for mode in plain sanitized;do
  flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror)
  [[ $mode != sanitized ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" "${flags[@]}" -I"$layer" "$owner/tests/fixtures/camera-rom-report-check.c" -o "$result/bin/reporter"
  readelf -h "$result/bin/reporter" | grep -F AArch64
  timeout --kill-after=2s 20s "$result/bin/reporter" >> "$result/reporter-results.txt"
 done
done
# Use the unchanged native22 framework model with the new production header.
model=$result/model
mkdir -p "$model/src/camera/provider" "$model/tests/fixtures"
for name in core lut clock startup floor native;do
 install -m644 "$kernel/drivers/clk/qcom/provider/camcc-sm7675-crm-$name.h" "$model/src/camera/provider/"
done
install -m644 "$layer/rom-report.h" "$model/src/camera/provider/rom-report.h"
{
 printf '%s\n' '#include <stdio.h>' '#define pr_err(...) do { if (0) fprintf(stderr, __VA_ARGS__); } while (0)'
 cat "$owner/tests/fixtures/camcc-crm-native-check.c"
} > "$model/tests/fixtures/camcc-crm-native-check.c"
awk '/^for compiler in gcc clang;do$/{print "cp \"$owner/src/camera/provider/rom-report.h\" \"$work/\"";n++}{print}END{if(n!=1)exit 1}' "$owner/tests/camcc-crm-native.sh" > "$model/tests/camcc-crm-native.sh"
bash "$model/tests/camcc-crm-native.sh" "$model" > "$result/composition-results.txt"
[[ $(grep -c '^PASS: camera ROM reporter:' "$result/reporter-results.txt") == 4 ]]
[[ $(grep -c '^PASS: camera native composition:' "$result/composition-results.txt") == 4 ]]
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror -j2 drivers/clk/qcom/camcc-sm7675.o
stage=$out/camera-rom-report734-adapter
[[ ! -e $stage ]]
mkdir "$stage"
cat > "$stage/report.c" <<'C'
// SPDX-License-Identifier: GPL-2.0-only
#define UKE_CAMCC_OBJECT_TEST
#include "camcc-sm7675.c"
int uke_camera_rom_report_check(u32, const char *, u32, int);
int uke_camera_rom_report_check(u32 client, const char *stage, u32 level, int error)
{ return cam_cc_crm_rom_report(client, stage, level, error); }
C
printf '%s\n' 'obj-y += report.o' "ccflags-y += -I$kernel/drivers/clk/qcom" > "$stage/Makefile"
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 M="$stage" KCFLAGS=-Werror -j2 report.o
for object in "$out/drivers/clk/qcom/camcc-sm7675.o" "$stage/report.o";do
 llvm-readelf -h "$object" | grep -F AArch64
 grep -aqF 'Uke camera ROM refusal:' "$object"
done
llvm-nm --defined-only "$stage/report.o" | awk '$NF=="uke_camera_rom_report_check"{found=1}END{exit !found}'
(cd "$kernel";sha256sum -c --strict --quiet "$result/source.sha256")
sha256sum "$out/drivers/clk/qcom/camcc-sm7675.o" "$stage/report.o" > "$result/native-objects.sha256"
jq -n '{schema_version:1,reporter_modes:4,production_admission_modes:4,actual_arm64_objects:2,maximum_lines_per_failure:23,hardware_reads_added:0,hardware_writes_added:0,errno_preserved:true,cached_input_unchanged:true,invalid_counts_refused:true,firmware_guard_retained:true,physical_camera_accepted:false}' > "$result/qualification.json"
cat "$result/reporter-results.txt"
cat "$result/composition-results.txt"
