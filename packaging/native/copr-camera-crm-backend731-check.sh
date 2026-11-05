#!/usr/bin/env bash
# COPR only: retain complete12204 prep, check actual IRQ/LUT bodies and APIs.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
bash "$owner/packaging/native/refuse-published-release.sh" uke-camera-crm-core-check 7.3.1-3
for build in 11263248 11264022; do
    [[ $(curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$build" | jq -er .state) == succeeded ]]
done
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
manifest=$owner/manifests/camera-crm-backend731-20261105.json
while IFS=$'\t' read -r path digest; do
    [[ $path =~ ^(src|tests|docs|manifests)/[a-zA-Z0-9_.,/-]+$ && $path != *..* ]]
    printf '%s  %s\n' "$digest" "$owner/$path" | sha256sum -c --strict -
done < <(jq -er '.inputs[] | [.path,.sha256] | @tsv' "$manifest")
curl -q -fLsS --retry 2 --max-time 600 --proto '=https' --proto-redir '=https' \
    "$(jq -er .parent.url "$manifest")" -o "$stage/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent.sha256 "$manifest")" "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == \
    senemos-uke-linux-kernel-mainline-unstable-7.3.1-12204 ]]
rpmkeys --checksig --nosignature --verbose "$stage/parent.src.rpm"
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
mkdir -p "$output" "$stage/crm-oracles"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
test -f "$parent"
if grep -qE '^Source(190|191):' "$parent"; then exit 1; fi
find "$output" -maxdepth 1 -type f ! -name "${parent##*/}" -print0 | \
    sort -z | xargs -0 sha256sum > "$stage/retained.sha256"
while IFS=$'\t' read -r file path digest; do
    [[ $file =~ ^oem571-[a-z0-9.-]+$ && $path =~ ^(drivers|include)/[a-zA-Z0-9_./-]+$ && $path != *..* ]]
    curl -q -fLsS --retry 2 --max-time 90 --proto '=https' --proto-redir '=https' \
        "https://raw.githubusercontent.com/MiCode/Xiaomi_Kernel_OpenSource/5712080a4b0c0b1a879e6d145c601c649ddaddfd/$path" \
        -o "$stage/crm-oracles/$file"
    printf '%s  %s\n' "$digest" "$stage/crm-oracles/$file" | sha256sum -c --strict -
done < <(jq -er '.oracle_inputs[] | [.reference_file,.path,.sha256] | @tsv' "$manifest")
mapfile -t assets < <(jq -er '.inputs[].path' "$manifest")
git -C "$owner" archive --prefix=camera-crm-backend/ HEAD "${assets[@]}" \
    manifests/camera-crm-backend731-20261105.json LICENSES/GPL-2.0-only.txt | tar -xf - -C "$stage"
git -C "$owner" rev-parse HEAD > "$stage/camera-crm-backend/source-commit"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/uke-camera-crm-backend.tar.xz" -C "$stage" camera-crm-backend
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/uke-camera-crm-oracles.tar.xz" -C "$stage" crm-oracles
spec=$output/uke-camera-crm-core-check.spec
awk '
 /^%description/ {exit}
 /^Name:/ {$0="Name: uke-camera-crm-core-check"}
 /^Release:/ {$0="Release: 3%{?dist}"}
 /^Summary:/ {$0="Summary: Uke camera CRM IRQ and LUT source qualification"}
 /^(Requires|Provides|Recommends|Conflicts|Obsoletes)(\([^)]*\))?:/ {next}
 {print}
' "$parent" > "$spec"
cat >> "$spec" <<'SPEC'
%global debug_package %{nil}
Source190: uke-camera-crm-backend.tar.xz
Source191: uke-camera-crm-oracles.tar.xz
BuildRequires: compiler-rt

%description
Preserve complete12204 preparation and test the actual Cliffs AP SWDRV0 IRQ
transport and read-only LUT code. Execute fault, timeout, late/wrong completion,
power and source-oracle controls with GCC/Clang and sanitizers, then compile a
real AArch64 object against that kernel configuration. Package text receipts
only. No Image, module, provider activation or physical camera result is supplied.

SPEC
awk '/^%prep$/ {emit=1} /^%build$/ {exit} emit {print}' "$parent" >> "$spec"
cat >> "$spec" <<'SPEC'
tar -xJf %{SOURCE190}
tar -xJf %{SOURCE191}

%build
set -o pipefail
for pair in gcc:g++ clang:clang++; do
 for contract in core backend; do
  CC=${pair%%:*} CXX=${pair#*:} CAMERA_CRM_MUTATIONS=1 \
   bash camera-crm-backend/tests/camera-crm-$contract-contract.sh crm-oracles \
   | tee -a %{_topdir}/camera-crm-backend-checks.txt
  CC=${pair%%:*} CXX=${pair#*:} \
   CAMERA_CRM_TEST_FLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
   bash camera-crm-backend/tests/camera-crm-$contract-contract.sh crm-oracles \
   | tee -a %{_topdir}/camera-crm-backend-checks.txt
 done
done
bash camera-crm-backend/tests/camera-crm-backend-object731.sh "$PWD" "$PWD/crm-object" native-profile/native.config \
 | tee -a %{_topdir}/camera-crm-backend-checks.txt
sha256sum camera-crm-backend/src/camera/provider/camcc-sm7675-crm-{core,transport,lut}.h \
 | tee -a %{_topdir}/camera-crm-backend-checks.txt

%install
install -Dm644 %{_topdir}/camera-crm-backend-checks.txt %{buildroot}%{_docdir}/%{name}/checks.txt
install -m644 camera-crm-backend/source-commit %{buildroot}%{_docdir}/%{name}/source-commit
install -m644 camera-crm-backend/manifests/camera-crm-backend731-20261105.json %{buildroot}%{_docdir}/%{name}/source-manifest.json
install -m644 camera-crm-backend/manifests/camera-crm-core-20261105.json %{buildroot}%{_docdir}/%{name}/core-manifest.json
install -m644 native-profile/source-composition.json %{buildroot}%{_docdir}/%{name}/parent-composition.json

%check
test -s %{buildroot}%{_docdir}/%{name}/checks.txt
test ! -e arch/arm64/boot/Image
test ! -e crm-object/arch/arm64/boot/Image
test ! -e crm-object/drivers/clk/qcom/uke-crm-qualification.ko

%files
%license camera-crm-backend/LICENSES/GPL-2.0-only.txt
%{_docdir}/%{name}/checks.txt
%{_docdir}/%{name}/source-commit
%{_docdir}/%{name}/source-manifest.json
%{_docdir}/%{name}/core-manifest.json
%{_docdir}/%{name}/parent-composition.json

%changelog
* Thu Nov 05 2026 Uke contributors - 7.3.1-3
- Check owned IRQ completion and read-only LUT parsing on complete12204.
- Require source negative controls, timeout/error mutants and native API object.
- Keep the firmware CRM guard, camera graph and physical acceptance unchanged.
SPEC
sha256sum -c --strict --quiet "$stage/retained.sha256"
unlink "$parent"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$spec") == uke-camera-crm-core-check-7.3.1-3 ]]
printf 'Camera CRM IRQ/LUT source/native-object check prepared; no full kernel or target change\n'
