%global debug_package %{nil}
%global proof_release 1
Name: uke-kernel-migration-check
Version: 7.3.3
Release: %{proof_release}%{?dist}
Summary: Bounded FS19xx enable-query parser and transport evidence
License: GPL-2.0-only
Source0: speaker-readback-proof.tar.xz
ExclusiveArch: aarch64
BuildRequires: gcc clang compiler-rt libasan libubsan bash coreutils gawk sed

%description
Focused build-only evidence for fixed in-band AudioReach enable queries and
their production transport with independent synthetic GPR providers. This is
not a complete kernel-object build, a limiter test or authorization for gain243.
Only text evidence is packaged; no executable, service or unit data is shipped.

%prep
%setup -q -n speaker-readback-proof
sha256sum -c --strict --quiet SHA256SUMS

%build
test "$(uname -m)" = aarch64
set -euo pipefail
for cc in gcc clang; do
 for san in 0 1; do
  CC="$cc" SANITIZE="$san" bash tests/audio-fs19xx-readback.sh
 done
done | tee native-proof.txt

%check
test -s native-proof.txt

%install
install -d %{buildroot}%{_datadir}/uke-kernel-migration-check/speaker-readback
install -m644 native-proof.txt source-commit SCOPE.txt manifests/speaker-enable-readback-20261107.json %{buildroot}%{_datadir}/uke-kernel-migration-check/speaker-readback/

%files
%license LICENSE
%{_datadir}/uke-kernel-migration-check/speaker-readback/

%changelog
* Sat Nov 07 2026 Uke contributors - 7.3.3
- Test fixed in-band queries, strict reply identity and bounded teardown.
- Retain gain223 and separate enable readback from physical protection.
