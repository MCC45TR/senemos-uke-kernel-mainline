#!/usr/bin/bash
# COPR only: actual parent preparation, admission and passive adapter bodies.
set -Eeuo pipefail
[[ $# == 4 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2");owner=$(realpath "$3");result=$(realpath -m "$4")
bash "$owner/src/camera/native-parent734/apply.sh" "$kernel" "$owner" "$result"
model=$result/model
mkdir -p "$model/linux" "$model/constructor" "$model/handoff"
for header in compiler mutex types;do printf '#pragma once\n' > "$model/linux/$header.h";done
for name in core lut clock startup floor native;do
 cp "$kernel/drivers/clk/qcom/provider/camcc-sm7675-crm-$name.h" "$model/constructor/"
done
cp "$kernel/drivers/clk/qcom/provider/rom-report.h" "$model/constructor/"
node "$owner/tests/fixtures/camera-parent-model.mjs" constructor "$owner/tests/fixtures/camcc-crm-native-check.c" "$model/constructor/check.c"
cp "$model/constructor/camcc-sm7675-crm-native.h" "$model/constructor/after.h"
cp "$result/before/drivers/clk/qcom/provider/camcc-sm7675-crm-native.h" "$model/constructor/camcc-sm7675-crm-native.h"
for compiler in gcc clang;do
 "$compiler" -std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -Wno-unused-function -DUKE_PARENT_BEFORE -I"$model" -I"$model/constructor" "$model/constructor/check.c" -o "$model/before"
 set +e
 (ulimit -c 0;timeout --kill-after=2s 20s "$model/before") > "$model/before-$compiler.log" 2>&1
 status=$?
 set -e
 [[ $status == 134 ]] && grep -Fq 'parent_preparations==1' "$model/before-$compiler.log"
 printf 'Before-control: original constructor reaches ROM without local parent preparation: %s/status134\n' "$compiler" >> "$result/results.txt"
done
cp "$model/constructor/after.h" "$model/constructor/camcc-sm7675-crm-native.h"
# Import the same framework helpers used by the qualified caller fixture.
awk '/^struct cam_cc_clock \{/ {copy=1} copy {print;if($0=="};")exit}' "$kernel/drivers/clk/qcom/provider/camcc-sm7675-clocks.h" > "$model/handoff/clock-state.h"
awk '/^static inline int dev_set_drv_sync_state\(/ {copy=1} copy {print;if($0=="}")exit}' "$kernel/include/linux/device.h" > "$model/handoff/device-sync-function.c"
awk '/^static void genpd_set_stay_on\(/ {copy=1} copy {print;if($0=="}")exit}' "$kernel/drivers/pmdomain/core.c" > "$model/handoff/genpd-stay-function.c"
printf '%s  %s\n' 105f627f098606f82fb739dfb5cb8a9076ef3214826eb1d261289a78a1156434 "$model/handoff/device-sync-function.c" b367dc2f87a740bdd1b885e09c17bd65dd1985a3f0881a013395d6b513ed9dc8 "$model/handoff/genpd-stay-function.c" | sha256sum -c --strict --quiet -
for part in handoff registration;do sed '/^#include /d' "$kernel/drivers/clk/qcom/provider/camcc-sm7675-$part.h" > "$model/handoff/native-$part.h";done
awk '/^static ssize_t probe_(phase|error|gate_register|gate_readback)_show\(/ {copy=1;n++} copy{print;if($0=="}")copy=0}END{if(n!=4||copy)exit 1}' "$kernel/drivers/clk/qcom/camcc-sm7675.c" > "$model/handoff/native-probe-show.c"
awk '/^static u32 cam_cc_sm7675_critical_cbcrs\[\] =/{copy=1;n++}copy{print;if($0=="};")copy=0}END{if(n!=1||copy)exit 1}' "$kernel/drivers/clk/qcom/camcc-sm7675-data.h" > "$model/handoff/critical-gates.h"
node "$owner/tests/fixtures/camera-parent-model.mjs" handoff "$owner/tests/fixtures/camcc-native-check.c" "$model/handoff/check.c"
for compiler in gcc clang;do
 for mode in plain sanitized;do
  flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -Wno-unused-function -Wno-unused-parameter -Wno-sign-compare)
  [[ $mode != sanitized ]] || flags+=("-fsanitize=address,undefined" -fno-sanitize-recover=all -fno-omit-frame-pointer)
  for kind in constructor handoff;do
   "$compiler" "${flags[@]}" -I"$model" -I"$model/$kind" "$model/$kind/check.c" -o "$model/check"
   readelf -h "$model/check" | grep -F AArch64
   timeout --kill-after=2s 20s "$model/check" >> "$result/results.txt"
  done
 done
done
# The original independent OEM catalog, powered snapshots and semantic mutants.
passive=$model/passive
mkdir -p "$passive/tests/fixtures" "$passive/src/camera/provider"
cp "$owner/tests/"camcc-crm-passive{.sh,-catalog.mjs} "$passive/tests/"
cp "$owner/tests/fixtures/camcc-crm-passive-check.c" "$passive/tests/fixtures/"
cp "$kernel/drivers/clk/qcom/provider/camcc-sm7675-crm-passive.h" "$passive/src/camera/provider/"
bash "$passive/tests/camcc-crm-passive.sh" "$kernel/crm-passive/oracle/camcc-cliffs.c" >> "$result/passive-results.txt"
[[ $(grep -c '^PASS: camera parent constructor:' "$result/results.txt") == 4 ]]
[[ $(grep -c '^PASS: camera parent PLL:' "$result/results.txt") == 4 ]]
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror -j2 drivers/clk/qcom/camcc-sm7675.o
stage=$out/camera-parent734-adapter
[[ ! -e $stage ]]
mkdir "$stage"
cat > "$stage/parent.c" <<'C'
// SPDX-License-Identifier: GPL-2.0-only
#define UKE_CAMCC_OBJECT_TEST
#include "camcc-sm7675.c"
int uke_camera_parent_admit_check(void);
int uke_camera_parent_finalize_check(void);
int uke_camera_parent_admit_check(void) {return cam_cc_crm_native_admit();}
int uke_camera_parent_finalize_check(void) {return cam_cc_crm_native_plls_finalize();}
C
printf '%s\n' 'obj-y += parent.o' "ccflags-y += -I$kernel/drivers/clk/qcom" > "$stage/Makefile"
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 M="$stage" KCFLAGS=-Werror -j2 parent.o
for object in "$out/drivers/clk/qcom/camcc-sm7675.o" "$stage/parent.o";do llvm-readelf -h "$object" | grep -F AArch64;done
for symbol in uke_camera_parent_admit_check uke_camera_parent_finalize_check;do
 llvm-nm --defined-only "$stage/parent.o" | awk -v symbol="$symbol" '$NF==symbol{found=1}END{exit !found}'
done
(cd "$kernel";sha256sum -c --strict --quiet "$result/source.sha256")
sha256sum "$out/drivers/clk/qcom/camcc-sm7675.o" "$stage/parent.o" > "$result/native-objects.sha256"
jq -n '{schema_version:1,constructor_modes:4,actual_pll_and_caller_modes:4,passive_modes:4,passive_semantic_mutants:4,before_controls:2,actual_arm64_objects:2,firmware_plls_unchanged:true,original_limits_and_guards_retained:true,hardware_cause_confirmed:false,physical_camera_accepted:false}' > "$result/qualification.json"
cat "$result/results.txt"
cat "$result/passive-results.txt"
