#!/usr/bin/bash
# Qualify every reference configuration against the exact full23 source.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/storage-cohort-20261111.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
[[ ! -e $output ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 240 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$work/parent.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-23 ]]
rpm2cpio "$work/parent.rpm" | cpio -t --quiet > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
rpm2cpio "$work/parent.rpm" | (cd "$output";cpio -idm --quiet --no-absolute-filenames)
full=$output/senemos-uke-linux-kernel-mainline-unstable.spec
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$full" | sha256sum -c --strict --quiet -
printf '%s  %s\n' "$(jq -er .parent_profile_sha256 "$manifest")" "$output/senemos-native-profile-7.3.3.tar.xz" | sha256sum -c --strict --quiet -
tar -xJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work"
profile=$work/native-profile
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
jq -e 'length==774 and .source_commit=="dde9b3034a095f14581c0fd5e23c42f1caf43986" and .kernel_release=="7.3.3-23-unstable" and .speaker_gain_ceiling==223 and .charge_protection_observe_v2 and .charge_protection_legacy_passive_v1' "$profile/source-composition.json" >/dev/null
install -m644 "$profile/source-composition.json" "$profile/storage-cohort-parent-source-composition.json"
while IFS= read -r file;do install -Dm644 "$owner/$file" "$profile/$file";done < <(jq -r '.payload_assets[]' "$manifest")
commit=$(git -C "$owner" rev-parse HEAD)
tree=$(git -C "$owner" rev-parse HEAD^{tree})
jq --arg commit "$commit" --arg tree "$tree" '.+{source_commit:$commit,source_tree:$tree}' "$manifest" > "$profile/storage-cohort-source-qualification.json"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work" native-profile
release=$(jq -er .source_check_release "$manifest")
{
 cat <<'SPEC'
%global debug_package %{nil}
%global _uke_out %{_topdir}/native-kernel-out
%global senemos_build_release 23
%global krel %{version}-%{senemos_build_release}-unstable
Name: uke-kernel-migration-check
Version: 7.3.3
SPEC
 printf 'Release: %s%%{?dist}\n' "$release"
 cat <<'SPEC'
Summary: Native Uke encryption reference profile qualification
License: GPL-2.0-only AND MIT AND BSD-3-Clause
URL: https://github.com/MCC45TR/senemos-uke-kernel-mainline
SPEC
 sed -n '/^Source0:/,/^BuildRequires: rsync/p' "$full"
 grep -E '^BuildRequires: (clang|llvm|lld) = ' "$full"
 cat <<'SPEC'
BuildRequires: libfdt-devel nodejs ripgrep gzip cpio

%description
Text-only qualification of cumulative encryption configurations and objects.
No full kernel, encrypted filesystem, key provisioning or runtime is supplied.

SPEC
 awk '$0=="%prep"{emit=1} $0=="%build"{exit} emit{print}' "$full"
 cat <<'SPEC'
%build
export ARCH=arm64 LLVM=1 LLVM_IAS=1
mkdir -p %{_uke_out}
bash native-profile/packaging/native/check-dual-light-delivery733.sh "$PWD" %{_uke_out} prepared
SPEC
 awk '/^bash native-profile\/tests\/mainline-boot-status-contract.sh$/{emit=1} emit{print} emit&&/^bash native-profile\/packaging\/native\/prepare-charge-observe-full733.sh .* source$/{found++;exit}END{if(found!=1)exit 1}' "$full"
 cat <<'SPEC'
bash native-profile/packaging/native/check-storage-cohort733.sh "$PWD" %{_uke_out}
cmp native-profile/storage-cohort-parent-source-composition.json native-profile/source-composition.json

%install
install -Dm644 native-profile/storage-cohort-source-qualification.json %{buildroot}%{_docdir}/%{name}/storage-cohort-source-qualification.json
install -Dm644 native-profile/storage-cohort-parent-source-composition.json %{buildroot}%{_docdir}/%{name}/storage-cohort-parent-source-composition.json
install -Dm644 native-generated/storage-cohort733/resolved-cohort.json %{buildroot}%{_docdir}/%{name}/resolved-cohort.json
install -Dm644 native-generated/storage-cohort733/native-objects.sha256 %{buildroot}%{_docdir}/%{name}/native-objects.sha256
for role in native cdsp waydroid cdsp-before;do
 for phase in before after;do
  install -Dm644 native-generated/storage-cohort733/$phase-$role/.config %{buildroot}%{_docdir}/%{name}/$phase-$role.config
 done
done
install -Dm644 native-profile/SHA256SUMS %{buildroot}%{_docdir}/%{name}/source-assets.sha256
install -Dm644 COPYING %{buildroot}%{_licensedir}/%{name}/COPYING

%files
%{_docdir}/%{name}
%{_licensedir}/%{name}

%changelog
SPEC
 printf '* Wed Nov 11 2026 Uke contributors - 7.3.3-%s\n- Resolve the exact encryption delta across all cumulative reference profiles.\n- Compile real crypto and retained battery objects with the final native config.\n' "$release"
} > "$output/uke-kernel-migration-check.spec"
rm "$full"
printf 'Storage cohort source prepared over exact full23; no full kernel reservation,volume operation,new runtime or hardware acceptance.\n'
