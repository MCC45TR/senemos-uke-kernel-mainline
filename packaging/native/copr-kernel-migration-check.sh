#!/usr/bin/env bash
# COPR source worker only. Produces text evidence, never a target driver package.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR source result directory}")
bash "$owner/packaging/native/refuse-published-release.sh" uke-kernel-migration-check 1.0-1
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/uke-kernel-migration-check-1.0"
git -C "$owner" archive HEAD \
    src/sensors src/boot/uke-hardware.h src/boot/bindings/firmware/xiaomi,uke-ssc-sensors.yaml \
    tests/ssc-protocol-contract.c tests/ssc-protocol-contract.sh \
    tests/ssc-native-contract.c tests/ssc-native-contract.sh tests/ssc-native-host.h \
    tests/ssc-supplier-contract.sh tests/ssc-mount-matrix.c tests/ssc-mount-matrix.sh \
    tests/hardware-dt.cpp tests/hardware-dt.sh \
    packaging/native/check-ssc-native-objects.sh \
    manifests/kernel-package-migration.json docs/KERNEL-PACKAGE-MIGRATION.md \
    scripts/kernel-migration-inventory.sh LICENSE LICENSES/GPL-2.0-only.txt |
    tar -xf - -C "$stage/uke-kernel-migration-check-1.0"
git -C "$owner" rev-parse HEAD > "$stage/uke-kernel-migration-check-1.0/source-commit"
git -C "$owner" rev-parse HEAD^{tree} > "$stage/uke-kernel-migration-check-1.0/source-tree"
tar --sort=name --mtime=@1793836800 --owner=0 --group=0 --numeric-owner \
    -czf "$output/uke-kernel-migration-check-1.0.tar.gz" -C "$stage" uke-kernel-migration-check-1.0
curl -q -fLsS --retry 2 --max-time 600 --proto '=https' --proto-redir '=https' \
    https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.1.tar.xz \
    -o "$output/linux-7.3.1.tar.xz"
printf '%s  %s\n' fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231 \
    "$output/linux-7.3.1.tar.xz" | sha256sum -c --strict -
cat > "$output/uke-kernel-migration-check.spec" <<'SPEC'
Name: uke-kernel-migration-check
Version: 1.0
Release: 1%{?dist}
Summary: Native Uke DT and IIO migration source checks
License: GPL-2.0-only AND MIT
Source0: %{name}-%{version}.tar.gz
Source1: linux-7.3.1.tar.xz
ExclusiveArch: aarch64
BuildRequires: bash gcc gcc-c++ clang compiler-rt libasan libubsan coreutils findutils git libfdt-devel
BuildRequires: make bc bison flex perl openssl-devel elfutils-libelf-devel tar xz jq
%global debug_package %{nil}

%description
Checks actual native SSC callbacks, Device Tree transformation, refusal paths,
and AArch64 protocol/IIO object compilation. Only text evidence is packaged.
This package is not a driver and does not establish physical sensor acceptance.

%prep
%autosetup

%build

%install
install -d %{buildroot}%{_docdir}/%{name}
install -m644 source-commit source-tree manifests/kernel-package-migration.json \
    docs/KERNEL-PACKAGE-MIGRATION.md %{buildroot}%{_docdir}/%{name}/

%check
set -o pipefail
bash tests/ssc-protocol-contract.sh | tee %{buildroot}%{_docdir}/%{name}/checks.txt
bash tests/ssc-supplier-contract.sh | tee -a %{buildroot}%{_docdir}/%{name}/checks.txt
for compiler in g++ clang++; do
    CXX=$compiler bash tests/hardware-dt.sh | tee -a %{buildroot}%{_docdir}/%{name}/checks.txt
done
UKE_SSC_KERNEL_ARCHIVE=%{SOURCE1} bash packaging/native/check-ssc-native-objects.sh \
    | tee -a %{buildroot}%{_docdir}/%{name}/checks.txt
printf 'Full kernel/module, DNF replacement, four-pose rotation and ALS acceptance remain separate\n' \
    | tee -a %{buildroot}%{_docdir}/%{name}/checks.txt

%files
%license LICENSE LICENSES/GPL-2.0-only.txt
%{_docdir}/%{name}

%changelog
* Thu Nov 05 2026 Uke contributors - 1.0-1
- Check native child mount metadata, exact landscape DT strings and retained SSC gates.
- Package text evidence only; preserve all target services and recovery policy.
SPEC
