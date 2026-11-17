#!/usr/bin/bash
# Source-only COPR gate; do not build an Image or access tablet hardware.
set -Eeuo pipefail
[[ $# == 4 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2");owner=$(realpath "$3");result=$(realpath -m "$4")
[[ ! -e $result && ! -L $result ]]
mkdir "$result"
bash "$owner/src/camera/icc-hf734/apply.sh" "$kernel" "$owner" "$result/fixed"
before=$result/fixed/before/drivers/interconnect/qcom/icc-rpmh.c
after=$kernel/drivers/interconnect/qcom/icc-rpmh.c
printf '%s  %s\n' 177b6dc3f59862089099f8ff83015157400d023893b5616aadd6b55fbe7dca10 "$kernel/drivers/interconnect/core.c" | sha256sum -c --strict --quiet -
for compiler in gcc clang;do
 for mode in plain sanitized;do
  flags=''
  [[ $mode != sanitized ]] || flags='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer'
  CC=$compiler ICC_HF_FLAGS="$flags" bash "$owner/tests/camera-icc-hf734-contract.sh" "$kernel" "$after" "$owner" >> "$result/results.txt"
 done
 for version in before after;do
  source=$after
  [[ $version != before ]] || source=$before
  CC=$compiler ICC_HF_FLAGS=-DICC_LEGACY_TRACE bash "$owner/tests/camera-icc-hf734-contract.sh" "$kernel" "$source" "$owner" > "$result/legacy-$compiler-$version.txt"
 done
 cmp "$result/legacy-$compiler-before.txt" "$result/legacy-$compiler-after.txt"
 [[ $(wc -l < "$result/legacy-$compiler-after.txt") == 9 ]]
 set +e
 CC=$compiler ICC_HF_FLAGS='' bash "$owner/tests/camera-icc-hf734-contract.sh" "$kernel" "$before" "$owner" > "$result/before-$compiler.log" 2>&1
 status=$?
 set -e
 [[ $status == 134 ]]
 grep -Fq 'CONFIGURE(&qp)==-EIO' "$result/before-$compiler.log"
 printf 'Original ignored register error detected: %s/status134.\n' "$compiler" >> "$result/results.txt"
done
mkdir "$result/mutants"
node - "$after" "$result/mutants" <<'JS'
const fs=require('fs'),a=require('assert/strict'),s=fs.readFileSync(process.argv[2],'utf8'),dir=process.argv[3];
const cases=[
 ['vote-return','return qcom_icc_bcm_voter_commit(qp->voter);','qcom_icc_bcm_voter_commit(qp->voter); return 0;'],
 ['barrier','if (sync_initial_votes) {','if (sync_initial_votes && false) {'],
 ['aux-cache','addr = cmd_db_read_addr(bcm->name);','bcm->addr = addr = cmd_db_read_addr(bcm->name);'],
 ['qos-return','return ret;\n\n\t\tret = regmap_update_bits(qp->regmap, QOSGEN_MAINCTL_LO(qos, port),\n\t\t\t\t   QOS_DFLT_PRIO_MASK,','ret = 0;\n\n\t\tret = regmap_update_bits(qp->regmap, QOSGEN_MAINCTL_LO(qos, port),\n\t\t\t\t   QOS_DFLT_PRIO_MASK,']
];
for(const [name,from,to] of cases){a.equal(s.split(from).length,2);fs.writeFileSync(dir+'/'+name+'.c',s.replace(from,to));}
JS
for mutant in vote-return barrier aux-cache qos-return;do
 set +e
 CC=clang ICC_HF_FLAGS='' bash "$owner/tests/camera-icc-hf734-contract.sh" "$kernel" "$result/mutants/$mutant.c" "$owner" > "$result/mutants/$mutant.log" 2>&1
 status=$?
 set -e
 [[ $status == 134 ]]
 printf 'Actual ICC callback mutant detected: %s/status134.\n' "$mutant" >> "$result/results.txt"
done
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror -j2 \
 drivers/interconnect/qcom/icc-rpmh.o drivers/interconnect/qcom/qnoc-cliffs-usb.o
for object in icc-rpmh qnoc-cliffs-usb;do
 llvm-readelf -h "$out/drivers/interconnect/qcom/$object.o" | grep -F AArch64
done
(cd "$out";sha256sum drivers/interconnect/qcom/{icc-rpmh,qnoc-cliffs-usb}.o) > "$result/native-objects.sha256"
(cd "$kernel";sha256sum drivers/interconnect/qcom/{icc-rpmh.c,cliffs-display-icc.h}) > "$result/source.sha256"
[[ $(grep -c '^Camera HF ICC:' "$result/results.txt") == 4 ]]
jq -n '{schema_version:1,compiler_modes:4,register_faults_per_mode:15,shared_video_idle_cycles_per_mode:256,original_failure_controls:2,callback_mutants:4,legacy_qos_traces:2,legacy_register_updates_per_trace:9,actual_arm64_objects:2,actual_initial_node_callback:true,hardware_modeled:true,physical_camera_accepted:false}' > "$result/qualification.json"
cat "$result/results.txt"
