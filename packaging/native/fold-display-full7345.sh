#!/usr/bin/bash
# Preserve the whole actual full4 recipe and append the qualified MDP handoff.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' 141c2c4052c96e7f749f0caa3bd3f75eed141dd3644be1842b0b1092eda4e9dc "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/header" <<'SPEC'
# UKE_DISPLAY_FULL7345_HEADER_BEGIN
Source212: uke-display-full7345.tar.xz
Source213: display-handoff-native-proof.rpm
Source214: display-full7345-qualification.json
# UKE_DISPLAY_FULL7345_HEADER_END
SPEC
cat > "$work/prepare" <<'SPEC'
# UKE_DISPLAY_FULL7345_PREPARE_BEGIN
tar -xJf %{SOURCE212}
(cd display-full7345;sha256sum -c --strict --quiet SHA256SUMS)
# UKE_DISPLAY_FULL7345_PREPARE_END
SPEC
cat > "$work/build" <<'SPEC'
# UKE_DISPLAY_FULL7345_BUILD_BEGIN
printf '%s  %s\n' "$(jq -er .native.proof_sha256 %{SOURCE214})" %{SOURCE213} | sha256sum -c --strict --quiet -
mkdir native-generated/display-handoff-native-proof
(cd native-generated/display-handoff-native-proof;rpm2cpio %{SOURCE213} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
display_proof=$PWD/native-generated/display-handoff-native-proof/usr/share/uke-kernel-migration-check/display-handoff734
test "$(cat "$display_proof/source-commit")" = "$(jq -er .native.source_commit %{SOURCE214})"
cmp "$display_proof/SHA256SUMS" display-full7345/display-handoff734/SHA256SUMS
jq -e '.compiler_modes==4 and .actual_arm64_provider_objects==1 and .firmware_rcg_configuration_preserved and .normal_park_restore_retained and .semantic_mutants==2' "$display_proof/qualification.json"
bash display-full7345/display-handoff734/tests/native-display-handoff734.sh "$PWD" "$super_objects"
sha256sum -c --strict --quiet "$display_proof/source.sha256"
# UKE_DISPLAY_FULL7345_BUILD_END
SPEC
cat > "$work/check" <<'SPEC'
# UKE_DISPLAY_FULL7345_CHECK_BEGIN
test "$(grep -c '^PASS: display handoff' display-handoff734-result/native-results.txt)" = 4
sha256sum -c --strict --quiet display-handoff734-result/source.sha256
# UKE_DISPLAY_FULL7345_CHECK_END
SPEC
cat > "$work/install" <<'SPEC'
# UKE_DISPLAY_FULL7345_INSTALL_BEGIN
display_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/display-handoff734
install -d "$display_support"
install -m644 %{SOURCE214} "$display_support/full-qualification.json"
install -m644 display-handoff734-result/{source.sha256,native-objects.sha256,native-results.txt,qualification.json,parent-uke-dispcc-votes.c} "$display_support/"
# UKE_DISPLAY_FULL7345_INSTALL_END
SPEC
awk -v root="$work" '
 function inject(name,path,line){path=root"/"name;while((getline line<path)>0)print line;close(path)}
 /^%changelog$/{history=1;print;print "# UKE_DISPLAY_FULL7345_HISTORY_BEGIN";print "* Mon Nov 16 2026 Uke contributors - 7.3.4-5";print "- Keep the firmware MDP clock configuration until native takeover, preserving cumulative full4 and normal runtime clock parking.";print "";print "# UKE_DISPLAY_FULL7345_HISTORY_END";next}
 !history{
  if($0=="%global senemos_build_release 4"){$0="%global senemos_build_release 5";release++}
  if($0=="%description"){inject("header");header++}
  if($0=="%build"){print;inject("prepare");prepares++;next}
  if($0=="bash full4/packaging/native/verify-parent-source-tuple7344.sh \"$PWD\" \"$native_proof/source.sha256\""){
   print "# UKE_DISPLAY_FULL7345_TUPLE_BEGIN";print "bash display-full7345/verify-parent-source-tuple7345.sh \"$PWD\" \"$native_proof/source.sha256\"";print "# UKE_DISPLAY_FULL7345_TUPLE_END";tuple++;next
  }
  if(/^bash boot-recipe\/src\/boot\/build-payload[.]sh /){inject("build");build++}
  if($0=="%check"){print;inject("check");checks++;next}
  if($0=="%install"){print;inject("install");installs++;next}
 }{print}
 END{if(release!=1||header!=1||prepares!=1||tuple!=1||build!=1||checks!=1||installs!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_DISPLAY_FULL7345_TUPLE_END$/{print "bash full4/packaging/native/verify-parent-source-tuple7344.sh \"$PWD\" \"$native_proof/source.sha256\"";skip=0;next}
 /^# UKE_DISPLAY_FULL7345_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_DISPLAY_FULL7345_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="%global senemos_build_release 5"{$0="%global senemos_build_release 4"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == senemos-uke-linux-kernel-mainline-unstable-7.3.4-5.fc46 ]]
