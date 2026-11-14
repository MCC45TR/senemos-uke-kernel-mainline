#!/usr/bin/bash
# COPR only: source, linked image and existing-core packaging remain distinct.
set -Eeuo pipefail
[[ ! -e /etc/senemos/kernel-update.conf && ($# == 3 || $# == 4) ]]
kernel=$(realpath "$1")
out=$(realpath -m "$2")
phase=$3
layer=$kernel/native-hardware
contract=$layer/manifests/native-hardware-delivery-20261113.json
work=$kernel/native-generated/native-hardware733
release=$(jq -er .kernel_release "$kernel/native-profile/source-composition.json")
if [[ $phase == source ]];then
 [[ ! -e $work ]]
 mkdir -p "$work/before"
 for item in camcc/camera-crmc-owner-20261113.json ssc/ssc-stream-freshness-20261113.json;do
  packet=${item%%/*};name=${item#*/}
  (cd "$layer/$packet"; jq -r '.source_assets[]|.sha256+"  "+.path' "manifests/$name" | sha256sum -c --strict --quiet -)
 done
 node - "$layer" "$work/units.json" <<'JS'
const fs=require('fs'),[p,o]=process.argv.slice(2),c=JSON.parse(fs.readFileSync(p+'/camcc/manifests/camera-crmc-owner-20261113.json')),s=JSON.parse(fs.readFileSync(p+'/ssc/manifests/ssc-stream-freshness-20261113.json')),m=JSON.parse(fs.readFileSync(p+'/manifests/native-hardware-delivery-20261113.json'));if(c.source_check_release!==108||s.source_check_release!==108||c.runtime_units.length!==16)throw Error('Qualified packet drift');const units=[...c.runtime_units,{path:'drivers/iio/common/uke-ssc/uke-ssc-iio.c',before_sha256:s.driver_before_sha256,after_sha256:s.driver_after_sha256},{path:'arch/arm64/kernel/uke-camcc-dt.h',before_sha256:m.dt_before_sha256,after_sha256:m.dt_after_sha256}];if(new Set(units.map(x=>x.path)).size!==18)throw Error('Duplicate unit');fs.writeFileSync(o,JSON.stringify(units,null,2)+'\n');
JS
 while IFS=$'\t' read -r path digest;do
  [[ $path =~ ^(arch|drivers)/[a-zA-Z0-9_.,/-]+[.](c|h)$ && $path != *..* ]]
  if [[ $digest == absent ]];then [[ ! -e $kernel/$path && ! -L $kernel/$path ]];
  else printf '%s  %s\n' "$digest" "$kernel/$path" | sha256sum -c --strict --quiet -;fi
 done < <(jq -er '.[]|[.path,(.before_sha256//"absent")]|@tsv' "$work/units.json")
 while IFS= read -r path;do install -Dm644 "$kernel/$path" "$work/before/$path";done < <(jq -er '.[]|select(.before_sha256!=null)|.path' "$work/units.json")
 bash "$layer/camcc/src/camera/provider/apply-native-crm733.sh" "$kernel" "$layer/camcc"
 bash "$layer/ssc/src/sensors/apply-stream-freshness733.sh" "$kernel" "$layer/ssc"
 install -m644 "$layer/camcc/src/camera/provider/uke-camcc-dt.h" "$kernel/arch/arm64/kernel/uke-camcc-dt.h"
 jq -r '.[]|.after_sha256+"  "+.path' "$work/units.json" > "$work/after.sha256"
 (cd "$kernel";sha256sum -c --strict --quiet "$work/after.sha256")
 bash "$layer/ssc/tests/ssc-stream-freshness.sh" "$kernel/drivers/iio/common/uke-ssc/uke-ssc-iio.c" "$kernel/include/uapi/linux/iio/types.h"
 CC=clang bash "$layer/camcc/tests/camcc-controller-fdt731-contract.sh"
 # Run every original quaternion assertion against the final publish path,
 # supplying only its declared heading boundary. Keep the sealed profile intact.
 node - "$kernel/native-profile/tests/ssc-quaternion-buffer.sh" "$work/final-quaternion-check.sh" "$contract" <<'JS'
const fs=require('fs'),crypto=require('crypto'),[i,o,c]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(c)),before=fs.readFileSync(i,'utf8'),sha=x=>crypto.createHash('sha256').update(x).digest('hex');if(sha(before)!==m.legacy_quaternion_runner_sha256)throw Error('Original runner drift');const old='"$profile/tests/ssc-quaternion-buffer.c"',next='"$NATIVE_HARDWARE_QUATERNION_FIXTURE"';if(before.split(old).length!==m.legacy_quaternion_runner_fixture_references+1)throw Error('Fixture selector count');const after=before.replaceAll(old,()=>next);if(after.replaceAll(next,()=>old)!==before)throw Error('Unrelated test runner change');fs.writeFileSync(o,after);
JS
 NATIVE_HARDWARE_QUATERNION_FIXTURE="$layer/ssc/tests/ssc-quaternion-buffer.c" bash "$work/final-quaternion-check.sh" "$kernel"
 touch "$work/source-complete"
 printf 'Full native hardware source:18 complete units, preserved full24/s2idle, actual DT/SSC callbacks and exact test-runner inverse pass; no physical acceptance\n'
 exit 0
fi
[[ -f $work/source-complete ]]
(cd "$kernel";sha256sum -c --strict --quiet "$work/after.sha256")
[[ $(cat "$out/include/config/kernel.release") == "$release" ]]
objects=(drivers/clk/qcom/camcc-sm7675.o arch/arm64/kernel/uke-abl.o drivers/iio/common/uke-ssc/uke-ssc-iio.o drivers/iio/common/uke-ssc/uke-ssc-protocol.o)
if [[ $phase == linked ]];then
 [[ ! -e $work/linked.sha256 ]]
 for object in "${objects[@]}";do llvm-readelf -h "$out/$object" | grep -F AArch64;done
 for marker in crmc-map firmware-enabled-refused;do grep -aqF "$marker" "$out/arch/arm64/boot/Image";done
 grep -aqF crmc "$out/arch/arm64/kernel/uke-abl.o"
 grep -Fq uke-camcc-dt.h "$out/arch/arm64/kernel/.uke-abl.o.cmd"
 grep -Fx kernel/drivers/clk/qcom/camcc-sm7675.ko "$out/modules.builtin"
 [[ ! -e $out/drivers/clk/qcom/camcc-sm7675.ko ]]
 llvm-nm --defined-only "$out/drivers/iio/common/uke-ssc/uke-ssc-iio.o" | awk '$NF=="ssc_buffer_enable"{found=1}END{exit !found}'
 [[ $(modinfo -F vermagic "$out/drivers/iio/common/uke-ssc/uke-ssc.ko") == "$release "* ]]
 (cd "$out";sha256sum "${objects[@]}" drivers/iio/common/uke-ssc/uke-ssc.ko arch/arm64/boot/Image vmlinux .config modules.builtin) > "$work/linked.sha256"
 printf 'Actual cumulative native CAMCC/SSC/early-DT objects, builtin Image and module ABI admitted; firmware CRM still refused\n'
 exit 0
fi
[[ -s $work/linked.sha256 ]]
(cd "$out";sha256sum -c --strict --quiet "$work/linked.sha256")
if [[ $phase == sealed ]];then
 printf 'Actual native hardware sources/Image/ELFs unchanged after retained full24 checks\n'
 exit 0
fi
[[ $# == 4 && ($phase == install || $phase == check) ]]
root=$(realpath -m "$4")
identity=$root/usr/share/senemos/uke/$release
module=$root/usr/lib/modules/$release/kernel/drivers/iio/common/uke-ssc/uke-ssc.ko.zst
cmp "$out/arch/arm64/boot/Image" "$root/usr/lib/modules/$release/vmlinuz"
[[ $(modinfo -F vermagic "$module") == "$release "* && -n $(modinfo -F signer "$module") ]]
if [[ $phase == install ]];then
 install -m644 "$work/after.sha256" "$identity/native-hardware-source.sha256"
 install -m644 "$work/linked.sha256" "$identity/native-hardware-linked.sha256"
 install -m644 "$contract" "$identity/native-hardware-delivery.json"
 node - "$identity/native-hardware-full-qualification.json" "$release" "$contract" <<'JS'
const fs=require('fs'),[o,release,f]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(f));fs.writeFileSync(o,JSON.stringify({schema_version:1,kernel_release:release,native_source_build:m.proof.build,native_source_receipt_sha256:m.proof.receipt_sha256,actual_full_image_linked:true,actual_arm64_source_units:18,actual_arm64_objects:4,camcc_builtin:true,source_only_legacy_views:true,objects_never_replaced:true,ssc_streaming_buffer_freshness:true,crm_activation_allowed:false,gravity_frame_admitted:false,physical_camera_accepted:false,physical_sensor_accepted:false,copr_rpm_signatures_verified:false,new_runtime_packages:0},null,2)+'\n');
JS
else
 cmp "$work/after.sha256" "$identity/native-hardware-source.sha256"
 cmp "$work/linked.sha256" "$identity/native-hardware-linked.sha256"
 jq --arg release "$release" -e '.kernel_release==$release and .native_source_build==11318588 and .actual_full_image_linked and .camcc_builtin and (.crm_activation_allowed|not) and (.physical_camera_accepted|not)' "$identity/native-hardware-full-qualification.json" >/dev/null
fi
printf 'Existing core native hardware metadata/%s admitted; source/full/physical scopes remain separate\n' "$phase"
