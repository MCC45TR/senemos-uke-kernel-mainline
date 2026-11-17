#!/usr/bin/bash
# Exact full7 inverse; add qualified native-parent ordering and odd ROM support.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' 3ebbf025267e7ba7decccf3eb41b526181e0f22c8c5b678d1923faca3db1919e "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/header" <<'SPEC'
# UKE_CAMERA_FULL7348_HEADER_BEGIN
Source221: uke-camera-full7348.tar.xz
Source222: camera-native26-proof.rpm
Source223: camera-full7348-qualification.json
# UKE_CAMERA_FULL7348_HEADER_END
SPEC
cat > "$work/prepare" <<'SPEC'
# UKE_CAMERA_FULL7348_PREPARE_BEGIN
tar -xJf %{SOURCE221}
(cd camera-full7348;sha256sum -c --strict --quiet SHA256SUMS)
# UKE_CAMERA_FULL7348_PREPARE_END
SPEC
cat > "$work/build" <<'SPEC'
# UKE_CAMERA_FULL7348_BUILD_BEGIN
printf '%s  %s\n' "$(jq -er .native.proof_sha256 %{SOURCE223})" %{SOURCE222} | sha256sum -c --strict --quiet -
mkdir native-generated/camera-native26-proof
(cd native-generated/camera-native26-proof;rpm2cpio %{SOURCE222} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
native_proof25=$PWD/native-generated/camera-native26-proof/usr/share/uke-kernel-migration-check
for pair in odd parent;do
 case "$pair" in
  odd) name=camera-odd734;source_commit=$(jq -er .odd.source_commit %{SOURCE223});;
  parent) name=camera-parent734;source_commit=$(jq -er .native.source_commit %{SOURCE223});;
 esac
 proof=$native_proof25/$name
 layer=$PWD/camera-full7348/$name
 test "$(cat "$proof/source-commit")" = "$source_commit"
 cmp "$proof/SHA256SUMS" "$layer/SHA256SUMS"
 if test "$pair" = odd;then
  jq -e '.compiler_modes==4 and .before_controls==2 and .actual_arm64_objects==2 and .unknown_shifts_refused and .voltage_limits_unchanged and .firmware_ownership_retained and (.physical_camera_accepted|not)' "$proof/qualification.json"
 else
  jq -e '.constructor_modes==4 and .actual_pll_and_caller_modes==4 and .passive_modes==4 and .passive_semantic_mutants==4 and .before_controls==2 and .actual_arm64_objects==2 and .firmware_plls_unchanged and .original_limits_and_guards_retained and (.physical_camera_accepted|not)' "$proof/qualification.json"
 fi
 bash "$layer/tests/native-camera-$pair"'734.sh' "$PWD" "$super_objects" "$layer" "$PWD/camera-$pair"'734-result'
 cmp "$proof/qualification.json" "camera-$pair"'734-result/qualification.json'
 sha256sum -c --strict --quiet "$proof/source.sha256"
done
bash camera-full7348/seal-camera-native7348.sh "$PWD"
camera_full5_parent=$(bash camera-full7348/project-camera-native7348.sh "$PWD")
# UKE_CAMERA_FULL7348_BUILD_END
SPEC
cat > "$work/linked" <<'SPEC'
# UKE_CAMERA_FULL7348_LINKED_BEGIN
sha256sum -c --strict --quiet camera-native7348-result/source.sha256
grep -aqF 'crm-native-plls' %{_uke_out}/drivers/clk/qcom/camcc-sm7675.o
grep -aqF 'crm-native-plls' %{_uke_out}/arch/arm64/boot/Image
(cd %{_uke_out};sha256sum drivers/clk/qcom/camcc-sm7675.o arch/arm64/boot/Image vmlinux) > camera-native7348-result/full-linked.sha256
# UKE_CAMERA_FULL7348_LINKED_END
SPEC
cat > "$work/check" <<'SPEC'
# UKE_CAMERA_FULL7348_CHECK_BEGIN
sha256sum -c --strict --quiet camera-native7348-result/source.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-native7348-result/full-linked.sha256")
# UKE_CAMERA_FULL7348_CHECK_END
SPEC
cat > "$work/install" <<'SPEC'
# UKE_CAMERA_FULL7348_INSTALL_BEGIN
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-native7348-result/full-linked.sha256")
sha256sum -c --strict --quiet camera-native7348-result/source.sha256
native_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/camera-native7348
install -d "$native_support"
install -m644 %{SOURCE223} "$native_support/full-qualification.json"
install -m644 camera-native7348-result/*.sha256 "$native_support/"
for name in odd parent;do
 install -d "$native_support/$name"
 install -m644 camera-$name'734-result/'{source.sha256,native-objects.sha256,results.txt,qualification.json} "$native_support/$name/"
 install -m644 camera-full7348/camera-$name'734/'{source-commit,SHA256SUMS} "$native_support/$name/"
done
install -m644 camera-parent734-result/passive-results.txt "$native_support/parent/"
# UKE_CAMERA_FULL7348_INSTALL_END
SPEC
awk -v root="$work" '
 function inject(name,path,line){path=root"/"name;while((getline line<path)>0)print line;close(path)}
 /^%changelog$/{history=1;print;print "# UKE_CAMERA_FULL7348_HISTORY_BEGIN";print "* Tue Nov 17 2026 Uke contributors - 7.3.4-8";print "- Prepare local camera PLL parents before ROM decoding and retain the original odd postdivider field.";print "";print "# UKE_CAMERA_FULL7348_HISTORY_END";next}
 !history{
  if($0=="%global senemos_build_release 7"){$0="%global senemos_build_release 8";release++}
  if($0=="%description"){inject("header");header++}
  if($0=="# UKE_CAMERA_FULL7347_PREPARE_END"){print;inject("prepare");prepares++;next}
  if($0=="# UKE_CAMERA_FULL7347_BUILD_END"){print;inject("build");build++;next}
  if($0=="bash camera-full7347/verify-parent-source-tuple7347.sh \"$PWD\" \"$native_proof/source.sha256\""){
   print "# UKE_CAMERA_FULL7348_TUPLE_BEGIN";print "bash camera-full7348/verify-parent-source-tuple7348.sh \"$PWD\" \"$native_proof/source.sha256\"";print "# UKE_CAMERA_FULL7348_TUPLE_END";tuple++;next
  }
  if($0=="# UKE_CAMERA_FULL7347_LINKED_END"){print;inject("linked");linked++;next}
  if($0=="%check"){print;inject("check");checks++;next}
  if($0=="%install"){print;inject("install");installs++;next}
 }{print}END{if(release!=1||header!=1||prepares!=1||build!=1||tuple!=1||linked!=1||checks!=1||installs!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_CAMERA_FULL7348_TUPLE_END$/{print "bash camera-full7347/verify-parent-source-tuple7347.sh \"$PWD\" \"$native_proof/source.sha256\"";skip=0;next}
 /^# UKE_CAMERA_FULL7348_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_CAMERA_FULL7348_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="%global senemos_build_release 8"{$0="%global senemos_build_release 7"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == senemos-uke-linux-kernel-mainline-unstable-7.3.4-8.fc46 ]]
