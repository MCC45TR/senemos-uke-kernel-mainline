#!/usr/bin/bash
# COPR only: actual VFE callbacks and real ARM64 object, no hardware activation.
set -Eeuo pipefail
[[ $# == 4 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2");owner=$(realpath "$3");result=$(realpath -m "$4")
(cd "$owner/oracle";sha256sum -c --strict --quiet SHA256SUMS)
bash "$owner/src/camera/camss-lite734/apply.sh" "$kernel" "$owner" "$result"
file=drivers/media/platform/qcom/camss/camss-vfe-gen3.c
model=$result/model
node "$owner/tests/fixtures/camss-lite734-model.mjs" "$kernel/$file" "$owner/oracle" "$model/after"
node "$owner/tests/fixtures/camss-lite734-model.mjs" "$result/before/$file" "$owner/oracle" "$model/before"
fixture=$owner/tests/fixtures/camss-lite734-check.c
flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -Wno-unused-parameter)
for compiler in gcc clang;do
 "$compiler" "${flags[@]}" -I"$model/before" "$fixture" -o "$model/before-check"
 set +e
 (ulimit -c 0;timeout --kill-after=2s 20s "$model/before-check") > "$model/before-$compiler.log" 2>&1
 status=$?
 set -e
 [[ $status == 134 ]] && grep -Fq Assertion "$model/before-$compiler.log"
 printf 'Before-control: original SM7675 lite MMIO trace fails the OEM register oracle: %s/status134\n' "$compiler" >> "$result/results.txt"
 "$model/before-check" --legacy > "$model/legacy-before-$compiler.txt"
 for mode in plain sanitized;do
  sanitize=()
  [[ $mode != sanitized ]] || sanitize=("-fsanitize=address,undefined" -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" "${flags[@]}" "${sanitize[@]}" -I"$model/after" "$fixture" -o "$model/check"
  readelf -h "$model/check" | grep -F AArch64
  timeout --kill-after=2s 20s "$model/check" >> "$result/results.txt"
  "$model/check" --legacy > "$model/legacy-after-$compiler-$mode.txt"
  cmp "$model/legacy-before-$compiler.txt" "$model/legacy-after-$compiler-$mode.txt"
 done
done
[[ $(grep -c '^PASS: CAMSS SM7675 lite:' "$result/results.txt") == 4 ]]
node - "$model/after" "$model" <<'JS'
const fs=require('fs'),a=require('assert/strict'),[source,out]=process.argv.slice(2),s=fs.readFileSync(source+'/actual-vfe-functions.h','utf8');
for(const [name,before,after]of [
 ['wrong-testbus','(BUS_REG_BASE + 0x194)','(BUS_REG_BASE + 0xDC)'],
 ['unsupported-framedrop','if (!IS_VFE_860_LITE(vfe)) {','if (1) {'],
 ['foreign-lite','vfe->camss->res->version == CAMSS_7675 && vfe_is_lite(vfe)','vfe_is_lite(vfe)']
]){a.equal(s.split(before).length,2);fs.mkdirSync(out+'/'+name);fs.writeFileSync(out+'/'+name+'/actual-vfe-functions.h',s.replace(before,after));fs.copyFileSync(source+'/actual-oem-oracle.h',out+'/'+name+'/actual-oem-oracle.h');}
JS
for mutant in wrong-testbus unsupported-framedrop foreign-lite;do
 gcc "${flags[@]}" -I"$model/$mutant" "$fixture" -o "$model/mutant"
 if [[ $mutant == foreign-lite ]];then
  "$model/mutant" --legacy > "$model/foreign-lite-trace.txt"
  if cmp -s "$model/legacy-before-gcc.txt" "$model/foreign-lite-trace.txt";then exit 1;fi
 else
  set +e
  (ulimit -c 0;timeout --kill-after=2s 20s "$model/mutant") > "$model/$mutant.log" 2>&1
  status=$?
  set -e
  [[ $status == 134 ]] && grep -Fq Assertion "$model/$mutant.log"
 fi
 printf 'Semantic mutant rejected: %s\n' "$mutant" >> "$result/results.txt"
done
grep -Fx CONFIG_VIDEO_QCOM_CAMSS=m "$out/.config"
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror -j2 drivers/media/platform/qcom/camss/camss-vfe-gen3.o
object=$out/drivers/media/platform/qcom/camss/camss-vfe-gen3.o
llvm-readelf -h "$object" | grep -F AArch64
llvm-nm --defined-only "$object" | awk '$NF=="vfe_ops_gen3"{found=1}END{exit !found}'
sha256sum "$object" > "$result/native-objects.sha256"
(cd "$kernel";sha256sum -c --strict --quiet "$result/source.sha256")
jq -n '{schema_version:1,compiler_modes:4,original_before_controls:2,semantic_mutants:3,sm7675_lite_trace_cases_per_mode:72,legacy_trace_cases_per_mode:31,actual_arm64_objects:1,independent_oem_tables:true,same_soc_oracle_byte_identical:true,all_legacy_traces_unchanged:true,unsupported_lite_framedrop_writes_absent:true,graph_activated:false,physical_camera_accepted:false}' > "$result/qualification.json"
cat "$result/results.txt"
