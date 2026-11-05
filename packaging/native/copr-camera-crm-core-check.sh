#!/usr/bin/env bash
# COPR source worker only. A text receipt; no kernel build or tablet delivery.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
bash "$owner/packaging/native/refuse-published-release.sh" uke-camera-crm-core-check 7.3.1-1
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
manifest=$owner/manifests/camera-crm-core-20261105.json
while IFS=$'\t' read -r path digest; do
    [[ $path =~ ^(src|tests|docs)/[a-zA-Z0-9_.,/-]+$ && $path != *..* ]]
    printf '%s  %s\n' "$digest" "$owner/$path" | sha256sum -c --strict -
done < <(jq -er '.inputs[] | [.path,.sha256] | @tsv' "$manifest")
mkdir -p "$output" "$stage/crm-oracles"
while IFS=$'\t' read -r file path digest; do
    [[ $file =~ ^oem571-[a-z0-9.-]+$ && $path =~ ^(drivers|include)/[a-zA-Z0-9_./-]+$ && $path != *..* ]]
    curl -q -fLsS --retry 2 --max-time 90 --proto '=https' --proto-redir '=https' \
        "https://raw.githubusercontent.com/MiCode/Xiaomi_Kernel_OpenSource/5712080a4b0c0b1a879e6d145c601c649ddaddfd/$path" \
        -o "$stage/crm-oracles/$file"
    printf '%s  %s\n' "$digest" "$stage/crm-oracles/$file" | sha256sum -c --strict -
done < <(jq -er '.oracle_inputs[] | [.reference_file,.path,.sha256] | @tsv' "$manifest")
mapfile -t assets < <(jq -er '.inputs[].path' "$manifest")
git -C "$owner" archive --prefix=camera-crm-core/ HEAD "${assets[@]}" \
    manifests/camera-crm-core-20261105.json LICENSES/GPL-2.0-only.txt | tar -xf - -C "$stage"
git -C "$owner" rev-parse HEAD > "$stage/camera-crm-core/source-commit"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/camera-crm-core.tar.xz" -C "$stage" camera-crm-core
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/crm-oracles.tar.xz" -C "$stage" crm-oracles
cat > "$output/uke-camera-crm-core-check.spec" <<'SPEC'
Name: uke-camera-crm-core-check
Version: 7.3.1
Release: 1%{?dist}
Summary: Uke AP camera CRM source and failure qualification
License: GPL-2.0-only
Source0: camera-crm-core.tar.xz
Source1: crm-oracles.tar.xz
BuildRequires: gcc
BuildRequires: gcc-c++
BuildRequires: clang
BuildRequires: compiler-rt
BuildRequires: libasan
BuildRequires: libubsan
BuildRequires: jq
BuildRequires: coreutils
BuildRequires: grep
BuildRequires: gawk
BuildRequires: sed
BuildRequires: xz
BuildRequires: tar
BuildRequires: rpm

%description
Compile the AP SWDRV0 vote core as C and C++, compare it with immutable Uke
OEM register/function bodies, and inject partial-write and timeout failures.
GCC and Clang run ordinary and address/undefined sanitizer checks. Only text
receipts and licensing are packaged. No kernel Image, module, MMIO access or
hardware admission is provided. IRQ/LUT/CCF integration remains separate work.

%prep
%setup -q -n camera-crm-core
tar -xJf %{SOURCE1}

%build
set -o pipefail
for pair in gcc:g++ clang:clang++; do
 CC=${pair%%:*} CXX=${pair#*:} CAMERA_CRM_MUTATIONS=1 \
  bash tests/camera-crm-core-contract.sh crm-oracles \
  | tee -a %{_topdir}/camera-crm-core-checks.txt
 CC=${pair%%:*} CXX=${pair#*:} \
  CAMERA_CRM_TEST_FLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
  bash tests/camera-crm-core-contract.sh crm-oracles \
  | tee -a %{_topdir}/camera-crm-core-checks.txt
done
sha256sum src/camera/provider/camcc-sm7675-crm-core.h crm-oracles/* \
 | tee -a %{_topdir}/camera-crm-core-checks.txt

%install
install -Dm644 %{_topdir}/camera-crm-core-checks.txt %{buildroot}%{_docdir}/%{name}/checks.txt
install -m644 source-commit %{buildroot}%{_docdir}/%{name}/source-commit
install -m644 manifests/camera-crm-core-20261105.json %{buildroot}%{_docdir}/%{name}/source-manifest.json

%check
test -s %{buildroot}%{_docdir}/%{name}/checks.txt
test -s %{buildroot}%{_docdir}/%{name}/source-commit
test -s %{buildroot}%{_docdir}/%{name}/source-manifest.json

%files
%license LICENSES/GPL-2.0-only.txt
%{_docdir}/%{name}/checks.txt
%{_docdir}/%{name}/source-commit
%{_docdir}/%{name}/source-manifest.json

%changelog
* Thu Nov 05 2026 Uke contributors - 7.3.1-1
- Check AP SWDRV0 offsets and packets against exact OEM source bodies.
- Reject invalid plans before transport; stop and poison on first failure.
- Keep active firmware CRM admission and all camera hardware gates closed.
SPEC
printf 'Camera CRM core source check prepared; no full-kernel revision or target change\n'
