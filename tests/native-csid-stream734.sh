#!/usr/bin/bash
# COPR only: shared callback with actual gen3 dispatch, not a hardware capture.
set -Eeuo pipefail
[[ $# == 4 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2");owner=$(realpath "$3");result=$(realpath -m "$4")
(cd "$owner/oracle";sha256sum -c --strict --quiet SHA256SUMS)
bash "$owner/src/camera/csid-stream734/apply.sh" "$kernel" "$owner" "$result"
file=drivers/media/platform/qcom/camss/camss-csid.c
gen3=$kernel/drivers/media/platform/qcom/camss/camss-csid-gen3.c
model=$result/model
node "$owner/tests/fixtures/csid-stream734-model.mjs" "$kernel/$file" "$gen3" "$owner/oracle" "$model/after"
node "$owner/tests/fixtures/csid-stream734-model.mjs" "$result/before/$file" "$gen3" "$owner/oracle" "$model/before"
node "$owner/tests/fixtures/csid-stream734-mutants.mjs" "$model/after" "$model"
fixture=$owner/tests/fixtures/csid-stream734-check.c
flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -Wno-unused-parameter)
for compiler in gcc clang;do
 "$compiler" "${flags[@]}" -I"$model/before" "$fixture" -o "$model/before-check"
 set +e
 (ulimit -c 0;timeout --kill-after=2s 20s "$model/before-check") > "$model/before-$compiler.log" 2>&1
 status=$?
 set -e
 [[ $status == 134 ]] && grep -Fq Assertion "$model/before-$compiler.log"
 printf 'Before-control: original CSID skips stop after initial start: %s/status134\n' "$compiler" >> "$result/results.txt"
 "$model/before-check" --entries > "$model/entries-before-$compiler.txt"
 for mode in plain sanitized;do
  sanitize=()
  [[ $mode != sanitized ]] || sanitize=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" "${flags[@]}" "${sanitize[@]}" -I"$model/after" "$fixture" -o "$model/check"
  readelf -h "$model/check" | grep -F AArch64
  timeout --kill-after=2s 20s "$model/check" >> "$result/results.txt"
  "$model/check" --entries > "$model/entries-after-$compiler-$mode.txt"
  cmp "$model/entries-before-$compiler.txt" "$model/entries-after-$compiler-$mode.txt"
 done
done
[[ $(grep -c '^PASS: CSID stream:' "$result/results.txt") == 4 ]]
for mutant in cached-gate start-only duplicate-dispatch discard-control-error bypass-link;do
 gcc "${flags[@]}" -I"$model/$mutant" "$fixture" -o "$model/mutant"
 set +e
 (ulimit -c 0;timeout --kill-after=2s 20s "$model/mutant") > "$model/$mutant.log" 2>&1
 status=$?
 set -e
 [[ $status == 134 ]] && grep -Fq Assertion "$model/$mutant.log"
 printf 'Semantic mutant rejected: %s\n' "$mutant" >> "$result/results.txt"
done
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror -j2 drivers/media/platform/qcom/camss/camss-csid.o drivers/media/platform/qcom/camss/camss-csid-gen3.o
for object in camss-csid.o camss-csid-gen3.o;do
 llvm-readelf -h "$out/drivers/media/platform/qcom/camss/$object" | grep -F AArch64
 sha256sum "$out/drivers/media/platform/qcom/camss/$object" >> "$result/native-objects.sha256"
done
(cd "$kernel";sha256sum -c --strict --quiet "$result/source.sha256")
jq -n '{schema_version:1,compiler_modes:4,original_before_controls:2,repeated_stream_cycles_per_mode:2048,entry_refusal_cases_per_mode:48,semantic_mutants:5,actual_arm64_objects:2,donor_callback_byte_identical:true,actual_gen3_dispatch:true,control_and_link_refusals_retained:true,graph_activated:false,physical_camera_accepted:false}' > "$result/qualification.json"
cat "$result/results.txt"
