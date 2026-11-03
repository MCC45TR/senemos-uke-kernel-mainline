#!/usr/bin/env bash
# COPR-only retained production build; no camera or DT activation.
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
    ((.source_package.version // "")|test("^7[.]3[.]1-1013([.]|$)"))|not)' "$stage/builds.json" >/dev/null
  count=$(jq -er '.items|length' "$stage/builds.json")
  ((count < 100)) && break
  offset=$((offset + 100))
 done
 ((offset < 10000))
done
curl -fLsS --retry 2 --proto '=https' --proto-redir '=https' \
 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11246385/senemos-uke-linux-kernel-mainline-7.3.1-1011.src.rpm -o "$stage/base.src.rpm"
printf '%s  %s\n' 84915ef98a26df47bc8f223e3751b160e40eba3c447f433fbe13b2097d6a7146 "$stage/base.src.rpm" | sha256sum -c -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/base.src.rpm") == senemos-uke-linux-kernel-mainline-7.3.1-1011 ]]
# COPR's retained SRPM is unsigned. Pin its header and payload digest, then
# verify both over the complete remotely downloaded source RPM. This is not
# the signature policy for built binary packages or device installation.
[[ $(rpm -qp --qf '%{SHA256HEADER}' "$stage/base.src.rpm") == 1a5eea8444659804be066cd379c6021c067455cd9a6a9899c3857962a128a46a ]]
[[ $(rpm -qp --qf '%{PAYLOADSHA256}' "$stage/base.src.rpm") == 914461682948289e960221fb64289e32ca6b6b2bf456357744afb90d591b6a42 ]]
rpmkeys --checksig --nosignature --verbose "$stage/base.src.rpm"
parent_sha=$(sha256sum "$stage/base.src.rpm" | cut -d ' ' -f1)
printf 'Verified retained parent SRPM SHA256: %s\n' "$parent_sha"
rpm2cpio "$stage/base.src.rpm" > "$stage/base.cpio"
cpio -t --quiet < "$stage/base.cpio" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
mkdir -p "$output" "$stage/unpacked"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/base.cpio")
spec=$output/senemos-uke-linux-kernel-mainline.spec
printf '%s  %s\n' d48ae2fc7af05df331c15068e73eb77c4c50c203a57b7cdc6b1ff1e9509a334b "$spec" | sha256sum -c -
archive=senemos-native-profile-7.3.1.tar.xz
find "$output" -maxdepth 1 -type f ! -name "${spec##*/}" ! -name "$archive" \
 -print0 | sort -z | xargs -0 sha256sum > "$stage/retained-sources.sha256"
tar -tJf "$output/$archive" > "$stage/archive.entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/archive.entries"
tar -xJf "$output/$archive" -C "$stage/unpacked"
profile=$stage/unpacked/native-profile
(cd "$profile"; sha256sum --check --strict --quiet SHA256SUMS
 find . -type f ! -name SHA256SUMS ! -name source-commit ! -name source-composition.json \
  -print0 | sort -z | xargs -0 sha256sum > "$stage/retained-profile.sha256")
overlays=(src/camera/provider/0001-gdsc-registration-unwind731.patch
 src/camera/provider/README731.md tests/gdsc-registration731-contract.sh
 tests/fixtures/gdsc-registration731.c)
for path in "${overlays[@]}"; do
 test ! -e "$profile/$path"
 install -Dm644 "$owner/$path" "$profile/$path"
done
cp "$profile/source-composition.json" "$profile/source-composition-before1013.json"
commit=$(git -C "$owner" rev-parse HEAD)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --arg parent_sha "$parent_sha" '. + {
 source_commit:$commit,source_mode:"retained1011-with-gdsc-registration-unwind",
 parent_copr_build:11246385,parent_srpm_sha256:$parent_sha,
 parent_srpm_header_sha256:"1a5eea8444659804be066cd379c6021c067455cd9a6a9899c3857962a128a46a",
 parent_composition:"source-composition-before1013.json",kernel_release:"7.3.1-1013",rpm_revision:"1013",
 changed_kernel_files:["drivers/clk/qcom/gdsc.c"],camera_dt_activation:false,
 firmware_payload_included:false,automatic_policy_unchanged:true,physical_acceptance:false
 }' "$profile/source-composition-before1013.json" > "$profile/source-composition.json"
(cd "$profile"; sha256sum -c "$stage/retained-profile.sha256"
 find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$archive" -C "$stage/unpacked" native-profile
for line in '%global senemos_build_release 1011' 'bash native-profile/prepare.sh "$PWD"' 'uke_build_start=$SECONDS' '%check'; do
 [[ $(grep -Fxc "$line" "$spec") == 1 ]]
done
awk '
 /^%global senemos_build_release 1011$/ {$0="%global senemos_build_release 1013"}
 /^bash native-profile\/prepare.sh "\$PWD"$/ {
  print
  print "cp drivers/clk/qcom/gdsc.c native-generated/gdsc-before1013.c"
  print "git apply --check native-profile/src/camera/provider/0001-gdsc-registration-unwind731.patch"
  print "git apply native-profile/src/camera/provider/0001-gdsc-registration-unwind731.patch"
  next
 }
 /^uke_build_start=\$SECONDS$/ {
  print
  print "CC=clang bash native-profile/tests/gdsc-registration731-contract.sh native-generated/gdsc-before1013.c drivers/clk/qcom/gdsc.h drivers/clk/qcom/gdsc.c"
  next
 }
 /^%check$/ {
  print
  print "grep -Fx CONFIG_QCOM_GDSC=y %{_uke_out}/.config"
  print "test -s %{_uke_out}/drivers/clk/qcom/gdsc.o"
  print "llvm-readelf -h %{_uke_out}/drivers/clk/qcom/gdsc.o | grep -E '\''Machine:.*AArch64'\''"
  next
 }
 /^%changelog$/ {
  print; print "* Tue Nov 03 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1013"
  print "- Unwind initialized genpds after later registration failures."
  print "- Retain the production drivers and DT without activating a camera provider."
  print ""; next
 }
 {print}
' "$spec" > "$stage/next.spec"
mv "$stage/next.spec" "$spec"
sha256sum -c "$stage/retained-sources.sha256"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{VERSION}-%{RELEASE}' "$spec") == 7.3.1-1013 ]]
