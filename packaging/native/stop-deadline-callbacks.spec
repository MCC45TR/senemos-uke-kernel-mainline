%global proof_release 1
Name: uke-kernel-migration-check
Version: 7.3.3
Release: %{proof_release}%{?dist}
Summary: Focused muted speaker STOP deadline callback evidence
License: GPL-2.0-only
Source0: stop-deadline-proof.tar.xz
ExclusiveArch: aarch64
BuildRequires: gcc
BuildRequires: clang
BuildRequires: compiler-rt
BuildRequires: libasan
BuildRequires: libubsan
BuildRequires: git-core
BuildRequires: coreutils
BuildRequires: gawk
BuildRequires: grep
BuildRequires: sed
BuildRequires: diffutils
BuildRequires: bash

%description
Build-only text evidence for the actual codec worker and muted STOP callback.
This focused proof does not admit a full kernel, an ABI, a boot or speakers.
It contains no runtime helper, service, calibration or device operation.

%prep
%setup -q -n stop-deadline-proof
sha256sum -c --strict --quiet SHA256SUMS

%build
test "$(uname -m)" = aarch64

set -o pipefail
bash packaging/native/copr-stop-deadline-callbacks.sh "$PWD/native-proof" | tee native-proof.txt

%check
test -s native-proof.txt

%install
install -d %{buildroot}%{_datadir}/uke-kernel-migration-check/stop-deadline
install -m644 native-proof.txt source-commit SCOPE.txt %{buildroot}%{_datadir}/uke-kernel-migration-check/stop-deadline/

%files
%license LICENSE
%{_datadir}/uke-kernel-migration-check/stop-deadline/

%changelog
* Sat Nov 07 2026 Uke contributors - 7.3.3
- Exercise a separate finite muted STOP deadline across timer rates and wrap.
- Retain active faults, mute readback, original callbacks and negative controls.
