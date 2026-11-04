#!/usr/bin/env bash
# COPR only: actual cached probe callbacks and registration fault models.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/uke-camcc-probe-check-1.0"
git -C "$owner" archive HEAD src/camera/camcc-sm7675.c \
    src/camera/provider/camcc-sm7675-clocks.h \
    src/camera/provider/camcc-sm7675-handoff.h \
    src/camera/provider/camcc-sm7675-registration.h \
    src/camera/provider/camcc-sm7675-crm-guard.h \
    tests/camcc-native731-contract.sh tests/fixtures/camcc-native-check.c \
    tests/camcc-crm-guard731-contract.sh tests/fixtures/camcc-crm-guard-check.c \
    LICENSE LICENSES/GPL-2.0-only.txt | tar -xf - -C "$stage/uke-camcc-probe-check-1.0"
git -C "$owner" rev-parse HEAD > "$stage/uke-camcc-probe-check-1.0/source-commit"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -czf "$output/uke-camcc-probe-check-1.0.tar.gz" -C "$stage" uke-camcc-probe-check-1.0
curl -q -fLsS --retry 2 --max-time 600 --proto '=https' --proto-redir '=https' \
    https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.1.tar.xz \
    -o "$output/linux-7.3.1.tar.xz"
printf '%s  %s\n' fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231 \
    "$output/linux-7.3.1.tar.xz" | sha256sum -c --strict -
cat > "$output/uke-camcc-probe-check.spec" <<'SPEC'
Name: uke-camcc-probe-check
Version: 1.0
Release: 1%{?dist}
Summary: Remote qualification of cached native Uke CAMCC probe observations
License: GPL-2.0-only
Source0: %{name}-%{version}.tar.gz
Source1: linux-7.3.1.tar.xz
BuildArch: noarch
BuildRequires: bash gcc clang compiler-rt libasan libubsan coreutils findutils gawk grep sed tar xz
%description
Checks actual CAMCC registration, quarantine and read-only probe callbacks with
modeled framework and MMIO boundaries. No driver is installed or activated.
This does not qualify full kernel linkage, electrical behavior or cameras.
%prep
%autosetup
echo 'fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231  %{SOURCE1}' | sha256sum -c --strict -
mkdir upstream
tar -xJf %{SOURCE1} --strip-components=1 -C upstream \
 linux-7.3.1/include/linux/device.h linux-7.3.1/drivers/pmdomain/core.c
%build
%install
install -d %{buildroot}%{_docdir}/%{name}
install -m644 source-commit %{buildroot}%{_docdir}/%{name}/source-commit
%check
set -o pipefail
for compiler in gcc clang; do
 CC=$compiler bash tests/camcc-crm-guard731-contract.sh | tee -a %{buildroot}%{_docdir}/%{name}/checks.txt
 CC=$compiler CAMCC_CRM_TEST_FLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
  bash tests/camcc-crm-guard731-contract.sh | tee -a %{buildroot}%{_docdir}/%{name}/checks.txt
 CC=$compiler CAMCC_NATIVE_MUTATIONS=1 bash tests/camcc-native731-contract.sh "$PWD/upstream" \
  | tee -a %{buildroot}%{_docdir}/%{name}/checks.txt
 CC=$compiler CAMCC_NATIVE_TEST_FLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
  bash tests/camcc-native731-contract.sh "$PWD/upstream" | tee -a %{buildroot}%{_docdir}/%{name}/checks.txt
done
%files
%license LICENSE LICENSES/GPL-2.0-only.txt
%{_docdir}/%{name}/source-commit
%{_docdir}/%{name}/checks.txt
%changelog
* Wed Nov 04 2026 Uke contributors - 1.0-1
- Preserve the first failing phase and existing gate readback without new MMIO.
- Check cached sysfs reads, unavailable/stale data and unchanged probe calls.
- Require frozen-phase, stale-readback and live-read mutations to fail.
SPEC
