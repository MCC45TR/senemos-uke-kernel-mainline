#!/usr/bin/bash
# Preserve the actual full7342 recipe, correcting only the RGB client and ABM.
set -Eeuo pipefail
[[ $# == 2 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
bash "$owner/packaging/native/move-rgb-client-dependency.sh" "$before" "$work/parent.spec"
cat > "$work/header" <<'SPEC'
# UKE_ABM_FULL7343_HEADER_BEGIN
Source205: uke-native-abm734.tar.xz
Source206: abm734-native-proof.rpm
Source207: abm734-full-qualification.json
# UKE_ABM_FULL7343_HEADER_END
SPEC
cat > "$work/build" <<'SPEC'
# UKE_ABM_FULL7343_BUILD_BEGIN
printf '%s  %s\n' "$(jq -er .native.proof_sha256 %{SOURCE207})" %{SOURCE206} | sha256sum -c --strict --quiet -
mkdir native-generated/abm734-native-proof
(cd native-generated/abm734-native-proof;rpm2cpio %{SOURCE206} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
abm_proof=$PWD/native-generated/abm734-native-proof/usr/share/uke-kernel-migration-check/abm734
test "$(cat "$abm_proof/layer-source-commit")" = "$(jq -er .native.source_commit %{SOURCE207})"
cmp "$abm_proof/qualified-source.sha256" abm734/src/display/abm734-post.sha256
bash abm734/src/display/apply-native-abm734.sh "$PWD"
sha256sum -c --strict --quiet "$abm_proof/qualified-source.sha256"
if ! bash abm734/tests/native-abm734.sh "$PWD" > native-generated/abm734-native-results.txt 2>&1;then tail -n 100 native-generated/abm734-native-results.txt;exit 1;fi
cat native-generated/abm734-native-results.txt
# UKE_ABM_FULL7343_BUILD_END
SPEC
cat > "$work/check" <<'SPEC'
# UKE_ABM_FULL7343_CHECK_BEGIN
test "$(grep -c '^PASS: native ABM' native-generated/abm734-native-results.txt)" = 4
sha256sum -c --strict --quiet abm734/src/display/abm734-post.sha256
llvm-nm %{_uke_out}/drivers/gpu/drm/msm/dsi/dsi_manager.o | awk '$NF=="qcom_uke_dsi_abm_register"{found=1}END{exit !found}'
llvm-nm %{_uke_out}/drivers/gpu/drm/panel/panel-xiaomi-o82.o | awk '$NF=="o82_abm_update"{found=1}END{exit !found}'
# UKE_ABM_FULL7343_CHECK_END
SPEC
cat > "$work/install" <<'SPEC'
# UKE_ABM_FULL7343_INSTALL_BEGIN
abm_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/abm734
install -d "$abm_support"
install -m644 %{SOURCE207} "$abm_support/qualification.json"
install -m644 abm734/src/display/{abm734-parent.sha256,abm734-post.sha256} native-generated/abm734-native-results.txt "$abm_support/"
# UKE_ABM_FULL7343_INSTALL_END
SPEC
awk -v root="$work" '
 function inject(name,path,line){path=root"/"name;while((getline line<path)>0)print line;close(path)}
 /^%changelog$/{history=1;print;print "# UKE_ABM_FULL7343_HISTORY_BEGIN";print "* Mon Nov 16 2026 Uke contributors - 7.3.4-3";print "- Update CABC without cycling the powered O82 panel; keep the RGB desktop client outside lean rescue core.";print "";print "# UKE_ABM_FULL7343_HISTORY_END";next}
 !history{
  if($0=="%global senemos_build_release 2"){$0="%global senemos_build_release 3";release++}
  if($0=="%description"){inject("header");header++}
  if($0=="sha256sum -c --strict --quiet \"$native_proof/source.sha256\""){
   print "# UKE_ABM_FULL7343_PARENT_BEGIN"
   print "tar -xJf %{SOURCE205}"
   print "(cd abm734;sha256sum -c --strict --quiet SHA256SUMS)"
   print "bash abm734/packaging/native/verify-parent-source-tuple734.sh \"$PWD\" \"$native_proof/source.sha256\""
   print "# UKE_ABM_FULL7343_PARENT_END";proof++;next
  }
  if(/^bash boot-recipe\/src\/boot\/build-payload[.]sh /){inject("build");build++}
  if($0=="%check"){print;inject("check");checks++;next}
  if($0=="%install"){print;inject("install");installs++;next}
 }{print}
 END{if(release!=1||header!=1||build!=1||checks!=1||installs!=1||proof!=1)exit 1}
' "$work/parent.spec" > "$after"
awk '
 /^# UKE_ABM_FULL7343_PARENT_END$/{print "sha256sum -c --strict --quiet \"$native_proof/source.sha256\"";skip=0;next}
 /^# UKE_ABM_FULL7343_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_ABM_FULL7343_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="%global senemos_build_release 3"{$0="%global senemos_build_release 2"}
 {print}
' "$after" | cmp - "$work/parent.spec"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == senemos-uke-linux-kernel-mainline-unstable-7.3.4-3.fc46 ]]
printf 'Full7343 retains the entire actual7342 recipe inverse, RGB dependency correction and late ABM checks; no submission or hardware acceptance.\n'
