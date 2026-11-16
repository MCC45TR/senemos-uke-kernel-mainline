#!/usr/bin/bash
# Add the late ABM qualification without removing any native13 phase or input.
set -Eeuo pipefail
[[ $# == 3 ]]
before=$(realpath "$1");after=$(realpath -m "$2");contract=$(realpath "$3")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' "$(jq -er .parent.spec_sha256 "$contract")" "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/header" <<'SPEC'
# UKE_NATIVE_ABM14_HEADER_BEGIN
Source202: uke-native-abm734.tar.xz
Source203: native13-parent-proof.rpm
Source204: native-abm734-20261116.json
# UKE_NATIVE_ABM14_HEADER_END
SPEC
cat > "$work/build" <<'SPEC'
# UKE_NATIVE_ABM14_BUILD_BEGIN
tar -xJf %{SOURCE202}
(cd abm734;sha256sum -c --strict --quiet SHA256SUMS)
printf '%s  %s\n' "$(jq -er .parent.proof_sha256 %{SOURCE204})" %{SOURCE203} | sha256sum -c --strict --quiet -
mkdir abm734/parent-proof
(cd abm734/parent-proof;rpm2cpio %{SOURCE203} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
cmp abm734/parent-proof/usr/share/uke-kernel-migration-check/source.sha256 stable734-objects/source.sha256
bash abm734/src/display/apply-native-abm734.sh "$PWD"
if ! bash abm734/tests/native-abm734.sh "$PWD" > abm734/native-results.txt 2>&1;then tail -n 100 abm734/native-results.txt;exit 1;fi
cat abm734/native-results.txt
make -s O="$PWD/stable734-objects" ARCH=arm64 LLVM=1 LLVM_IAS=1 -j2 \
 drivers/gpu/drm/drm_atomic_helper.o drivers/gpu/drm/msm/msm_atomic.o \
 drivers/gpu/drm/msm/dsi/dsi_manager.o drivers/gpu/drm/panel/panel-xiaomi-o82.o
for object in drivers/gpu/drm/drm_atomic_helper.o drivers/gpu/drm/msm/msm_atomic.o drivers/gpu/drm/msm/dsi/dsi_manager.o drivers/gpu/drm/panel/panel-xiaomi-o82.o;do
 llvm-readelf -h "stable734-objects/$object" | grep -F AArch64
done
llvm-nm stable734-objects/drivers/gpu/drm/msm/dsi/dsi_manager.o | awk '$NF=="qcom_uke_dsi_abm_register"{found=1}END{exit !found}'
llvm-nm stable734-objects/drivers/gpu/drm/msm/msm_atomic.o | awk '$NF=="msm_dsi_manager_uke_abm_apply"&&$(NF-1)=="U"{found=1}END{exit !found}'
sha256sum -c --strict --quiet abm734/src/display/abm734-post.sha256
cp abm734/src/display/abm734-post.sha256 abm734/qualified-source.sha256
(cd stable734-objects;sha256sum drivers/gpu/drm/drm_atomic_helper.o drivers/gpu/drm/msm/msm_atomic.o drivers/gpu/drm/msm/dsi/dsi_manager.o drivers/gpu/drm/panel/panel-xiaomi-o82.o) > abm734/native-objects.sha256
jq --arg commit "$(cat abm734/layer-source-commit)" '. + {layer_source_commit:$commit,native_qualified:true,kernel_objects_qualified:true,compiler_modes:4,kernel_object_count:4,contains_kernel_image:false,physical_acceptance:false,installed_on_target:false}' %{SOURCE204} > abm734/qualification.json
# UKE_NATIVE_ABM14_BUILD_END
SPEC
cat > "$work/install" <<'SPEC'
# UKE_NATIVE_ABM14_INSTALL_BEGIN
install -Dm644 abm734/native-results.txt %{buildroot}%{_datadir}/%{name}/abm734/native-results.txt
install -m644 abm734/{qualified-source.sha256,native-objects.sha256,qualification.json,layer-source-commit} %{SOURCE204} %{buildroot}%{_datadir}/%{name}/abm734/
# UKE_NATIVE_ABM14_INSTALL_END
SPEC
cat > "$work/check" <<'SPEC'
# UKE_NATIVE_ABM14_CHECK_BEGIN
test "$(grep -c '^PASS: native ABM' abm734/native-results.txt)" = 4
sha256sum -c --strict --quiet abm734/qualified-source.sha256
test ! -e stable734-objects/arch/arm64/boot/Image
# UKE_NATIVE_ABM14_CHECK_END
SPEC
awk -v root="$work" '
 function inject(name,path,line){path=root"/"name;while((getline line<path)>0)print line;close(path)}
 /^%changelog$/{history=1;print;print "# UKE_NATIVE_ABM14_HISTORY_BEGIN";print "* Mon Nov 16 2026 Uke contributors - 7.3.4-14";print "- Qualify live O82 ABM commands, lifetime and rollback with native objects; no Image or physical acceptance.";print "";print "# UKE_NATIVE_ABM14_HISTORY_END";next}
 !history{
  if($0=="Release: 13%{?dist}"){$0="Release: 14%{?dist}";release++}
  if($0=="%description"){inject("header");header++}
  if($0=="%install"){inject("build");build++;print;inject("install");installs++;next}
  if($0=="%check"){print;inject("check");checks++;next}
 }{print}
 END{if(release!=1||header!=1||build!=1||installs!=1||checks!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_NATIVE_ABM14_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_NATIVE_ABM14_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="Release: 14%{?dist}"{$0="Release: 13%{?dist}"}
 {print}
' "$after" | cmp - "$before"
printf 'Native14 keeps the complete native13 recipe inverse and adds only late ABM source, synthetic functions and actual ARM64 objects.\n'
