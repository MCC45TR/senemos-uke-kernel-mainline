#!/usr/bin/bash
# Exact full6 inverse; add the independently qualified cached ROM reporter.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' df05e3e99b2f168bc12221b319b65b78127feb99e9827297adc43cb06e3c2b93 "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/header" <<'SPEC'
# UKE_CAMERA_FULL7347_HEADER_BEGIN
Source218: uke-camera-full7347.tar.xz
Source219: camera-native23-proof.rpm
Source220: camera-full7347-qualification.json
# UKE_CAMERA_FULL7347_HEADER_END
SPEC
cat > "$work/prepare" <<'SPEC'
# UKE_CAMERA_FULL7347_PREPARE_BEGIN
tar -xJf %{SOURCE218}
(cd camera-full7347;sha256sum -c --strict --quiet SHA256SUMS)
# UKE_CAMERA_FULL7347_PREPARE_END
SPEC
cat > "$work/build" <<'SPEC'
# UKE_CAMERA_FULL7347_BUILD_BEGIN
printf '%s  %s\n' "$(jq -er .native.proof_sha256 %{SOURCE220})" %{SOURCE219} | sha256sum -c --strict --quiet -
mkdir native-generated/camera-native23-proof
(cd native-generated/camera-native23-proof;rpm2cpio %{SOURCE219} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
rom_proof=$PWD/native-generated/camera-native23-proof/usr/share/uke-kernel-migration-check/camera-rom-report734
rom_layer=$PWD/camera-full7347/camera-rom-report734
test "$(cat "$rom_proof/source-commit")" = "$(jq -er .native.source_commit %{SOURCE220})"
cmp "$rom_proof/SHA256SUMS" "$rom_layer/SHA256SUMS"
jq -e '.schema_version==1 and .reporter_modes==4 and .production_admission_modes==4 and .actual_arm64_objects==2 and .maximum_lines_per_failure==23 and .hardware_reads_added==0 and .hardware_writes_added==0 and .errno_preserved and .cached_input_unchanged and .invalid_counts_refused and .firmware_guard_retained and (.physical_camera_accepted|not)' "$rom_proof/qualification.json"
bash "$rom_layer/tests/native-camera-rom-report734.sh" "$PWD" "$super_objects" "$rom_layer" "$PWD/camera-rom-report734-result"
cmp "$rom_proof/qualification.json" camera-rom-report734-result/qualification.json
sha256sum -c --strict --quiet "$rom_proof/source.sha256"
bash camera-full7347/seal-camera-rom-report7347.sh "$PWD" "$PWD/camera-rom-report734-result"
# UKE_CAMERA_FULL7347_BUILD_END
SPEC
cat > "$work/check" <<'SPEC'
# UKE_CAMERA_FULL7347_CHECK_BEGIN
sha256sum -c --strict --quiet camera-rom-report734-result/source.sha256
grep -aqF 'Uke camera ROM refusal:' %{_uke_out}/drivers/clk/qcom/camcc-sm7675.o
grep -aqF 'Uke camera ROM refusal:' %{_uke_out}/arch/arm64/boot/Image
(cd %{_uke_out};sha256sum drivers/clk/qcom/camcc-sm7675.o arch/arm64/boot/Image vmlinux) > camera-rom-report734-result/full-linked.sha256
# UKE_CAMERA_FULL7347_CHECK_END
SPEC
cat > "$work/install" <<'SPEC'
# UKE_CAMERA_FULL7347_INSTALL_BEGIN
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-rom-report734-result/full-linked.sha256")
sha256sum -c --strict --quiet camera-rom-report734-result/source.sha256
rom_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/camera-rom-report734
install -d "$rom_support"
install -m644 %{SOURCE220} "$rom_support/full-qualification.json"
install -m644 camera-rom-report734-result/{source.sha256,parent-source.sha256,current-source.sha256,native-objects.sha256,reporter-results.txt,composition-results.txt,qualification.json,full-linked.sha256} "$rom_support/"
install -m644 camera-full7347/camera-rom-report734/{source-commit,SHA256SUMS} "$rom_support/"
# UKE_CAMERA_FULL7347_INSTALL_END
SPEC
awk -v root="$work" '
 function inject(name,path,line){path=root"/"name;while((getline line<path)>0)print line;close(path)}
 /^%changelog$/{history=1;print;print "# UKE_CAMERA_FULL7347_HISTORY_BEGIN";print "* Tue Nov 17 2026 Uke contributors - 7.3.4-7";print "- Preserve full6 and report the exact cached CRM ROM refusal before camera admission.";print "";print "# UKE_CAMERA_FULL7347_HISTORY_END";next}
 !history{
  if($0=="%global senemos_build_release 6"){$0="%global senemos_build_release 7";release++}
  if($0=="%description"){inject("header");header++}
  if($0=="# UKE_CAMERA_FULL7346_PREPARE_END"){print;inject("prepare");prepares++;next}
  if($0=="# UKE_CAMERA_FULL7346_BUILD_END"){print;inject("build");build++;next}
  if($0=="bash camera-full7346/verify-parent-source-tuple7346.sh \"$PWD\" \"$native_proof/source.sha256\""){
   print "# UKE_CAMERA_FULL7347_TUPLE_BEGIN";print "bash camera-full7347/verify-parent-source-tuple7347.sh \"$PWD\" \"$native_proof/source.sha256\"";print "# UKE_CAMERA_FULL7347_TUPLE_END";tuple++;next
  }
  if($0=="%check"){print;inject("check");checks++;next}
  if($0=="%install"){print;inject("install");installs++;next}
 }{print}END{if(release!=1||header!=1||prepares!=1||build!=1||tuple!=1||checks!=1||installs!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_CAMERA_FULL7347_TUPLE_END$/{print "bash camera-full7346/verify-parent-source-tuple7346.sh \"$PWD\" \"$native_proof/source.sha256\"";skip=0;next}
 /^# UKE_CAMERA_FULL7347_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_CAMERA_FULL7347_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="%global senemos_build_release 7"{$0="%global senemos_build_release 6"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == senemos-uke-linux-kernel-mainline-unstable-7.3.4-7.fc46 ]]
