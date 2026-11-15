#!/usr/bin/bash
# Add a qualified diagnostic after the complete full25 source stage.
set -Eeuo pipefail
[[ ! -e /etc/senemos/kernel-update.conf && ($# == 3 || $# == 4) ]]
kernel=$(realpath "$1")
out=$(realpath -m "$2")
phase=$3
layer=$kernel/ssc-time-reference-full
contract=$layer/manifests/ssc-time-reference-delivery-20261113.json
work=$kernel/native-generated/ssc-time-reference733
parent=$kernel/native-generated/native-hardware733
release=$(jq -er .kernel_release "$kernel/native-profile/source-composition.json")
driver=drivers/iio/common/uke-ssc/uke-ssc-iio.c
if [[ $phase == source ]];then
 [[ ! -e $work && -f $parent/source-complete ]]
 printf '%s  %s\n' "$(jq -er .parent_native_hardware_source_manifest_sha256 "$contract")" "$parent/after.sha256" | sha256sum -c --strict --quiet -
 (cd "$kernel";sha256sum -c --strict --quiet "$parent/after.sha256")
 mkdir "$work"
 cp "$parent/after.sha256" "$work/parent-source.sha256"
 cp "$parent/units.json" "$work/parent-units.json"
 bash "$layer/src/sensors/apply-time-reference733.sh" "$kernel" "$layer"
 bash "$layer/tests/ssc-time-reference.sh" "$kernel/$driver"
 # Carry the declared final postimage into the generated cumulative manifest.
 # Frozen source packets and their signed native108 evidence remain unchanged.
 node - "$parent" "$work" "$layer" <<'JS'
const fs=require('fs'),assert=require('assert/strict'),[p,w,l]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(l+'/manifests/ssc-time-reference-20261113.json')),before=fs.readFileSync(w+'/parent-source.sha256','utf8'),path='drivers/iio/common/uke-ssc/uke-ssc-iio.c',old=m.driver_before_sha256+'  '+path+'\n',next=m.driver_after_sha256+'  '+path+'\n';assert.equal(before.split(old).length,2);const after=before.replace(old,()=>next);assert.equal(after.replace(next,()=>old),before);const units=JSON.parse(fs.readFileSync(w+'/parent-units.json')),u=units.filter(x=>x.path===path);assert.equal(units.length,18);assert.equal(u.length,1);assert.equal(u[0].after_sha256,m.driver_before_sha256);u[0].after_sha256=m.driver_after_sha256;const inverse=structuredClone(units);inverse.find(x=>x.path===path).after_sha256=m.driver_before_sha256;assert.deepEqual(inverse,JSON.parse(fs.readFileSync(w+'/parent-units.json')));fs.writeFileSync(p+'/after.sha256',after);fs.writeFileSync(p+'/units.json',JSON.stringify(units,null,2)+'\n');
JS
 (cd "$kernel";sha256sum -c --strict --quiet "$parent/after.sha256")
 sha256sum "$kernel/$driver" | sed "s|$kernel/||" > "$work/final-source.sha256"
 touch "$work/source-complete"
 printf 'Full SSC time-reference source:exact post25 patch/inverse,all callback modes,18-unit final manifest with one declared postimage;no operational callback or frozen packet changed\n'
 exit 0
fi
[[ -f $work/source-complete ]]
(cd "$kernel";sha256sum -c --strict --quiet "$work/final-source.sha256")
[[ $(cat "$out/include/config/kernel.release") == "$release" ]]
if [[ $phase == linked ]];then
 [[ ! -e $work/linked.sha256 ]]
 object=$out/drivers/iio/common/uke-ssc/uke-ssc-iio.o
 llvm-readelf -h "$object" | grep -F AArch64
 llvm-nm --defined-only "$object" | grep -E ' [tT] ssc_time_reference_show$'
 llvm-nm --undefined-only "$object" | grep -F arch_timer_read_counter
 if llvm-nm --undefined-only "$object" | grep -F arch_timer_get_rate;then exit 1;fi
 grep -aqF 'schema=1 admitted=0 generation=' "$object"
 grep -aqF 'schema=1 admitted=0 generation=' "$out/drivers/iio/common/uke-ssc/uke-ssc.ko"
 (cd "$out";sha256sum drivers/iio/common/uke-ssc/uke-ssc-iio.o drivers/iio/common/uke-ssc/uke-ssc.ko arch/arm64/boot/Image vmlinux .config) > "$work/linked.sha256"
 printf 'Full SSC time-reference actual AArch64 object/module/Image sealed;exported counter interface,admitted0;no substituted ELF\n'
 exit 0
fi
[[ -s $work/linked.sha256 ]]
(cd "$out";sha256sum -c --strict --quiet "$work/linked.sha256")
if [[ $phase == sealed ]];then
 printf 'Actual SSC time-reference final source/Image/ELFs unchanged after all inherited checks\n'
 exit 0
fi
[[ $# == 4 && ($phase == install || $phase == check) ]]
root=$(realpath -m "$4")
identity=$root/usr/share/senemos/uke/$release
module=$root/usr/lib/modules/$release/kernel/drivers/iio/common/uke-ssc/uke-ssc.ko.zst
cmp "$out/arch/arm64/boot/Image" "$root/usr/lib/modules/$release/vmlinuz"
[[ $(modinfo -F vermagic "$module") == "$release "* && -n $(modinfo -F signer "$module") ]]
if [[ $phase == install ]];then
 install -m644 "$work/final-source.sha256" "$identity/ssc-time-reference-source.sha256"
 install -m644 "$work/linked.sha256" "$identity/ssc-time-reference-linked.sha256"
 install -m644 "$work/parent-source.sha256" "$identity/ssc-time-reference-parent-native-hardware-source.sha256"
 install -m644 "$contract" "$identity/ssc-time-reference-delivery.json"
 install -m644 "$layer/src/sensors/sysfs-driver-uke-ssc-time-reference" "$identity/"
 node - "$identity/ssc-time-reference-full-qualification.json" "$release" "$contract" <<'JS'
const fs=require('fs'),[o,release,f]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(f));fs.writeFileSync(o,JSON.stringify({schema_version:1,kernel_release:release,parent_full_build:11318688,native_source_build:m.proof.build,native_source_receipt_sha256:m.proof.receipt_sha256,actual_full_image_linked:true,actual_arm64_ssc_object:true,root_attribute_mode:'0400',demand_only:true,firmware_requests_added:0,per_report_work_added:false,all_parent_hardware_units_retained:true,declared_ssc_postimage_extension:true,objects_never_replaced:true,clock_mapping_admitted:false,gravity_frame_admitted:false,production_motion_admission:false,crm_activation_allowed:false,physical_acceptance:false,copr_rpm_signatures_verified:false,new_runtime_packages:0},null,2)+'\n');
JS
else
 cmp "$work/final-source.sha256" "$identity/ssc-time-reference-source.sha256"
 cmp "$work/linked.sha256" "$identity/ssc-time-reference-linked.sha256"
 cmp "$work/parent-source.sha256" "$identity/ssc-time-reference-parent-native-hardware-source.sha256"
 cmp "$contract" "$identity/ssc-time-reference-delivery.json"
 jq --arg release "$release" --argjson build "$(jq -er .proof.build "$contract")" -e '.kernel_release==$release and .parent_full_build==11318688 and .native_source_build==$build and .actual_full_image_linked and .actual_arm64_ssc_object and .root_attribute_mode=="0400" and (.clock_mapping_admitted|not) and (.gravity_frame_admitted|not) and (.production_motion_admission|not) and (.physical_acceptance|not)' "$identity/ssc-time-reference-full-qualification.json" >/dev/null
fi
printf 'Existing core SSC time-reference metadata/%s admitted;clock/frame/physical gates remain separate\n' "$phase"
