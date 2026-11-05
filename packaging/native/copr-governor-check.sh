#!/usr/bin/env bash
# Produce a text-receipt check package in COPR; never a kernel or target update.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
root=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?Pass the remote source result directory}")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/uke-governor-check-1.0"
git -C "$root" archive HEAD packaging/native/native.config manifests/native-linux-7.3.1.json \
    tests/governor-config-contract.sh packaging/native/check-governor-native-objects.sh \
    LICENSE LICENSES/GPL-2.0-only.txt | tar -xf - -C "$stage/uke-governor-check-1.0"
# Frozen cumulative input; the source worker fetches this exact object too.
git -C "$root" show d1a7a35247eb76bdcc323b42b3ff46806c7fdccf:packaging/native/native.config \
    > "$stage/uke-governor-check-1.0/packaging/native/native-before.config"
tar --sort=name --mtime=@1793836800 --owner=0 --group=0 --numeric-owner \
    -czf "$output/uke-governor-check-1.0.tar.gz" -C "$stage" uke-governor-check-1.0
cat > "$output/uke-governor-check.spec" <<'SPEC'
Name: uke-governor-check
Version: 1.0
Release: 1%{?dist}
Summary: Configuration retention and AArch64 object checks for Uke governors
License: GPL-2.0-only
Source0: %{name}-%{version}.tar.gz
BuildArch: noarch
BuildRequires: bash gcc make bc bison flex perl openssl-devel elfutils-libelf-devel
BuildRequires: curl jq tar xz coreutils diffutils findutils grep binutils
%description
Text receipts for the exact four-option native configuration delta and the
unchanged upstream CPUFreq/devfreq governor objects. No kernel Image, module,
device configuration, boot selection or physical qualification is provided.
%prep
%autosetup
%build
%install
install -d %{buildroot}%{_docdir}/%{name}
%check
set -o pipefail
bash tests/governor-config-contract.sh packaging/native/native-before.config packaging/native/native.config \
    | tee %{buildroot}%{_docdir}/%{name}/checks.txt
bash packaging/native/check-governor-native-objects.sh \
    | tee -a %{buildroot}%{_docdir}/%{name}/checks.txt
%files
%license LICENSE LICENSES/GPL-2.0-only.txt
%{_docdir}/%{name}/checks.txt
%changelog
* Thu Nov 05 2026 Uke contributors - 1.0-1
- Check optional CPU and GPU governors without changing scheduling defaults.
SPEC
