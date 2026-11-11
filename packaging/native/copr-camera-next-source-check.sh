#!/usr/bin/env bash
# COPR only: qualify the same assembly used by the following full kernel.
set -Eeuo pipefail
trap 'rc=$?; printf "Next-camera source-check factory failed at line%s/exit%s\n" "$LINENO" "$rc" >&2; exit "$rc"' ERR
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
bash "$owner/packaging/native/refuse-published-release.sh" uke-camera-next-source-check 7.3.1-2
bash "$owner/packaging/native/assemble-camera-next731.sh" "$output"
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
spec=$output/uke-camera-next-source-check.spec
! grep -Eq '^Source9[01]:' "$parent"
install -m644 "$parent" "$output/camera-next-production.spec.txt"
awk '
 /^%description/ {exit}
 /^Name:/ {$0="Name: uke-camera-next-source-check"}
 /^Release:/ {$0="Release: 2%{?dist}"}
 /^Summary:/ {$0="Summary: Cumulative camera GCC and all qualified postfreeze source checks"}
 /^(Requires|Provides|Recommends|Conflicts|Obsoletes|Supplements|Suggests|Enhances)(\([^)]*\))?:/ {next}
 {print}
' "$parent" > "$spec"
cat >> "$spec" <<'SPEC'
Source90: camera-next-check-inputs.tar.xz
Source91: camera-next-production.spec.txt

%description
Qualify the complete production12203 inputs with governor, speaker observer and
inclusion gates, pogo, corrected SSC early reports and exact OEM camera GCC
configuration. Preserve all original preparation, config comparisons and hardware
gates. Run actual callbacks and real native objects without an Image or final
module. Package only text evidence. No kernel release or device operation.

SPEC
awk '/^%prep$/ {emit=1} /^%build$/ {exit} emit {print}' "$parent" >> "$spec"
cat >> "$spec" <<'SPEC'
tar -xJf %{SOURCE90}

%build
set -o pipefail
bash union-addon/packaging/native/check-postfreeze-union.sh "$PWD" %{_uke_out} \
 | tee %{_topdir}/camera-next-checks.txt
bash native-profile/packaging/native/check-camera-next731.sh "$PWD" %{_uke_out} prepared \
 | tee -a %{_topdir}/camera-next-checks.txt
bash ssc-addon/packaging/native/check-ssc-early731.sh "$PWD" %{_uke_out} \
 | tee -a %{_topdir}/camera-next-checks.txt
bash native-profile/tests/camera-gcc-config731-object.sh "$PWD" "$PWD/camera-gcc-object" native-profile/native.config \
 | tee -a %{_topdir}/camera-next-checks.txt

%install
install -Dm644 %{_topdir}/camera-next-checks.txt %{buildroot}%{_docdir}/%{name}/checks.txt
install -m644 source-commit %{buildroot}%{_docdir}/%{name}/source-commit
install -m644 native-profile/source-composition.json %{buildroot}%{_docdir}/%{name}/check-view-composition.json
install -m644 native-profile/manifests/camera-next-cohort731-20261105.json %{buildroot}%{_docdir}/%{name}/source-manifest.json
install -m644 %{SOURCE91} %{buildroot}%{_docdir}/%{name}/production-spec.txt

%check
test -s %{buildroot}%{_docdir}/%{name}/checks.txt
test ! -e %{_uke_out}/arch/arm64/boot/Image
test ! -e camera-gcc-object/arch/arm64/boot/Image
test -z "$(find %{_uke_out} camera-gcc-object -type f -name '*.ko' -print -quit)"

%files
%license COPYING
%{_docdir}/%{name}/*

%changelog
* Thu Nov 05 2026 Uke contributors - 7.3.1-2
- Qualify all camera/peer layers on the complete latest production inputs.
- Preserve original full-config comparisons and early audio checks.
- Require source/callback/object evidence without producing a kernel candidate.
SPEC
unlink "$parent"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$spec") == uke-camera-next-source-check-7.3.1-2 ]]
printf 'Complete next-camera source-only check prepared; no Image, kernel NVR or target change\n'
