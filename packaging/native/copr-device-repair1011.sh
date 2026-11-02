#!/usr/bin/env bash
# COPR only: preserve the installed1010 driver sources in a fresh rollback ABI.
set -Eeuo pipefail
trap 'status=$?; printf "Source preparation failed at line %s (exit %s)\n" "$LINENO" "$status" >&2; exit "$status"' ERR
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
for project in uke-linux-unstable uke-linux-test uke-linux; do
 offset=0
 while ((offset < 10000)); do
  curl -fLsS --max-time 45 --get --data-urlencode ownername=mcc45tr \
   --data-urlencode "projectname=$project" --data-urlencode packagename=senemos-uke-linux-kernel-mainline \
   --data-urlencode limit=100 --data-urlencode "offset=$offset" \
   https://copr.fedorainfracloud.org/api_3/build/list > "$stage/builds.json"
  jq -e '(.items|type)=="array" and all(.items[];
    ((.source_package.version // "")|test("^7[.]3[.]1-1011([.]|$)"))|not)' "$stage/builds.json" >/dev/null
  count=$(jq -er '.items|length' "$stage/builds.json")
  ((count < 100)) && break
  offset=$((offset + 100))
 done
 ((offset < 10000))
done
# Build11240834 retained this exact production source and corrected only the
# duplicate upstream-enum fixture (commit517030ed). Reproduce that correction
# without downloading or substituting an unrelated main-branch kernel input.
curl -fLsS --retry 2 --proto '=https' --proto-redir '=https' \
 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable:custom:o82-abm-20261101/srpm-builds/11240670/senemos-uke-linux-kernel-mainline-7.3.1-1010.src.rpm -o "$stage/base.src.rpm"
printf '%s  %s\n' 834165e195638d8b975a57a5af3b9a4087a90b2f38a698822ad45bac5aa6386d "$stage/base.src.rpm" | sha256sum -c -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/base.src.rpm") == senemos-uke-linux-kernel-mainline-7.3.1-1010 ]]
rpm2cpio "$stage/base.src.rpm" > "$stage/base.cpio"
cpio -t --quiet < "$stage/base.cpio" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
mkdir -p "$output" "$stage/unpacked"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/base.cpio")
spec=$output/senemos-uke-linux-kernel-mainline.spec
archive=senemos-native-profile-7.3.1.tar.xz
find "$output" -maxdepth 1 -type f ! -name "${spec##*/}" ! -name "$archive" \
 -print0 | sort -z | xargs -0 sha256sum > "$stage/retained.sha256"
tar -tJf "$output/$archive" > "$stage/archive.entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/archive.entries"
tar -xJf "$output/$archive" -C "$stage/unpacked"
profile=$stage/unpacked/native-profile
(cd "$profile"; sha256sum --check --strict --quiet SHA256SUMS)
cp "$profile/source-composition.json" "$profile/source-composition-before1011.json"
cp "$profile/tests/o82-panel-contract.sh" "$profile/tests/o82-panel-contract-before1010.sh"
[[ $(grep -Fc 'MIPI_DSI_DCS_SHORT_WRITE_PARAM=0x15,' "$profile/tests/o82-panel-contract.sh") == 1 ]]
sed '/MIPI_DSI_DCS_SHORT_WRITE_PARAM=0x15,/d' "$profile/tests/o82-panel-contract.sh" > "$stage/expected-test.sh"
cmp "$stage/expected-test.sh" "$owner/tests/o82-panel-contract.sh"
install -m644 "$owner/tests/o82-panel-contract.sh" "$profile/tests/o82-panel-contract.sh"
commit=$(git -C "$owner" rev-parse HEAD)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" '. + {source_commit:$commit,
 source_mode:"retained1010-production-with-versioned-local-video",parent_copr_build:11240670,
 parent_srpm_sha256:"834165e195638d8b975a57a5af3b9a4087a90b2f38a698822ad45bac5aa6386d",
 accepted_kernel_copr_build:11240834,accepted_kernel_source_commit:"517030ed3d8669164de005a8c55046666f195268",
 parent_composition:"source-composition-before1011.json",kernel_release:"7.3.1-1011",rpm_revision:"1011",
 kernel_driver_source_unchanged:true,firmware_payload_included:false,device_local_video_import:true,
 automatic_policy_unchanged:true,physical_acceptance:false}' "$profile/source-composition-before1011.json" > "$profile/source-composition.json"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$archive" -C "$stage/unpacked" native-profile
[[ $(grep -Fxc '%global senemos_build_release 1010' "$spec") == 1 ]]
[[ $(grep -Fxc '%posttrans boot -p /bin/sh' "$spec") == 1 ]]
[[ $(grep -Fxc 'Requires: uke-kernel-update >= 1.8.13' "$spec") == 1 ]]
awk '
 /^%global senemos_build_release 1010$/ {$0="%global senemos_build_release 1011"}
 /^Requires: uke-kernel-update >= 1[.]8[.]13$/ {
  print "Requires: uke-kernel-update >= 1.8.30"
  print "Requires: uke-kernel-update(inactive-slot-no-image-backup-v1) >= 1"
  print "Requires: uke-kernel-update(device-local-video-import-v1) >= 1";next
 }
 /^%changelog$/ {
  print;print "* Mon Nov 02 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1011"
  print "- Retain installed1010 drivers and scope local video firmware to the new kernel ABI."
  print "- Require image-copy-free inactive-slot delivery without requesting reboot."
  print "";next
 }
 /^CC=clang bash native-profile\/tests\/o82-panel-contract.sh / {
  print "if CC=clang bash native-profile/tests/o82-panel-contract-before1010.sh native-profile/src/display/panel-xiaomi-o82.c native-profile/src/display/o82-data.h \"$PWD\" > %{_uke_out}/o82-before1010-negative.log 2>&1; then cat %{_uke_out}/o82-before1010-negative.log; exit 1; fi"
  print "grep -Fq \"redefinition of enumerator '\''MIPI_DSI_DCS_SHORT_WRITE_PARAM'\''\" %{_uke_out}/o82-before1010-negative.log"
 }
 /^test -z "\$\(find %\{buildroot\} -type f / {
  print "install -d %{buildroot}/usr/lib/firmware/%{krel}/qcom/uke"
 }
 {print}
 /^%posttrans boot -p \/bin\/sh$/ {
  print "/usr/bin/uke-kernel-update import-oem-video %{krel} || exit 1"
 }
 /^\/usr\/lib\/firmware\/%\{krel\}\/$/ {
  print "%ghost %attr(0644,root,root) /usr/lib/firmware/%{krel}/qcom/uke/vpu30_2v.mbn"
 }
' "$spec" > "$stage/next.spec"
mv "$stage/next.spec" "$spec"
[[ $(grep -Fxc 'install -d %{buildroot}/usr/lib/firmware/%{krel}/qcom/uke' "$spec") == 1 ]]
[[ $(grep -Fxc '/usr/bin/uke-kernel-update import-oem-video %{krel} || exit 1' "$spec") == 1 ]]
[[ $(grep -Fxc '%ghost %attr(0644,root,root) /usr/lib/firmware/%{krel}/qcom/uke/vpu30_2v.mbn' "$spec") == 1 ]]
sha256sum -c "$stage/retained.sha256"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{VERSION}-%{RELEASE}' "$spec") == 7.3.1-1011 ]]
[[ $(grep -Fxc '%global krel %{version}-%{senemos_build_release}' "$spec") == 1 ]]
