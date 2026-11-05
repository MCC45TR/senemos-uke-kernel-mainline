#!/usr/bin/env bash
# COPR only: exact production12204 prep, independent source/fault/object checks.
set -Eeuo pipefail
trap 'rc=$?; printf "Hall startup source preparation failed at line%s/exit%s\n" "$LINENO" "$rc" >&2; exit "$rc"' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
bash "$owner/packaging/native/refuse-published-release.sh" uke-hall-startup-check 7.3.1-1
[[ $(curl -q -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11263248 | jq -er .state) == succeeded ]]
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
manifest=$owner/manifests/hall-startup-20261105.json
while IFS=$'\t' read -r path digest; do
    [[ $path =~ ^(src|tests|docs|patches)/[a-zA-Z0-9_.,/-]+$ && $path != *..* ]]
    printf '%s  %s\n' "$digest" "$owner/$path" | sha256sum -c --strict -
done < <(jq -er '.inputs[]|[.path,.sha256]|@tsv' "$manifest")
curl -q -fLsS --retry 2 --max-time 600 --proto '=https' --proto-redir '=https' \
    "$(jq -er .parent.url "$manifest")" -o "$stage/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent.sha256 "$manifest")" "$stage/parent.src.rpm" | sha256sum -c --strict -
actual_parent=$(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm")
expected_parent=$(jq -er .parent.rpm_nvr "$manifest")
[[ $actual_parent == "$expected_parent" ]] || {
    printf 'Refused raw SRPM NVR: actual=%s expected=%s\n' "$actual_parent" "$expected_parent" >&2
    exit 1
}
# Source-worker SRPM is unsigned; verify its whole hash and RPM digests only.
rpmkeys --checksig --nosignature --verbose "$stage/parent.src.rpm"
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
mkdir -p "$output"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
test -f "$parent"
! grep -q '^Source90:' "$parent"
find "$output" -maxdepth 1 -type f ! -name "${parent##*/}" -print0 | \
    sort -z | xargs -0 sha256sum > "$stage/retained.sha256"
mapfile -t assets < <(jq -er '.inputs[].path' "$manifest")
git -C "$owner" archive --prefix=hall-startup-addon/ HEAD "${assets[@]}" \
    manifests/hall-startup-20261105.json LICENSE LICENSES/GPL-2.0-only.txt | tar -xf - -C "$stage"
git -C "$owner" rev-parse HEAD > "$stage/hall-startup-addon/source-commit"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/uke-hall-startup-addon.tar.xz" -C "$stage" hall-startup-addon
spec=$output/uke-hall-startup-check.spec
awk '
 /^%description/ {exit}
 /^Name:/ {$0="Name: uke-hall-startup-check"}
 /^Release:/ {$0="Release: 1%{?dist}"}
 /^Summary:/ {$0="Summary: Uke Hall initial-state source qualification"}
 /^(Requires|Provides|Recommends|Conflicts|Obsoletes)(\([^)]*\))?:/ {next}
 {print}
' "$parent" > "$spec"
cat >> "$spec" <<'SPEC'
Source90: uke-hall-startup-addon.tar.xz

%description
Qualify initial-state retries on complete production12204 without changing
its original preparation or retained features. Execute actual callbacks
with late stationary closure, fault controls and a real AArch64 input object.
Package only text receipts and licenses. Physical closed-cover boot, wake
and firmware publication remain separate tests.

SPEC
awk '/^%prep$/ {emit=1} /^%build$/ {exit} emit {print}' "$parent" >> "$spec"
cat >> "$spec" <<'SPEC'
tar -xJf %{SOURCE90}
cp drivers/input/misc/qcom-smp2p-switch.c native-generated/hall-before-startup.c
bash hall-startup-addon/src/input/apply-smp2p-switch-startup.sh "$PWD"
sha256sum drivers/input/misc/qcom-smp2p-switch.c > native-generated/hall-startup-repeat.sha256
bash hall-startup-addon/src/input/apply-smp2p-switch-startup.sh "$PWD"
sha256sum -c --strict native-generated/hall-startup-repeat.sha256

%build
set -o pipefail
for compiler in gcc clang; do
 CC=$compiler bash hall-startup-addon/tests/hall-startup-contract.sh \
  drivers/input/misc/qcom-smp2p-switch.c | tee -a %{_topdir}/hall-startup-checks.txt
 CC=$compiler HALL_TEST_FLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
  bash hall-startup-addon/tests/hall-startup-contract.sh \
  drivers/input/misc/qcom-smp2p-switch.c | tee -a %{_topdir}/hall-startup-checks.txt
done
bash hall-startup-addon/tests/hall-startup-controls.sh "$PWD" \
 | tee -a %{_topdir}/hall-startup-checks.txt
bash hall-startup-addon/tests/hall-startup-object.sh "$PWD" "$PWD/hall-startup-object" native-profile/native.config \
 | tee -a %{_topdir}/hall-startup-checks.txt
sha256sum drivers/input/misc/qcom-smp2p-switch.c native-generated/hall-before-startup.c \
 | tee -a %{_topdir}/hall-startup-checks.txt

%install
install -Dm644 %{_topdir}/hall-startup-checks.txt %{buildroot}%{_docdir}/%{name}/checks.txt
install -m644 hall-startup-addon/source-commit %{buildroot}%{_docdir}/%{name}/source-commit
install -m644 hall-startup-addon/manifests/hall-startup-20261105.json %{buildroot}%{_docdir}/%{name}/source-manifest.json
install -m644 native-profile/source-composition.json %{buildroot}%{_docdir}/%{name}/parent-composition.json

%check
test -s %{buildroot}%{_docdir}/%{name}/checks.txt
test ! -e arch/arm64/boot/Image
test ! -e hall-startup-object/arch/arm64/boot/Image
test ! -e hall-startup-object/drivers/input/misc/qcom-smp2p-switch.ko

%files
%license hall-startup-addon/LICENSE hall-startup-addon/LICENSES/GPL-2.0-only.txt
%{_docdir}/%{name}/checks.txt
%{_docdir}/%{name}/source-commit
%{_docdir}/%{name}/source-manifest.json
%{_docdir}/%{name}/parent-composition.json

%changelog
* Thu Nov 05 2026 Uke contributors - 7.3.1-1
- Retry unavailable initial Hall state while preserving selective open wake.
- Require late closed-state, invalid-pair, timeout, PM and cleanup controls.
- Retain complete production12204 preparation and compile the actual input object.
SPEC
sha256sum -c --strict --quiet "$stage/retained.sha256"
unlink "$parent"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$spec") == uke-hall-startup-check-7.3.1-1 ]]
printf 'Hall startup independent source check prepared; no full-kernel revision or target change\n'
