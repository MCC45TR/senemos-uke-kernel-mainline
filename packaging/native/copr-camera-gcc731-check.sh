#!/usr/bin/env bash
# COPR only: exact production12203 prep, independent source/fault/object checks.
set -Eeuo pipefail
trap 'rc=$?; printf "Camera GCC source preparation failed at line%s/exit%s\n" "$LINENO" "$rc" >&2; exit "$rc"' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
bash "$owner/packaging/native/refuse-published-release.sh" uke-camera-gcc-check 7.3.1-2
[[ $(curl -q -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11262313 | jq -er .state) == succeeded ]]
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
manifest=$owner/manifests/camera-gcc-config731-20261105.json
while IFS=$'\t' read -r path digest; do
    [[ $path =~ ^(src|tests|docs)/[a-zA-Z0-9_.,/-]+$ && $path != *..* ]]
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
git -C "$owner" archive --prefix=camera-gcc-addon/ HEAD "${assets[@]}" \
    manifests/camera-gcc-config731-20261105.json LICENSE LICENSES/GPL-2.0-only.txt | tar -xf - -C "$stage"
git -C "$owner" rev-parse HEAD > "$stage/camera-gcc-addon/source-commit"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/uke-camera-gcc-addon.tar.xz" -C "$stage" camera-gcc-addon
spec=$output/uke-camera-gcc-check.spec
awk '
 /^%description/ {exit}
 /^Name:/ {$0="Name: uke-camera-gcc-check"}
 /^Release:/ {$0="Release: 2%{?dist}"}
 /^Summary:/ {$0="Summary: Exact Uke camera GCC configuration source qualification"}
 /^(Requires|Provides|Recommends|Conflicts|Obsoletes)(\([^)]*\))?:/ {next}
 {print}
' "$parent" > "$spec"
cat >> "$spec" <<'SPEC'
Source90: uke-camera-gcc-addon.tar.xz

%description
Qualify the precise OEM camera GCC configuration delta on the complete
production12203 source. Preserve its original preparation and early gates,
then execute the actual probe, original missing-gate negative control,
failure/retention mutants and real AArch64 GCC object compilation.
Only text receipts/licenses are packaged; no Image, module or kernel RPM.
This check does not establish electrical camera access or fitted calibration.

SPEC
awk '/^%prep$/ {emit=1} /^%build$/ {exit} emit {print}' "$parent" >> "$spec"
cat >> "$spec" <<'SPEC'
tar -xJf %{SOURCE90}
bash camera-gcc-addon/src/camera/provider/apply-gcc-config731.sh "$PWD"
sha256sum drivers/clk/qcom/gcc-cliffs.c native-generated/gcc-before-camera-config.c > native-generated/gcc-repeat.sha256
bash camera-gcc-addon/src/camera/provider/apply-gcc-config731.sh "$PWD"
sha256sum -c --strict native-generated/gcc-repeat.sha256

%build
set -o pipefail
for compiler in g++ clang++; do
 CXX=$compiler CAMERA_GCC_MUTATIONS=1 \
  bash camera-gcc-addon/tests/camera-gcc-config731-contract.sh \
   drivers/clk/qcom/gcc-cliffs.c native-generated/gcc-before-camera-config.c \
   | tee -a %{_topdir}/camera-gcc-checks.txt
 CXX=$compiler CAMERA_GCC_TEST_FLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
  bash camera-gcc-addon/tests/camera-gcc-config731-contract.sh \
   drivers/clk/qcom/gcc-cliffs.c native-generated/gcc-before-camera-config.c \
   | tee -a %{_topdir}/camera-gcc-checks.txt
done
bash camera-gcc-addon/tests/camera-gcc-config731-object.sh "$PWD" "$PWD/camera-gcc-object" native-profile/native.config \
 | tee -a %{_topdir}/camera-gcc-checks.txt
sha256sum drivers/clk/qcom/gcc-cliffs.c native-generated/gcc-before-camera-config.c \
 | tee -a %{_topdir}/camera-gcc-checks.txt

%install
install -Dm644 %{_topdir}/camera-gcc-checks.txt %{buildroot}%{_docdir}/%{name}/checks.txt
install -m644 camera-gcc-addon/source-commit %{buildroot}%{_docdir}/%{name}/source-commit
install -m644 camera-gcc-addon/manifests/camera-gcc-config731-20261105.json %{buildroot}%{_docdir}/%{name}/source-manifest.json
install -m644 native-profile/source-composition.json %{buildroot}%{_docdir}/%{name}/parent-composition.json

%check
test -s %{buildroot}%{_docdir}/%{name}/checks.txt
test ! -e arch/arm64/boot/Image
test ! -e camera-gcc-object/arch/arm64/boot/Image
test ! -e camera-gcc-object/drivers/clk/qcom/gcc-cliffs.ko

%files
%license camera-gcc-addon/LICENSE camera-gcc-addon/LICENSES/GPL-2.0-only.txt
%{_docdir}/%{name}/checks.txt
%{_docdir}/%{name}/source-commit
%{_docdir}/%{name}/source-manifest.json
%{_docdir}/%{name}/parent-composition.json

%changelog
* Thu Nov 05 2026 Uke contributors - 7.3.1-2
- Check the measured raw source-worker NVR, independently of native binary dist.
- Restore only the exact OEM three camera configuration writes before GCC publication.
- Preserve video and full12203 preparation, source/config/DT and hardware admission.
- Require actual original failure, fault/mutation controls and AArch64 object.
SPEC
sha256sum -c --strict --quiet "$stage/retained.sha256"
unlink "$parent"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$spec") == uke-camera-gcc-check-7.3.1-2 ]]
printf 'Camera GCC independent source check prepared; no full-kernel revision or target change\n'
