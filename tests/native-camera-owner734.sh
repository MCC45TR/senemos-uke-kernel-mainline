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
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror -j2 drivers/clk/qcom/camcc-sm7675.o
stage=$out/camera-owner734-adapter
[[ ! -e $stage ]]
mkdir "$stage"
cat > "$stage/owner.c" <<'C'
// SPDX-License-Identifier: GPL-2.0-only
#define UKE_CAMCC_OBJECT_TEST
#include "camcc-sm7675.c"
#include "provider/camcc-sm7675-crm-startup.h"
int uke_camera_owner_bind_check(void);
int uke_camera_rom_check(u32,cam_cc_crm_lut_read_fn,void *,struct cam_cc_crm_lut *);
int uke_camera_managed_check(struct cam_cc_crm_clock *);
int uke_camera_startup_check(const struct cam_cc_crm_caps *,const struct cam_cc_crm_lut *,cam_cc_crm_lut_read_fn,void *,struct cam_cc_crm_startup *);
int uke_camera_owner_bind_check(void) {return cam_cc_crm_owner_transport_bind();}
int uke_camera_rom_check(u32 client,cam_cc_crm_lut_read_fn read,void *context,struct cam_cc_crm_lut *table)
{return cam_cc_crm_rom_load(client,read,context,table);}
int uke_camera_managed_check(struct cam_cc_crm_clock *clients) {return cam_cc_crm_managed_attach(clients);}
int uke_camera_startup_check(const struct cam_cc_crm_caps *caps,const struct cam_cc_crm_lut *tables,cam_cc_crm_lut_read_fn read,void *context,struct cam_cc_crm_startup *out)
{return cam_cc_crm_startup_read(caps,tables,0x2000,read,context,out);}
C
printf '%s\n' 'obj-y += owner.o' "ccflags-y += -I$kernel/drivers/clk/qcom" > "$stage/Makefile"
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 M="$stage" KCFLAGS=-Werror -j2 owner.o
for object in "$out/drivers/clk/qcom/camcc-sm7675.o" "$stage/owner.o";do
 llvm-readelf -h "$object" | grep -F AArch64
done
for symbol in uke_camera_owner_bind_check uke_camera_rom_check uke_camera_managed_check uke_camera_startup_check;do
 llvm-nm --defined-only "$stage/owner.o" | awk -v symbol="$symbol" '$NF==symbol{found=1}END{exit !found}'
done
grep -aqF firmware-enabled-refused "$out/drivers/clk/qcom/camcc-sm7675.o"
(cd "$kernel";sha256sum -c --strict --quiet "$result/source.sha256" "$result/retained.sha256")
sha256sum "$out/drivers/clk/qcom/camcc-sm7675.o" "$stage/owner.o" > "$result/native-objects.sha256"
[[ $(grep -c '^PASS: camera owner' "$result/owner-results.txt") == 4 && $(grep -c '^PASS: camera startup snapshot' "$result/startup-results.txt") == 4 && ! -e $out/arch/arm64/boot/Image && ! -e $stage/owner.ko ]]
jq -n '{schema_version:1,owner_compiler_modes:4,rom_compiler_modes:4,startup_compiler_modes:4,semantic_mutants:4,actual_arm64_objects:2,inherited_AP0_preserved:true,all8_IRQ_enable_failures_covered:true,firmware_guard_retained:true,probe_calls_owner:false,probe_calls_rom:false,probe_calls_startup:false,physical_camera_accepted:false,contains_kernel_image:false}' > "$result/qualification.json"
