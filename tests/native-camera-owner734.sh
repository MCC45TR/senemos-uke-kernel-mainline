#!/usr/bin/bash
# COPR only: actual owner/transport composition and complete ARM64 provider.
set -Eeuo pipefail
[[ $# == 2 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2")
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
result=$PWD/camera-owner734-result
bash "$owner/src/camera/provider/apply-crm-owner734.sh" "$kernel" "$owner" "$result"
bash "$owner/tests/camcc-crm-owner.sh" "$owner" > "$result/owner-results.txt"
cat "$result/owner-results.txt"
bash "$owner/tests/camcc-crm-rom.sh" > "$result/rom-results.txt"
cat "$result/rom-results.txt"
bash "$owner/tests/camcc-crm-startup.sh" > "$result/startup-results.txt"
cat "$result/startup-results.txt"
bash "$owner/tests/camcc-crm-floor.sh" > "$result/floor-results.txt"
cat "$result/floor-results.txt"
bash "$owner/tests/camcc-crm-native.sh" "$owner" > "$result/composition-results.txt"
cat "$result/composition-results.txt"
for compiler in gcc clang;do
 for mode in plain sanitized;do
  flags='-UNDEBUG'
  [[ $mode != sanitized ]] || flags+=' -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer'
  CC=$compiler CAMCC_NATIVE_TEST_FLAGS="$flags" bash "$owner/tests/camcc-native731-contract.sh" "$kernel" >> "$result/caller-results.txt"
 done
done
cat "$result/caller-results.txt"
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror -j2 drivers/clk/qcom/camcc-sm7675.o
stage=$out/camera-owner734-adapter
[[ ! -e $stage ]]
mkdir "$stage"
cat > "$stage/owner.c" <<'C'
// SPDX-License-Identifier: GPL-2.0-only
#define UKE_CAMCC_OBJECT_TEST
#include "camcc-sm7675.c"
#include "provider/camcc-sm7675-crm-startup.h"
#include "provider/camcc-sm7675-crm-floor.h"
int uke_camera_floor_init_check(struct cam_cc_crm_floor *,const u32 *,int (*)(void *,u32,u32,u32),void *);
int uke_camera_floor_vote_check(void *,u32,u32,u32);
int uke_camera_floor_sync_check(struct cam_cc_crm_floor *);
int uke_camera_owner_bind_check(void);
int uke_camera_native_admit_check(void);
int uke_camera_native_sync_check(void);
int uke_camera_native_resume_check(void *);
int uke_camera_rom_check(u32,cam_cc_crm_lut_read_fn,void *,struct cam_cc_crm_lut *);
int uke_camera_managed_check(struct cam_cc_crm_clock *);
int uke_camera_startup_check(const struct cam_cc_crm_caps *,const struct cam_cc_crm_lut *,cam_cc_crm_lut_read_fn,void *,struct cam_cc_crm_startup *);
int uke_camera_owner_bind_check(void) {return cam_cc_crm_owner_transport_bind();}
int uke_camera_native_admit_check(void) {return cam_cc_crm_native_admit();}
int uke_camera_native_sync_check(void) {return cam_cc_crm_native_sync();}
int uke_camera_native_resume_check(void *context) {return cam_cc_crm_native_resume(context);}
int uke_camera_rom_check(u32 client,cam_cc_crm_lut_read_fn read,void *context,struct cam_cc_crm_lut *table)
{return cam_cc_crm_rom_load(client,read,context,table);}
int uke_camera_managed_check(struct cam_cc_crm_clock *clients) {return cam_cc_crm_managed_attach(clients);}
int uke_camera_startup_check(const struct cam_cc_crm_caps *caps,const struct cam_cc_crm_lut *tables,cam_cc_crm_lut_read_fn read,void *context,struct cam_cc_crm_startup *out)
{return cam_cc_crm_startup_read(caps,tables,0x2000,read,context,out);}
int uke_camera_floor_init_check(struct cam_cc_crm_floor *f,const u32 *v,int (*send)(void *,u32,u32,u32),void *c) {return cam_cc_crm_floor_init(f,v,send,c);}
int uke_camera_floor_vote_check(void *c,u32 k,u32 r,u32 v) {return cam_cc_crm_floor_vote(c,k,r,v);}
int uke_camera_floor_sync_check(struct cam_cc_crm_floor *f) {return cam_cc_crm_floor_sync(f);}
C
printf '%s\n' 'obj-y += owner.o' "ccflags-y += -I$kernel/drivers/clk/qcom" > "$stage/Makefile"
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 M="$stage" KCFLAGS=-Werror -j2 owner.o
for object in "$out/drivers/clk/qcom/camcc-sm7675.o" "$stage/owner.o";do
 llvm-readelf -h "$object" | grep -F AArch64
done
for symbol in uke_camera_owner_bind_check uke_camera_rom_check uke_camera_managed_check uke_camera_startup_check uke_camera_floor_init_check uke_camera_floor_vote_check uke_camera_floor_sync_check uke_camera_native_admit_check uke_camera_native_sync_check uke_camera_native_resume_check;do
 llvm-nm --defined-only "$stage/owner.o" | awk -v symbol="$symbol" '$NF==symbol{found=1}END{exit !found}'
done
grep -aqF firmware-enabled-refused "$out/drivers/clk/qcom/camcc-sm7675.o"
(cd "$kernel";sha256sum -c --strict --quiet "$result/source.sha256" "$result/retained.sha256")
sha256sum "$out/drivers/clk/qcom/camcc-sm7675.o" "$stage/owner.o" > "$result/native-objects.sha256"
[[ $(grep -c '^PASS: camera owner' "$result/owner-results.txt") == 4 && $(grep -c '^PASS: camera startup snapshot' "$result/startup-results.txt") == 4 && $(grep -c '^PASS: camera inherited floors' "$result/floor-results.txt") == 4 && ! -e $out/arch/arm64/boot/Image && ! -e $stage/owner.ko ]]
[[ $(grep -c '^PASS: camera native composition:' "$result/composition-results.txt") == 4 && $(grep -c '^CAMCC CRM callers:' "$result/caller-results.txt") == 4 ]]
jq -n '{schema_version:2,owner_compiler_modes:4,rom_compiler_modes:4,startup_compiler_modes:4,floor_compiler_modes:4,composition_compiler_modes:4,actual_caller_compiler_modes:4,semantic_mutants:7,actual_arm64_objects:2,inherited_AP0_preserved_until_sync:true,all8_IRQ_enable_failures_covered:true,firmware_guard_retained:true,probe_calls_owner:true,probe_calls_rom:true,probe_calls_startup:true,probe_calls_floor:true,primary_CRM_command_map:true,separate_CRMC_ROM_map:true,physical_camera_accepted:false,contains_kernel_image:false}' > "$result/qualification.json"
