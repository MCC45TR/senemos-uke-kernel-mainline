#!/usr/bin/bash
# Render the full candidate from the actual full28 recipe, with a whole inverse.
set -Eeuo pipefail
[[ $# == 3 ]]
parent=$(realpath "$1"); result=$(realpath -m "$2"); plan=$(realpath "$3")
[[ ! -e $result && ! -L $result ]]
[[ $(jq -er .full_release "$plan") == 2 && $(jq -er .upstream.version "$plan") == 7.3.4 ]]
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$plan")" "$parent" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/sources" <<'SPEC'
# UKE_STABLE734_FULL_SOURCES_BEGIN
Source201: uke-stable734.tar.xz
Source202: stable734-full-qualification.json
Source203: stable734-native-proof.rpm
Source204: stable734-copr-public-key.asc
# UKE_STABLE734_FULL_SOURCES_END
SPEC
cat > "$work/build" <<'SPEC'
# UKE_STABLE734_FULL_BUILD_BEGIN
tar -xJf %{SOURCE201}
bash native-profile/src/display/apply-native-vrr734.sh "$PWD"
mkdir native-generated/stable734-native-proof
(cd native-generated/stable734-native-proof;rpm2cpio %{SOURCE203} | cpio -idm --quiet --no-absolute-filenames)
native_proof=$PWD/native-generated/stable734-native-proof/usr/share/uke-kernel-migration-check
test "$(cat "$native_proof/source-commit")" = "$(jq -er .source_check.source_commit %{SOURCE202})"
sha256sum -c --strict --quiet "$native_proof/source.sha256"
bash native-profile/packaging/native/preflight-audio-identity734.sh "$PWD"
# UKE_STABLE734_FULL_BUILD_END
SPEC
cat > "$work/check" <<'SPEC'
# UKE_STABLE734_FULL_CHECK_BEGIN
grep -Fxq 'CONFIG_LIVEPATCH=y' %{_uke_out}/.config
bash native-profile/tests/kernel-hardening-config-contract.sh %{_uke_out}/.config
openssl x509 -in native-profile/src/livepatch/uke-livepatch-20261115.pem -outform DER | cmp - %{_uke_out}/certs/x509_certificate_list
llvm-nm %{_uke_out}/vmlinux | awk '$NF=="klp_enable_patch"{found=1}END{exit !found}'
printf '%s  %s\n' "$(jq -er .after_encoder_sha256 native-profile/manifests/native-vrr734-20261115.json)" drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c | sha256sum -c --strict --quiet -
bash native-profile/tests/audio-identity734.sh "$PWD/native-profile" %{_uke_out}/sound/soc/qcom/uke-audio-card.ko
# UKE_STABLE734_FULL_CHECK_END
SPEC
cat > "$work/install" <<'SPEC'
# UKE_STABLE734_FULL_INSTALL_BEGIN
build_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support
install -d "$build_support"
install -m644 %{_uke_out}/Module.symvers "$build_support/"
install -m644 %{_uke_out}/include/generated/{utsrelease.h,compile.h} "$build_support/"
install -m644 %{SOURCE202} "$build_support/qualification.json"
install -m644 native-profile/src/livepatch/uke-livepatch-20261115.pem "$build_support/"
# UKE_STABLE734_FULL_INSTALL_END
SPEC
awk -v sources="$work/sources" -v build="$work/build" -v check="$work/check" -v install="$work/install" '
 function inject(path){while((getline line<path)>0)print line;close(path)}
 /^%changelog$/ {
  print;print "* Sun Nov 15 2026 Uke contributors - 7.3.4-2";
  print "- Add native VRR, battery LED events and signed livepatch support; physical qualification remains separate.";
  print "";history=1;next
 }
 !history {
  gsub(/7[.]3[.]3/,"7.3.4")
  if($0=="%global senemos_build_release 28"){$0="%global senemos_build_release 2";release++}
  if($0=="export SOURCE_DATE_EPOCH=1793989159"){$0="export SOURCE_DATE_EPOCH=1794334272";epoch++}
  if($0=="%description"){inject(sources);source++}
  if($0=="%package core"){print;print "# UKE_STABLE734_FULL_DEP_BEGIN";
   print "Requires: uke-control(rgb-charge-status-v1) >= 1";print "# UKE_STABLE734_FULL_DEP_END";dep++;next}
  if(/^bash boot-recipe\/src\/boot\/build-payload[.]sh /){inject(build);payload++}
  if($0=="%check"){print;inject(check);checks++;next}
  if($0=="%install"){print;inject(install);installs++;next}
 }
 {print}
 END{if(release!=1||epoch!=1||source!=1||dep!=1||payload!=1||checks!=1||installs!=1)exit 1}
' "$parent" > "$result"
awk '
 /^# UKE_STABLE734_FULL_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_STABLE734_FULL_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{print;history=1;drop=3;next}
 drop{drop--;next}
 !history {
  gsub(/7[.]3[.]4/,"7.3.3")
  if($0=="%global senemos_build_release 2")$0="%global senemos_build_release 28"
  if($0=="export SOURCE_DATE_EPOCH=1794334272")$0="export SOURCE_DATE_EPOCH=1793989159"
 }
 {print}
' "$result" | cmp - "$parent"
printf 'Full7.3.4-2 recipe: complete28 inverse, retained build/check/install/slot logic, native VRR/livepatch gates and existing Control capability dependency passed.\n'
