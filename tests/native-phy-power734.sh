#!/usr/bin/bash
# COPR only: production PHY transitions, legacy traces and real ARM64 objects.
set -Eeuo pipefail
[[ $# == 4 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2");owner=$(realpath "$3");result=$(realpath -m "$4")
bash "$owner/src/camera/phy-power734/apply.sh" "$kernel" "$owner" "$result"
model=$result/model
node "$owner/tests/fixtures/phy-power734-model.mjs" "$result/before" "$owner" "$model/before"
node "$owner/tests/fixtures/phy-power734-model.mjs" "$kernel" "$owner" "$model/after"
fixture=$owner/tests/fixtures/phy-power734-check.c
flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -Wno-unused-function -Wno-unused-parameter -Wno-misleading-indentation)
for compiler in gcc clang;do
 "$compiler" "${flags[@]}" -I"$model/before" "$fixture" -o "$model/before-check"
 set +e
 (ulimit -c 0;timeout --kill-after=2s 20s "$model/before-check" --before) > "$model/before-$compiler.log" 2>&1
 status=$?
 set -e
 [[ $status == 134 ]] && grep -Fq Assertion "$model/before-$compiler.log"
 printf 'Before-control: original PHY enables shared supplies without a consumer voltage request: %s/status134\n' "$compiler" >> "$result/results.txt"
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
[[ $(grep -c '^PASS: PHY power:' "$result/results.txt") == 4 ]]
node - "$model/after" "$model" <<'JS'
const fs=require('fs'),a=require('assert/strict'),[source,out]=process.argv.slice(2);
for(const [name,file,before,after]of [
 ['wide-voltage','actual-power.h','csiphy->res->voltage[i].max_uV','INT_MAX'],
 ['early-release','actual-power.h','ret = regulator_disable(power->supplies[i].consumer);','ret = regulator_set_voltage(power->supplies[i].consumer, 0, INT_MAX);'],
 ['discard-fault','actual-power.h','if (power->fault || power->active || power->voted || power->enabled ||\n\t    power->pm_held || power->clocks || power->irq)','if (false)'],
 ['sync-deadlock','actual-status.h','if (!READ_ONCE(cam_cc_native.ready))','if (!READ_ONCE(cam_cc_native.synchronized))'],
 ['legacy-dispatch','actual-dispatch.h','csiphy->camss->res->version == CAMSS_7675','1']
]){fs.mkdirSync(out+'/'+name);for(const f of fs.readdirSync(source))fs.copyFileSync(source+'/'+f,out+'/'+name+'/'+f);const p=out+'/'+name+'/'+file,s=fs.readFileSync(p,'utf8');a.equal(s.split(before).length,2,name);fs.writeFileSync(p,s.replace(before,after));}
JS
for mutant in wide-voltage early-release discard-fault sync-deadlock legacy-dispatch;do
 gcc "${flags[@]}" -I"$model/$mutant" "$fixture" -o "$model/mutant"
 if [[ $mutant == legacy-dispatch ]];then
  "$model/mutant" --legacy > "$model/mutant-legacy.txt"
  if cmp -s "$model/legacy-before-gcc.txt" "$model/mutant-legacy.txt";then exit 1;fi
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
grep -Fx CONFIG_SM_CAMCC_7675=y "$out/.config"
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror -j2 drivers/media/platform/qcom/camss/camss.o drivers/media/platform/qcom/camss/camss-csiphy.o drivers/clk/qcom/camcc-sm7675.o
for object in drivers/media/platform/qcom/camss/camss.o drivers/media/platform/qcom/camss/camss-csiphy.o drivers/clk/qcom/camcc-sm7675.o;do
 llvm-readelf -h "$out/$object" | grep -F AArch64
 sha256sum "$out/$object" >> "$result/native-objects.sha256"
done
llvm-nm --defined-only "$out/drivers/clk/qcom/camcc-sm7675.o" | awk '$NF=="qcom_sm7675_camcc_status"{found=1}END{exit !found}'
(cd "$kernel";sha256sum -c --strict --quiet "$result/source.sha256")
jq -n '{schema_version:1,compiler_modes:4,original_before_controls:2,semantic_mutants:5,legacy_traces_per_mode:15,actual_arm64_objects:3,shared_supply_votes_demand_based:true,provider_status_cached_only:true,static_builtin_owner_required:true,source_check_camss_linkage:"module; SM7675 admission must refuse it",runtime_camss_builtin_qualification_pending:true,graph_activated:false,physical_camera_accepted:false}' > "$result/qualification.json"
cat "$result/results.txt"
