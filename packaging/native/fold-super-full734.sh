#!/usr/bin/bash
# Keep the complete actual full3 recipe; add separately qualified boot layers.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' ad51469d681b8e5db62956c728e1d1c98c752a7c5a90f84a786092699be39823 "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/header" <<'SPEC'
# UKE_SUPER_FULL7344_HEADER_BEGIN
BuildRequires: android-tools e2fsprogs device-mapper
Source208: uke-super-full734.tar.xz
Source209: super734-native-proof.rpm
Source210: super734-initrd-proof.rpm
Source211: super734-full-qualification.json
# UKE_SUPER_FULL7344_HEADER_END
SPEC
cat > "$work/initrd" <<'SPEC'
# UKE_SUPER_FULL7344_INITRD_BEGIN
tar -xJf %{SOURCE208}
(cd full4;sha256sum -c --strict --quiet SHA256SUMS)
for proof_role in native initrd;do
 if test "$proof_role" = native;then archive=%{SOURCE209};else archive=%{SOURCE210};fi
 printf '%s  %s\n' "$(jq -er ".$proof_role.proof_sha256" %{SOURCE211})" "$archive" | sha256sum -c --strict --quiet -
 mkdir -p "native-generated/super734-$proof_role-proof"
 (cd "native-generated/super734-$proof_role-proof";rpm2cpio "$archive" | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
done
super_native=$PWD/native-generated/super734-native-proof/usr/share/uke-kernel-migration-check/super-root734
super_initrd=$PWD/native-generated/super734-initrd-proof/usr/share/uke-super-root-source-check
test "$(cat "$super_native/source-commit")" = "$(jq -er .native.source_commit %{SOURCE211})"
test "$(cat "$super_initrd/source-commit")" = "$(jq -er .initrd.source_commit %{SOURCE211})"
cmp "$super_native/SHA256SUMS" full4/root15/SHA256SUMS
cmp "$super_initrd/early/SHA256SUMS" full4/early/SHA256SUMS
jq -e '.prepared_parent_header_preserved and .actual_arm64_objects==2 and .exact_old_and_new_capability_notes' "$super_native/qualification.json"
jq -e '.original_physical_root_guard_preserved and .actual_dracut_units_verified and .new_codec_modes==4 and .no_python_payload' "$super_initrd/early/measurement.json"
bash full4/early/src/boot/super-root734/integrate-initrd.sh "$PWD/boot-recipe" "$PWD/full4/early/builder"
bash full4/early/src/boot/super-root734/apply-boot-profiles.sh "$PWD/boot-recipe"
# UKE_SUPER_FULL7344_INITRD_END
SPEC
cat > "$work/root" <<'SPEC'
# UKE_SUPER_FULL7344_ROOT_BEGIN
export LOCALVERSION=-%{senemos_build_release}-unstable
bash full4/root15/tests/native-super-root734.sh "$PWD" %{_uke_out}
sha256sum -c --strict --quiet "$super_native/source.sha256"
# UKE_SUPER_FULL7344_ROOT_END
SPEC
cat > "$work/profiles" <<'SPEC'
# UKE_SUPER_FULL7344_PROFILES_BEGIN
test "$(grep -c '^PASS: super root' super-root734-result/native-results.txt)" = 4
sha256sum -c --strict --quiet super-root734-result/source.sha256
bash full4/root15/tests/check-super-root-note734.sh %{_uke_out}/arch/arm64/boot/Image
test "$(stat -c%s %{_uke_out}/arch/arm64/boot/Image)" -le 96464896
for root_profile in userdata-super rescue;do
 %{_uke_out}/boot-image create-bootloader-compat %{_uke_out}/arch/arm64/boot/Image "%{_uke_out}/$root_profile.img" "$root_profile"
 %{_uke_out}/boot-image inspect "%{_uke_out}/$root_profile.img" | jq -e '.image_bytes==100663296 and .os_version_encoded==570425768 and .ramdisk_bytes==0 and .signature_bytes==0 and (.avb_footer_present|not)'
 %{_uke_out}/boot-image extract "%{_uke_out}/$root_profile.img" "%{_uke_out}/$root_profile-readback"
 cmp %{_uke_out}/arch/arm64/boot/Image "%{_uke_out}/$root_profile-readback"
 unlink "%{_uke_out}/$root_profile-readback"
done
jq -n --arg release '%{krel}' --arg raw "$(sha256sum %{_uke_out}/arch/arm64/boot/Image | cut -d' ' -f1)" \
 --arg userdata "$(sha256sum %{_uke_out}/userdata-super.img | cut -d' ' -f1)" \
 --arg rescue "$(sha256sum %{_uke_out}/rescue.img | cut -d' ' -f1)" \
 '{schema_version:1,kernel_release:$release,raw_image_sha256:$raw,capacity_bytes:100663296,
   seed_contract_bytes:4294967296,userdata_super_sha256:$userdata,rescue_sha256:$rescue,
   original_default_userdata_profile:true,kernel_capability_verified:true,physical_boot_tested:false}' > %{_uke_out}/super-profiles.json
