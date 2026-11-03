#!/usr/bin/env bash
# COPR only: retain1011 and change only native touch recovery and its fixtures.
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
    ((.source_package.version // "")|test("^7[.]3[.]1-1019([.]|$)"))|not)' "$stage/builds.json" >/dev/null
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
[[ $(rpm -qp --qf '%{SHA256HEADER}' "$stage/base.src.rpm") == 1a5eea8444659804be066cd379c6021c067455cd9a6a9899c3857962a128a46a ]]
[[ $(rpm -qp --qf '%{PAYLOADSHA256}' "$stage/base.src.rpm") == 914461682948289e960221fb64289e32ca6b6b2bf456357744afb90d591b6a42 ]]
rpmkeys --checksig --nosignature --verbose "$stage/base.src.rpm"
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
  ! -path './src/input/nt36532-uke-spi.c' ! -path './tests/touch-transport.c' \
  ! -path './tests/touch-transport-contract.sh' -print0 | sort -z | xargs -0 sha256sum > "$stage/retained-profile.sha256")
printf '%s  %s\n' ec80a9f5e7c72b04e2bb475d96ad3b37e8920ac1905b4ef6f63574892f446aab "$profile/src/input/nt36532-uke-spi.c" | sha256sum -c -
test ! -e "$profile/tests/fixtures/touch-before-recovery.c"
install -Dm644 "$profile/src/input/nt36532-uke-spi.c" "$profile/tests/fixtures/touch-before-recovery.c"
for path in src/input/nt36532-uke-spi.c tests/touch-transport.c tests/touch-transport-contract.sh; do
 install -m644 "$owner/$path" "$profile/$path"
done
cp "$profile/source-composition.json" "$profile/source-composition-before1019.json"
commit=$(git -C "$owner" rev-parse HEAD)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" '. + {
 source_commit:$commit,source_mode:"retained1011-with-bounded-native-touch-recovery",
 parent_copr_build:11246385,parent_srpm_sha256:"84915ef98a26df47bc8f223e3751b160e40eba3c447f433fbe13b2097d6a7146",
 parent_composition:"source-composition-before1019.json",kernel_release:"7.3.1-1019",rpm_revision:"1019",
 kernel_driver_source_unchanged:false,
 changed_kernel_files:["drivers/input/touchscreen/nt36532-uke/nt36532-uke-spi.c"],
 touch_recovery_attempts_per_powered_epoch:1,firmware_payload_included:false,
 automatic_policy_unchanged:true,physical_acceptance:false
 }' "$profile/source-composition-before1019.json" > "$profile/source-composition.json"
(cd "$profile"; sha256sum -c "$stage/retained-profile.sha256"
 find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$archive" -C "$stage/unpacked" native-profile
for line in '%global senemos_build_release 1011' 'bash native-profile/prepare.sh "$PWD"' 'uke_build_start=$SECONDS'; do
 [[ $(grep -Fxc "$line" "$spec") == 1 ]]
done
awk '
 /^%global senemos_build_release 1011$/ {$0="%global senemos_build_release 1019"}
 /^bash native-profile\/prepare.sh "\$PWD"$/ {
  print
  print "cmp native-profile/src/input/nt36532-uke-spi.c drivers/input/touchscreen/nt36532-uke/nt36532-uke-spi.c"
  next
 }
 /^uke_build_start=\$SECONDS$/ {
  print "ulimit -c 0"
  print "set +e"
  print "UKE_TOUCH_SOURCE=\"$PWD/native-profile/tests/fixtures/touch-before-recovery.c\" CC=clang bash native-profile/tests/touch-transport-contract.sh > %{_uke_out}/touch-recovery-before.log 2>&1"
  print "touch_before_status=$?"
  print "set -e"
  print "if test \"$touch_before_status\" != 134; then cat %{_uke_out}/touch-recovery-before.log; exit 1; fi"
  print "grep -Fq '\''!touch.fault && touch.recovery_attempts == 1'\'' %{_uke_out}/touch-recovery-before.log"
  print "echo '\''Original touch driver cannot recover a transient read fault (expected status134)'\''"
  print "UKE_TOUCH_SANITIZE=1 CC=clang bash native-profile/tests/touch-transport-contract.sh"
 }
 /^%changelog$/ {
  print
  print "* Tue Nov 03 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1019"
  print "- Permit one verified native touch recovery per powered lifecycle."
  print "- Re-arm on panel/PM restoration and expose value-free diagnostic counters."
  print ""
  next
 }
 {print}
' "$spec" > "$stage/next.spec"
mv "$stage/next.spec" "$spec"
sha256sum -c "$stage/retained-sources.sha256"
[[ $(grep -Fxc 'UKE_TOUCH_SANITIZE=1 CC=clang bash native-profile/tests/touch-transport-contract.sh' "$spec") == 1 ]]
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{VERSION}-%{RELEASE}' "$spec") == 7.3.1-1019 ]]
