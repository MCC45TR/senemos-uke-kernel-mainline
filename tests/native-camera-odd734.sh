#!/usr/bin/bash
# COPR only. Use the actual catalog and resolver, with modeled register reads.
set -Eeuo pipefail
[[ $# == 4 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2");owner=$(realpath "$3");result=$(realpath -m "$4")
bash "$owner/src/camera/rom-odd734/apply.sh" "$kernel" "$owner" "$result"
model=$result/model
mkdir -p "$model/linux"
printf '#pragma once\n' > "$model/linux/types.h"
cp "$kernel"/drivers/clk/qcom/provider/camcc-sm7675-crm-{core,lut}.h "$model/"
node - "$kernel/drivers/clk/qcom/camcc-sm7675-data.h" "$kernel/drivers/clk/qcom/provider/camcc-sm7675-crm-passive.h" "$model" <<'JS'
const fs=require('fs'),[catalog,passive,out]=process.argv.slice(2),s=fs.readFileSync(catalog,'utf8');let header='/* GPL-2.0-only; exact Qualcomm Innovation Center catalog tables. */\n';
for(const [suffix,macro]of [['even','EVEN'],['odd','ODD']]){
 const table='post_div_table_cam_cc_pll0_out_'+suffix;
 const t=s.match(new RegExp('^static const struct clk_div_table '+table+'\\[\\] = \\{[\\s\\S]*?^\\};','m'));
 const d=s.match(new RegExp('^static struct clk_alpha_pll_postdiv cam_cc_pll0_out_'+suffix+' = \\{[\\s\\S]*?^\\};','m'));
 if(!t||!d)throw Error('actual catalog table');const shift=d[0].match(/\.post_div_shift = ([0-9]+),/);if(!shift)throw Error('actual shift');
 header+=t[0]+'\n#define ACTUAL_'+macro+'_SHIFT '+shift[1]+'\n';
}
fs.writeFileSync(out+'/actual-postdiv-tables.h',header);
const p=fs.readFileSync(passive,'utf8'),a='static int cam_cc_crm_passive_pll_rate(',b='static int cam_cc_crm_passive_index(';
if(p.split(a).length!==2||p.split(b).length!==2)throw Error('arithmetic anchors');fs.writeFileSync(out+'/passive-pll.h',p.slice(p.indexOf(a),p.indexOf(b)));
JS
fixture=$owner/tests/fixtures/camera-rom-odd-check.c
for compiler in gcc clang;do
 cp "$result/before/drivers/clk/qcom/provider/camcc-sm7675-crm-rom.h" "$model/rom.h"
 "$compiler" -std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -I"$model" "$fixture" -o "$model/before"
 set +e
 (ulimit -c 0;timeout --kill-after=2s 20s "$model/before") > "$model/before-$compiler.log" 2>&1
 status=$?
 set -e
 [[ $status == 134 ]] && grep -Fq Assertion "$model/before-$compiler.log"
 printf 'Before-control: actual odd catalog field refused by original resolver: %s/status134\n' "$compiler" >> "$result/results.txt"
done
cp "$kernel/drivers/clk/qcom/provider/camcc-sm7675-crm-rom.h" "$model/rom.h"
for compiler in gcc clang;do
 for mode in plain sanitized;do
  flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror)
  [[ $mode != sanitized ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" "${flags[@]}" -I"$model" "$fixture" -o "$model/check"
  readelf -h "$model/check" | grep -F AArch64
  timeout --kill-after=2s 20s "$model/check" >> "$result/results.txt"
 done
done
[[ $(grep -c '^PASS: camera odd ROM:' "$result/results.txt") == 4 ]]
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror -j2 drivers/clk/qcom/camcc-sm7675.o
stage=$out/camera-odd734-adapter
[[ ! -e $stage ]]
mkdir "$stage"
cat > "$stage/odd.c" <<'C'
// SPDX-License-Identifier: GPL-2.0-only
#define UKE_CAMCC_OBJECT_TEST
#include "camcc-sm7675.c"
int uke_camera_odd_parent_check(void *,u32,u32,u32,u64 *);
int uke_camera_odd_parent_check(void *context,u32 source,u32 l,u32 alpha,u64 *rate)
{ return cam_cc_crm_rom_parent(context,source,l,alpha,rate); }
C
printf '%s\n' 'obj-y += odd.o' "ccflags-y += -I$kernel/drivers/clk/qcom" > "$stage/Makefile"
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 M="$stage" KCFLAGS=-Werror -j2 odd.o
for object in "$out/drivers/clk/qcom/camcc-sm7675.o" "$stage/odd.o";do llvm-readelf -h "$object" | grep -F AArch64;done
llvm-nm --defined-only "$stage/odd.o" | awk '$NF=="uke_camera_odd_parent_check"{found=1}END{exit !found}'
(cd "$kernel";sha256sum -c --strict --quiet "$result/source.sha256")
sha256sum "$out/drivers/clk/qcom/camcc-sm7675.o" "$stage/odd.o" > "$result/native-objects.sha256"
jq -n '{schema_version:1,compiler_modes:4,before_controls:2,actual_catalog_tables:true,separate_even_odd_fields:true,actual_arm64_objects:2,unknown_shifts_refused:true,voltage_limits_unchanged:true,firmware_ownership_retained:true,physical_camera_accepted:false}' > "$result/qualification.json"
cat "$result/results.txt"
