#!/usr/bin/bash
# COPR only: actual reset/ISR, modeled IRQ delivery and real ARM64 object.
set -Eeuo pipefail
[[ $# == 4 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2");owner=$(realpath "$3");result=$(realpath -m "$4")
(cd "$owner/oracle";sha256sum -c --strict --quiet SHA256SUMS)
bash "$owner/src/camera/csid-irq734/apply.sh" "$kernel" "$owner" "$result"
file=drivers/media/platform/qcom/camss/camss-csid-gen3.c
model=$result/model
node "$owner/tests/fixtures/csid-irq734-model.mjs" "$kernel/$file" "$owner/oracle" "$model/after"
node "$owner/tests/fixtures/csid-irq734-model.mjs" "$result/before/$file" "$owner/oracle" "$model/before"
node "$owner/tests/fixtures/csid-irq734-mutants.mjs" "$model/after" "$model"
fixture=$owner/tests/fixtures/csid-irq734-check.c
flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -Wno-unused-parameter -Wno-unused-function)
for compiler in gcc clang;do
 "$compiler" "${flags[@]}" -I"$model/before" "$fixture" -o "$model/before-check"
 set +e
 (ulimit -c 0;timeout --kill-after=2s 20s "$model/before-check") > "$model/before-$compiler.log" 2>&1
 status=$?
 set -e
 [[ $status == 134 ]] && grep -Fq Assertion "$model/before-$compiler.log"
 printf 'Before-control: original SM7675 reset does not admit the OEM completion IRQs: %s/status134\n' "$compiler" >> "$result/results.txt"
 "$model/before-check" --legacy > "$model/legacy-before-$compiler.txt"
 for mode in plain sanitized;do
  sanitize=()
  [[ $mode != sanitized ]] || sanitize=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" "${flags[@]}" "${sanitize[@]}" -I"$model/after" "$fixture" -o "$model/check"
  readelf -h "$model/check" | grep -F AArch64
  timeout --kill-after=2s 20s "$model/check" >> "$result/results.txt"
  "$model/check" --legacy > "$model/legacy-after-$compiler-$mode.txt"
  cmp "$model/legacy-before-$compiler.txt" "$model/legacy-after-$compiler-$mode.txt"
 done
done
[[ $(grep -c '^PASS: CSID IRQ:' "$result/results.txt") == 4 ]]
for mutant in wrong-top-buffer missing-rup-mask overwrite-buffer-mask missing-top-rdi legacy-dispatch;do
 gcc "${flags[@]}" -I"$model/$mutant" "$fixture" -o "$model/mutant"
 if [[ $mutant == legacy-dispatch ]];then
  set +e
  (ulimit -c 0;timeout --kill-after=2s 20s "$model/mutant" --legacy) > "$model/mutant-legacy.txt" 2>&1
  status=$?
  set -e
  if [[ $status == 0 ]];then
   if cmp -s "$model/legacy-before-gcc.txt" "$model/mutant-legacy.txt";then exit 1;fi
  else
   [[ $status == 134 ]] && grep -Fq Assertion "$model/mutant-legacy.txt"
  fi
 else
  set +e
  (ulimit -c 0;timeout --kill-after=2s 20s "$model/mutant") > "$model/$mutant.log" 2>&1
  status=$?
  set -e
  [[ $status == 134 ]] && grep -Fq Assertion "$model/$mutant.log"
 fi
 printf 'Semantic mutant rejected: %s\n' "$mutant" >> "$result/results.txt"
done
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror -j2 drivers/media/platform/qcom/camss/camss-csid-gen3.o
object=$out/drivers/media/platform/qcom/camss/camss-csid-gen3.o
llvm-readelf -h "$object" | grep -F AArch64
llvm-nm --defined-only "$object" | awk '$NF=="csid_ops_gen3"{found=1}END{exit !found}'
sha256sum "$object" > "$result/native-objects.sha256"
(cd "$kernel";sha256sum -c --strict --quiet "$result/source.sha256")
jq -n '{schema_version:1,compiler_modes:4,original_before_controls:2,reset_timeout_cases_per_mode:48,frame_rup_cases_per_mode:1152,invalid_path_refusals_per_mode:488,legacy_trace_cases_per_mode:96,semantic_mutants:5,actual_arm64_objects:1,oem_register_oracle:true,same_soc_relevant_fields_equal:true,all_legacy_traces_unchanged:true,graph_activated:false,physical_camera_accepted:false}' > "$result/qualification.json"
cat "$result/results.txt"