unlink %{_uke_out}/userdata-super.img
unlink %{_uke_out}/rescue.img
# UKE_SUPER_FULL7344_PROFILES_END
SPEC
cat > "$work/check" <<'SPEC'
# UKE_SUPER_FULL7344_CHECK_BEGIN
test "$(grep -c '^PASS: super root' super-root734-result/native-results.txt)" = 4
sha256sum -c --strict --quiet super-root734-result/source.sha256
bash full4/root15/tests/check-super-root-note734.sh %{_uke_out}/arch/arm64/boot/Image
test "$(jq -er .raw_image_sha256 %{_uke_out}/super-profiles.json)" = "$(sha256sum %{_uke_out}/arch/arm64/boot/Image | cut -d' ' -f1)"
test "$(jq -er .kernel_release %{_uke_out}/super-profiles.json)" = '%{krel}'
# UKE_SUPER_FULL7344_CHECK_END
SPEC
cat > "$work/install" <<'SPEC'
# UKE_SUPER_FULL7344_INSTALL_BEGIN
super_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/super-root734
install -d "$super_support"
install -m644 %{SOURCE211} "$super_support/qualification.json"
install -m644 super-root734-result/{source.sha256,native-objects.sha256,native-results.txt} "$super_support/"
install -m644 boot-recipe/lock.json "$super_support/boot-source-lock.json"
install -Dm755 %{_uke_out}/boot-image %{buildroot}/usr/lib/senemos/kernel-updates/%{krel}/boot-image
install -m644 %{_uke_out}/super-profiles.json %{buildroot}/usr/lib/senemos/kernel-updates/%{krel}/
# UKE_SUPER_FULL7344_INSTALL_END
SPEC
awk -v root="$work" '
 function inject(name,path,line){path=root"/"name;while((getline line<path)>0)print line;close(path)}
 /^%changelog$/{history=1;print;print "# UKE_SUPER_FULL7344_HISTORY_BEGIN";print "* Mon Nov 16 2026 Uke contributors - 7.3.4-4";print "- Add explicit seed4 and read-only rescue boot profiles with qualified native callers and original Fedora initrd tools.";print "";print "# UKE_SUPER_FULL7344_HISTORY_END";next}
 !history{
  if($0=="%global senemos_build_release 3"){$0="%global senemos_build_release 4";release++}
  if($0=="%description"){inject("header");header++}
  if($0=="%package boot"){print;print "# UKE_SUPER_FULL7344_CONSUMER_BEGIN";print "Requires: uke-control(super-root-boot-v1) >= 1";print "# UKE_SUPER_FULL7344_CONSUMER_END";consumer++;next}
  if($0=="%description core"){print "# UKE_SUPER_FULL7344_CAPABILITY_BEGIN";print "Provides: uke-kernel(super-root-seed4-v1) = 1";print "# UKE_SUPER_FULL7344_CAPABILITY_END";capability++}
  if($0=="if test ! -e %{uke_boot_userspace}; then"){inject("initrd");initrd++}
  if($0=="bash abm734/packaging/native/verify-parent-source-tuple734.sh \"$PWD\" \"$native_proof/source.sha256\""){
   print "# UKE_SUPER_FULL7344_TUPLE_BEGIN";print "bash full4/packaging/native/verify-parent-source-tuple7344.sh \"$PWD\" \"$native_proof/source.sha256\"";print "# UKE_SUPER_FULL7344_TUPLE_END";tuple++;next
  }
  if(/^bash boot-recipe\/src\/boot\/build-payload[.]sh /){inject("root");print;inject("profiles");build++;next}
  if($0=="%check"){print;inject("check");checks++;next}
  if($0=="%install"){print;inject("install");installs++;next}
 }{print}
 END{if(release!=1||header!=1||consumer!=1||capability!=1||initrd!=1||tuple!=1||build!=1||checks!=1||installs!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_SUPER_FULL7344_TUPLE_END$/{print "bash abm734/packaging/native/verify-parent-source-tuple734.sh \"$PWD\" \"$native_proof/source.sha256\"";skip=0;next}
 /^# UKE_SUPER_FULL7344_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_SUPER_FULL7344_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="%global senemos_build_release 4"{$0="%global senemos_build_release 3"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == senemos-uke-linux-kernel-mainline-unstable-7.3.4-4.fc46 ]]
echo 'Full4 recipe retains the complete full3 inverse; new native/boot layers and consumer dependency remain explicit.'
