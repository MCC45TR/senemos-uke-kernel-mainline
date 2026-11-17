#!/usr/bin/bash
# Retain the complete full9 recipe and add only qualified late front admission.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' b4082ea36915d9071d2dcfaeb55b963ffbea35bc91732e92c07a5f54fcfa5ac5 "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/header" <<'SPEC'
# UKE_CAMERA_FULL73410_HEADER_BEGIN
Source227: uke-camera-full73410.tar.xz
Source228: camera-native33-proof.rpm
Source229: camera-full73410-qualification.json
# UKE_CAMERA_FULL73410_HEADER_END
SPEC
cat > "$work/prepare" <<'SPEC'
# UKE_CAMERA_FULL73410_PREPARE_BEGIN
tar -xJf %{SOURCE227}
(cd camera-full73410;sha256sum -c --strict --quiet SHA256SUMS)
# UKE_CAMERA_FULL73410_PREPARE_END
SPEC
cat > "$work/build" <<'SPEC'
# UKE_CAMERA_FULL73410_BUILD_BEGIN
printf '%s  %s\n' "$(jq -er .native.proof_sha256 %{SOURCE229})" %{SOURCE228} | sha256sum -c --strict --quiet -
mkdir native-generated/camera-native33-proof
(cd native-generated/camera-native33-proof;rpm2cpio %{SOURCE228} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
front_proof=$PWD/native-generated/camera-native33-proof/usr/share/uke-kernel-migration-check/front-stage734
test "$(cat "$front_proof/source-commit")" = "$(jq -er .native.source_commit %{SOURCE229})"
bash camera-full73410/tests/native-camera-full73410.sh "$PWD" "$super_objects" "$PWD/camera-full73410" "$front_proof"
# UKE_CAMERA_FULL73410_BUILD_END
SPEC
cat > "$work/linked" <<'SPEC'
# UKE_CAMERA_FULL73410_LINKED_BEGIN
sha256sum -c --strict --quiet camera-full73410-result/source.sha256
grep -aqF uke-front-calibration %{_uke_out}/arch/arm64/boot/Image
cp camera-full7349-result/full-linked.sha256 camera-full73410-result/full-linked.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-full73410-result/full-linked.sha256")
# UKE_CAMERA_FULL73410_LINKED_END
SPEC
cat > "$work/check" <<'SPEC'
# UKE_CAMERA_FULL73410_CHECK_BEGIN
sha256sum -c --strict --quiet camera-full73410-result/source.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-full73410-result/full-linked.sha256")
jq -e '.compiler_modes==4 and .actual_arm64_objects==1 and .readonly_helper_unchanged and .real_interconnect_tag_converter and (.physical_camera_accepted|not)' front-stage734-result/qualification.json
jq -e '.compiler_modes==4 and .board_predicate_projection and .phandles_remapped and (.contains_unit_data|not) and (.contains_eeprom_contents|not) and (.physical_camera_accepted|not)' front-observed734-result/qualification.json
# UKE_CAMERA_FULL73410_CHECK_END
SPEC
cat > "$work/install" <<'SPEC'
# UKE_CAMERA_FULL73410_INSTALL_BEGIN
sha256sum -c --strict --quiet camera-full73410-result/source.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-full73410-result/full-linked.sha256")
front_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/camera-front-stage73410
install -d "$front_support"
install -m644 %{SOURCE229} "$front_support/full-qualification.json"
install -m644 camera-full73410-result/*.sha256 "$front_support/"
for name in front-stage734 front-observed734;do
 install -d "$front_support/$name"
 install -m644 "$name-result/"{results.txt,qualification.json} "$front_support/$name/"
done
install -m644 front-stage734-result/{source.sha256,native-objects.sha256,disabled-results.txt} "$front_support/front-stage734/"
install -m644 front-observed734-result/profile.sha256 "$front_support/front-observed734/"
install -m644 camera-full73410/front-stage734/src/camera/front-stage734/{pre.sha256,post.sha256,late-stage.patch} "$front_support/front-stage734/"
# UKE_CAMERA_FULL73410_INSTALL_END
SPEC
awk -v root="$work" '
 function inject(name,path,line){path=root"/"name;while((getline line<path)>0)print line;close(path)}
 /^%changelog$/{history=1;print;print "# UKE_CAMERA_FULL73410_HISTORY_BEGIN";print "* Tue Nov 17 2026 Uke contributors - 7.3.4-10";print "- Admit the read-only front gate after native interconnect tags and restored DT capacity.";print "- Qualify the unchanged helper against a board-only projection before linking the Image.";print "";print "# UKE_CAMERA_FULL73410_HISTORY_END";next}
 !history{
  if($0=="%global senemos_build_release 9"){$0="%global senemos_build_release 10";release++}
  if($0=="%description"){inject("header");headers++}
  if($0=="# UKE_CAMERA_FULL7349_PREPARE_END"){print;inject("prepare");prepares++;next}
  if($0=="# UKE_CAMERA_FULL7349_BUILD_END"){print;inject("build");builds++;next}
  if($0=="bash camera-full7349/verify-parent-source-tuple7349.sh \"$PWD\" \"$native_proof/source.sha256\""){
   print "# UKE_CAMERA_FULL73410_TUPLE_BEGIN";print "bash camera-full73410/verify-parent-source-tuple73410.sh \"$PWD\" \"$native_proof/source.sha256\"";print "# UKE_CAMERA_FULL73410_TUPLE_END";tuples++;next
  }
  if($0=="# UKE_CAMERA_FULL7349_LINKED_END"){print;inject("linked");links++;next}
  if($0=="%check"){print;inject("check");checks++;next}
  if($0=="%install"){print;inject("install");installs++;next}
 }{print}END{if(release!=1||headers!=1||prepares!=1||builds!=1||tuples!=1||links!=1||checks!=1||installs!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_CAMERA_FULL73410_TUPLE_END$/{print "bash camera-full7349/verify-parent-source-tuple7349.sh \"$PWD\" \"$native_proof/source.sha256\"";skip=0;next}
 /^# UKE_CAMERA_FULL73410_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_CAMERA_FULL73410_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="%global senemos_build_release 10"{$0="%global senemos_build_release 9"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == senemos-uke-linux-kernel-mainline-unstable-7.3.4-10.fc46 ]]
