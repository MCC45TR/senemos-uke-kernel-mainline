#!/usr/bin/bash
# Retain the actual full5 recipe, adding the qualified native22 camera layer.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' c8fe66fbc9d9633fc26225acaf453fecb03c7d70a1a208e606fe310953f688fd "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/header" <<'SPEC'
# UKE_CAMERA_FULL7346_HEADER_BEGIN
Source215: uke-camera-full7346.tar.xz
Source216: camera-native22-proof.rpm
Source217: camera-full7346-qualification.json
# UKE_CAMERA_FULL7346_HEADER_END
SPEC
cat > "$work/prepare" <<'SPEC'
# UKE_CAMERA_FULL7346_PREPARE_BEGIN
tar -xJf %{SOURCE215}
(cd camera-full7346;sha256sum -c --strict --quiet SHA256SUMS)
# UKE_CAMERA_FULL7346_PREPARE_END
SPEC
cat > "$work/build" <<'SPEC'
# UKE_CAMERA_FULL7346_BUILD_BEGIN
printf '%s  %s\n' "$(jq -er .native.proof_sha256 %{SOURCE217})" %{SOURCE216} | sha256sum -c --strict --quiet -
mkdir native-generated/camera-native22-proof
(cd native-generated/camera-native22-proof;rpm2cpio %{SOURCE216} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
camera_proof=$PWD/native-generated/camera-native22-proof/usr/share/uke-kernel-migration-check/camera-owner734
test "$(cat "$camera_proof/source-commit")" = "$(jq -er .native.source_commit %{SOURCE217})"
cmp "$camera_proof/SHA256SUMS" camera-full7346/camera-owner734/SHA256SUMS
jq -e '.schema_version==2 and .owner_compiler_modes==4 and .rom_compiler_modes==4 and .startup_compiler_modes==4 and .floor_compiler_modes==4 and .composition_compiler_modes==4 and .actual_caller_compiler_modes==4 and .semantic_mutants==7 and .actual_arm64_objects==2 and .inherited_AP0_preserved_until_sync and .all8_IRQ_enable_failures_covered and .firmware_guard_retained and .probe_calls_owner and .probe_calls_rom and .probe_calls_startup and .probe_calls_floor and .primary_CRM_command_map and .separate_CRMC_ROM_map and (.physical_camera_accepted|not) and (.contains_kernel_image|not)' "$camera_proof/qualification.json"
bash camera-full7346/camera-owner734/tests/native-camera-owner734.sh "$PWD" "$super_objects"
cmp "$camera_proof/qualification.json" camera-owner734-result/qualification.json
sha256sum -c --strict --quiet "$camera_proof/source.sha256"
camera_full5_parent=$(bash camera-full7346/camera-full5-legacy-view734.sh "$PWD")
uke_hwkm_parent=$(bash camera-full7346/camera-hwkm-legacy-view7346.sh "$camera_full5_parent")
# UKE_CAMERA_FULL7346_BUILD_END
SPEC
cat > "$work/check" <<'SPEC'
# UKE_CAMERA_FULL7346_CHECK_BEGIN
camera_full5_parent=$(bash camera-full7346/camera-full5-legacy-view734.sh "$PWD")
sha256sum -c --strict --quiet camera-owner734-result/source.sha256 camera-owner734-result/retained.sha256
for family in owner rom startup floor composition caller;do
 test "$(wc -l < camera-owner734-result/$family-results.txt)" -ge 4
done
for marker in firmware-managed crm-rom crm-topology crm-startup crm-transport crm-attach;do
 grep -aqF "$marker" %{_uke_out}/drivers/clk/qcom/camcc-sm7675.o
 grep -aqF "$marker" %{_uke_out}/arch/arm64/boot/Image
done
llvm-readelf -h %{_uke_out}/drivers/clk/qcom/camcc-sm7675.o | grep -F AArch64
grep -Fx kernel/drivers/clk/qcom/camcc-sm7675.ko %{_uke_out}/modules.builtin
(cd %{_uke_out};sha256sum drivers/clk/qcom/camcc-sm7675.o arch/arm64/boot/Image vmlinux) > camera-owner734-result/full-linked.sha256
# UKE_CAMERA_FULL7346_CHECK_END
SPEC
cat > "$work/install" <<'SPEC'
# UKE_CAMERA_FULL7346_INSTALL_BEGIN
camera_full5_parent=$(bash camera-full7346/camera-full5-legacy-view734.sh "$PWD")
camera_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/camera-native734
install -d "$camera_support"
install -m644 %{SOURCE217} "$camera_support/full-qualification.json"
install -m644 camera-owner734-result/{source.sha256,retained.sha256,native-objects.sha256,owner-results.txt,rom-results.txt,startup-results.txt,floor-results.txt,composition-results.txt,caller-results.txt,qualification.json,parent-camcc-sm7675.c} "$camera_support/"
install -m644 camera-full7346/camera-owner734/{source-commit,SHA256SUMS} "$camera_support/"
# UKE_CAMERA_FULL7346_INSTALL_END
SPEC
cat > "$work/sealed" <<'SPEC'
# UKE_CAMERA_FULL7346_SEALED_BEGIN
sha256sum -c --strict --quiet camera-owner734-result/source.sha256 camera-owner734-result/retained.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-owner734-result/full-linked.sha256")
cmp %{_uke_out}/arch/arm64/boot/Image %{buildroot}/usr/lib/modules/%{krel}/vmlinuz
# UKE_CAMERA_FULL7346_SEALED_END
SPEC
awk -v root="$work" '
 function inject(name,path,line){path=root"/"name;while((getline line<path)>0)print line;close(path)}
 /^%changelog$/{history=1;print;print "# UKE_CAMERA_FULL7346_HISTORY_BEGIN";print "* Tue Nov 17 2026 Uke contributors - 7.3.4-6";print "- Admit firmware CRM through checked ROM, permanent IRQ ownership and inherited-vote synchronization, preserving cumulative full5.";print "";print "# UKE_CAMERA_FULL7346_HISTORY_END";next}
 !history{
  if($0=="%global senemos_build_release 5"){$0="%global senemos_build_release 6";release++}
  if($0=="%description"){inject("header");header++}
  if($0=="%build"){print;inject("prepare");prepares++;next}
  if($0=="bash display-full7345/verify-parent-source-tuple7345.sh \"$PWD\" \"$native_proof/source.sha256\""){
   print "# UKE_CAMERA_FULL7346_TUPLE_BEGIN";print "bash camera-full7346/verify-parent-source-tuple7346.sh \"$PWD\" \"$native_proof/source.sha256\"";print "# UKE_CAMERA_FULL7346_TUPLE_END";tuple++;next
  }
  if(/^bash boot-recipe\/src\/boot\/build-payload[.]sh /){inject("build");build++;mutated=1}
  if(mutated && $0=="uke_hwkm_parent=$(bash hwkm-early/packaging/native/hwkm-early-legacy-view733.sh \"$PWD\")"){
   print "# UKE_CAMERA_FULL7346_VIEW_BEGIN";print "uke_hwkm_parent=$(bash camera-full7346/camera-hwkm-legacy-view7346.sh \"$camera_full5_parent\")";print "# UKE_CAMERA_FULL7346_VIEW_END";views++;next
  }
  if(mutated && /^bash hwkm-early\/packaging\/native\/prepare-hwkm-early733[.]sh "\$PWD" /){
   print "# UKE_CAMERA_FULL7346_HWKM_BEGIN";sub(/"\$PWD"/,"\"$camera_full5_parent\"");print;print "# UKE_CAMERA_FULL7346_HWKM_END";hwkm++;next
  }
  if($0=="%check"){print;inject("check");checks++;next}
  if($0=="%install"){inject("sealed");print;inject("install");installs++;next}
 }{print}
 END{if(release!=1||header!=1||prepares!=1||tuple!=1||build!=1||checks!=1||installs!=1||views!=2||hwkm!=4)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_CAMERA_FULL7346_TUPLE_END$/{print "bash display-full7345/verify-parent-source-tuple7345.sh \"$PWD\" \"$native_proof/source.sha256\"";skip=0;next}
 /^# UKE_CAMERA_FULL7346_VIEW_BEGIN$/{view=1;next}
 /^# UKE_CAMERA_FULL7346_HWKM_BEGIN$/{hwkm=1;next}
 /^# UKE_CAMERA_FULL7346_(VIEW|HWKM)_END$/{view=0;hwkm=0;next}
 view{sub(/camera-full7346\/camera-hwkm-legacy-view7346[.]sh/,"hwkm-early/packaging/native/hwkm-early-legacy-view733.sh")}
 view||hwkm{gsub(/"\$camera_full5_parent"/,"\"$PWD\"");print;next}
 /^# UKE_CAMERA_FULL7346_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_CAMERA_FULL7346_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="%global senemos_build_release 6"{$0="%global senemos_build_release 5"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == senemos-uke-linux-kernel-mainline-unstable-7.3.4-6.fc46 ]]
