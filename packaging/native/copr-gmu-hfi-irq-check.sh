#!/usr/bin/env bash
# COPR only: slim text-receipt fixture, no kernel RPM or device delivery.
set -Eeuo pipefail
trap 'status=$?; printf "GMU fixture source failed at line %s (exit %s)\n" "$LINENO" "$status" >&2; exit "$status"' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
bash "$owner/packaging/native/refuse-published-release.sh" uke-o82-kms-check 7.3.1-15
output=$(realpath -m "${1:?COPR source result directory}")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/sources" "$stage/parent" "$stage/addon/uke-o82-kms-check-7.3.1"
[[ $(curl -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11260781 | jq -er .state) == succeeded ]]
curl -fLsS --retry 2 --max-time 300 --proto '=https' --proto-redir '=https' \
 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11260781/senemos-uke-linux-kernel-mainline-unstable-7.3.1-12101.src.rpm \
 -o "$stage/parent.src.rpm"
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-12101 ]]
[[ $(rpm -qp --qf '%{SHA256HEADER}' "$stage/parent.src.rpm") == d3233dbac1900bae0032a141a9dd44b1e6e4bc5231314293af52a03dfe21fe12 ]]
[[ $(rpm -qp --qf '%{PAYLOADSHA256}' "$stage/parent.src.rpm") == 657383647b0ecbbfea3dca458a29897188bac5a87fca55aa7d829dd8d3453e8d ]]
rpmkeys --checksig --nosignature --verbose "$stage/parent.src.rpm"
printf 'Qualified12101 full source RPM SHA256: '
sha256sum "$stage/parent.src.rpm"
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
(cd "$stage/sources"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
printf '%s  %s\n' fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231 \
 "$stage/sources/linux-7.3.1.tar.xz" | sha256sum -c --strict
for archive in senemos-uke-adaptation-7.3.1.tar.xz senemos-native-profile-7.3.1.tar.xz; do
 tar -tJf "$stage/sources/$archive" > "$stage/entries"
 awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
 tar -xJf "$stage/sources/$archive" -C "$stage/parent"
done
profile=$stage/parent/native-profile
adaptation=$stage/parent/senemos-adaptation
[[ $(jq -er .source_commit "$profile/source-composition.json") == bba194e74ab97dcb848887fa62430c20f9d755d9 ]]
(cd "$profile"; sha256sum --check --strict --quiet SHA256SUMS)
# Refuse an unreviewed native-profile override of either extracted function.
if grep -REq --include='*.c' --include='*.h' --include='*.patch' --include='*.sh' \
 'a6xx_hfi_irq|a6xx_hfi_wait_for_msg_interrupt' "$profile"; then
 printf 'Unreviewed native-profile callback override; inspect instead of replacing it\n' >&2;exit 1
fi
addon=$stage/addon/uke-o82-kms-check-7.3.1
kernel=$addon/upstream
mkdir -p "$kernel"
tar -xJf "$stage/sources/linux-7.3.1.tar.xz" --strip-components=1 -C "$kernel" \
 linux-7.3.1/drivers/gpu/drm/msm/adreno/a6xx_gmu.c \
 linux-7.3.1/drivers/gpu/drm/msm/adreno/a6xx_hfi.c \
 linux-7.3.1/drivers/gpu/drm/msm/adreno/a6xx_hfi.h \
 linux-7.3.1/drivers/gpu/drm/msm/registers/adreno/a6xx_gmu.xml
git -c init.defaultBranch=fixture -C "$kernel" init -q
jq -r '.patches[].path|split("/")|last' "$adaptation/source-lock.json" > "$stage/expected-series"
cmp "$stage/expected-series" "$adaptation/patches/series"
count=0
while IFS=$'\t' read -r path expected; do
 [[ $path == patches/* || $path == configs/* ]]
 [[ $(sha256sum "$adaptation/${path%%/*}/${path##*/}" | cut -d ' ' -f1) == "$expected" ]]
done < <(jq -r '.patches[],.configs[]|[.path,.sha256]|@tsv' "$adaptation/source-lock.json")
while IFS= read -r patch_name; do
 [[ -n $patch_name ]]
 patch=$adaptation/patches/$patch_name
 git apply --numstat "$patch" > "$stage/numstat"
 if awk -F '\t' '$3=="drivers/gpu/drm/msm/adreno/a6xx_gmu.c" ||
  $3=="drivers/gpu/drm/msm/adreno/a6xx_hfi.c" ||
  $3=="drivers/gpu/drm/msm/adreno/a6xx_hfi.h" ||
  $3=="drivers/gpu/drm/msm/registers/adreno/a6xx_gmu.xml" {found=1} END{exit !found}' "$stage/numstat"; then
  [[ $patch_name == 0036-uke-adreno732-render.patch ]]
  args=(--include=drivers/gpu/drm/msm/adreno/a6xx_gmu.c
   --include=drivers/gpu/drm/msm/adreno/a6xx_hfi.c
   --include=drivers/gpu/drm/msm/adreno/a6xx_hfi.h
   --include=drivers/gpu/drm/msm/registers/adreno/a6xx_gmu.xml)
  git -C "$kernel" apply --check "${args[@]}" "$patch"
  git -C "$kernel" apply "${args[@]}" "$patch"
  count=$((count+1))
 fi
done < "$adaptation/patches/series"
[[ $count == 1 ]]
printf 'Retained12101 callback files: pinned upstream plus exact active A732 adaptation; no native-profile function override\n'
git -C "$owner" archive HEAD patches/gpu/0075-gmu-hfi-irq-owned-status.patch \
 tests/gmu-hfi-irq-contract.sh tests/fixtures/gmu-hfi-irq-check.c \
 docs/GMU-HFI-IRQ-OWNERSHIP.md LICENSE LICENSES/GPL-2.0-only.txt | tar -xf - -C "$addon"
git -C "$owner" rev-parse HEAD > "$addon/source-commit"
jq -n --arg source "$(git -C "$owner" rev-parse HEAD)" \
 '{source_commit:$source,parent_build:11260781,parent_source:"bba194e74ab97dcb848887fa62430c20f9d755d9",
 parent_header:"d3233dbac1900bae0032a141a9dd44b1e6e4bc5231314293af52a03dfe21fe12",
 parent_payload:"657383647b0ecbbfea3dca458a29897188bac5a87fca55aa7d829dd8d3453e8d",
 upstream:"79a907609d53d5cd645b42c11550d295d43abf99",fixture_only:true,
 whole_kernel_prepared:false,device_execution:false}' > "$addon/source-inputs.json"
# Do not duplicate complete Linux archives in this source package.
find "$kernel/.git" -depth -delete
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf \
 "$output/uke-o82-kms-check-7.3.1.tar.xz" -C "$stage/addon" uke-o82-kms-check-7.3.1
cat > "$output/uke-o82-kms-check.spec" <<'SPEC'
Name: uke-o82-kms-check
Version: 7.3.1
Release: 15%{?dist}
Summary: Actual Uke GMU fault IRQ and HFI response callback qualification
License: GPL-2.0-only
Source0: %{name}-%{version}.tar.xz
BuildArch: noarch
BuildRequires: bash gcc clang compiler-rt libasan libubsan coreutils findutils gawk grep git-core
%description
Execute retained12101 IRQ and HFI polling functions against modeled latch
ownership. Require actual old failure and corrected GCC/Clang normal and
fail-fast sanitizer controls. Only text receipts/licenses are installed.
No kernel, module, boot image, runtime helper or hardware operation is produced.
%prep
%autosetup
%build
%install
install -d %{buildroot}%{_docdir}/%{name}
install -m644 source-commit source-inputs.json %{buildroot}%{_docdir}/%{name}/
%check
set -o pipefail
bash tests/gmu-hfi-irq-contract.sh "$PWD/upstream" \
 | tee %{buildroot}%{_docdir}/%{name}/checks.txt
%files
%license LICENSE LICENSES/GPL-2.0-only.txt
%{_docdir}/%{name}/source-commit
%{_docdir}/%{name}/source-inputs.json
%{_docdir}/%{name}/checks.txt
%changelog
* Thu Nov 05 2026 Uke contributors - 7.3.1-15
- Check actual IRQ/poller ownership, fault dispatch, late arrivals and timeout.
SPEC
[[ $(rpmspec --define 'dist %{nil}' --target aarch64 -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$output/uke-o82-kms-check.spec") == uke-o82-kms-check-7.3.1-15 ]]
