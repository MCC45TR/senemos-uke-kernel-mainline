#!/usr/bin/bash
# COPR only: qualify the actual late entry and build its real ARM64 caller.
set -Eeuo pipefail
[[ $# == 4 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2");owner=$(realpath "$3");result=$(realpath -m "$4")
[[ ! -e $result && ! -L $result ]]
mkdir "$result"
bash "$owner/src/camera/front-eeprom734/apply.sh" "$kernel" "$owner" "$result/early9"
bash "$owner/src/camera/front-stage734/apply.sh" "$kernel" "$owner" "$result/fixed"
before=$result/fixed/before/arch/arm64/kernel/uke-abl.c
after=$kernel/arch/arm64/kernel/uke-abl.c
node - "$after" "$kernel/arch/arm64/kernel/uke-abl-native.h" <<'JS'
const fs=require('fs'),a=require('assert/strict'),s=fs.readFileSync(process.argv[2],'utf8'),n=fs.readFileSync(process.argv[3],'utf8');
a(!s.includes('uke_front_eeprom_graph(output)'));
a.equal(s.split('ret = uke_front_eeprom_graph(uke_fdt);').length,2);
const select=s.indexOf('ret = uke_abl_native_select(uke_fdt,'),front=s.indexOf('ret = uke_front_eeprom_graph(uke_fdt);');
a(select>0&&front>select&&s.indexOf('ret = uke_audio_config_graph(uke_fdt);')>front);
a(s.slice(select,front).includes('fdt_open_into(uke_fdt, uke_fdt, sizeof(uke_fdt))'));
a(n.indexOf('ret = uke_bwmon_apply(fdt);')<n.indexOf('ret = uke_cpu_bwmon_apply(fdt);'));
a(n.indexOf('ret = uke_cpu_bwmon_apply(fdt);')<n.indexOf('ret && ret != -FDT_ERR_NOTFOUND ? ret : fdt_pack(fdt)'));
JS
for compiler in gcc clang;do
 for mode in plain sanitized;do
  flags=-DCONFIG_SM_CAMCC_7675=1
  [[ $mode != sanitized ]] || flags+=' -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer'
  CC=$compiler FRONT_STAGE_FLAGS="$flags" bash "$owner/tests/front-stage734-contract.sh" "$kernel" "$after" "$owner" >> "$result/results.txt"
 done
 CC=$compiler FRONT_STAGE_FLAGS='' bash "$owner/tests/front-stage734-contract.sh" "$kernel" "$after" "$owner" >> "$result/disabled-results.txt"
 set +e
 CC=$compiler FRONT_STAGE_FLAGS=-DCONFIG_SM_CAMCC_7675=1 bash "$owner/tests/front-stage734-contract.sh" "$kernel" "$before" "$owner" > "$result/before-$compiler.log" 2>&1
 status=$?
 set -e
 [[ $status == 134 ]]
 grep -Fq 'setjmp(refusal)' "$result/before-$compiler.log"
 printf 'Original early front gate refuses pre-native ICC graph: %s/status134.\n' "$compiler" >> "$result/results.txt"
done
mkdir "$result/mutants"
node - "$after" "$result/mutants" <<'JS'
const fs=require('fs'),a=require('assert/strict'),s=fs.readFileSync(process.argv[2],'utf8'),dir=process.argv[3];
const capacity='\t\t\tret = fdt_open_into(uke_fdt, uke_fdt, sizeof(uke_fdt));\n#ifdef CONFIG_SM_CAMCC_7675';
const guard='#ifdef CONFIG_SM_CAMCC_7675\n\t\t\t/* Native ICC tags must exist before the read-only front gate. */\n\t\t\tif (!ret)\n\t\t\t\tret = uke_front_eeprom_graph(uke_fdt);\n#endif';
for(const [name,from,to] of [['capacity',capacity,'\t\t\tret = 0;\n#ifdef CONFIG_SM_CAMCC_7675'],['ignored-error','ret = uke_front_eeprom_graph(uke_fdt);','(void)uke_front_eeprom_graph(uke_fdt);'],['guard',guard,guard.split('\n').slice(1,-1).join('\n')]]){
 a.equal(s.split(from).length,2);fs.writeFileSync(dir+'/'+name+'.c',s.replace(from,to));
}
JS
for mutant in capacity ignored-error guard;do
 flags=-DCONFIG_SM_CAMCC_7675=1
 [[ $mutant != guard ]] || flags=''
 set +e
 CC=clang FRONT_STAGE_FLAGS="$flags" bash "$owner/tests/front-stage734-contract.sh" "$kernel" "$result/mutants/$mutant.c" "$owner" > "$result/mutants/$mutant.log" 2>&1
 status=$?
 set -e
 [[ $status == 134 ]]
 printf 'Actual entry mutant detected: %s/status134.\n' "$mutant" >> "$result/results.txt"
done
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror -j2 arch/arm64/kernel/uke-abl.o
llvm-readelf -h "$out/arch/arm64/kernel/uke-abl.o" | grep -F AArch64
grep -aqF uke-front-calibration "$out/arch/arm64/kernel/uke-abl.o"
(cd "$out";sha256sum arch/arm64/kernel/uke-abl.o) > "$result/native-objects.sha256"
(cd "$kernel";sha256sum arch/arm64/kernel/{uke-abl.c,uke-front-eeprom-dt.h,uke-bwmon.h,uke-abl-native.h}) > "$result/source.sha256"
[[ $(grep -c '^Front stage:' "$result/results.txt") == 4 && $(grep -c '^Front stage:' "$result/disabled-results.txt") == 2 ]]
jq -n '{schema_version:1,compiler_modes:4,disabled_controller_modes:2,original_failure_controls:2,entry_mutants:3,actual_arm64_objects:1,real_interconnect_tag_converter:true,readonly_helper_unchanged:true,synthetic_graph_only:true,physical_camera_accepted:false}' > "$result/qualification.json"
cat "$result/results.txt"
