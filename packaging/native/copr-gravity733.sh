#!/usr/bin/bash
# COPR source worker, exact full13 retained; no target compilation/requests.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/ssc-gravity-20261110.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 240 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$work/parent.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-13 ]]
rpm2cpio "$work/parent.rpm" | cpio -t --quiet > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
rpm2cpio "$work/parent.rpm" | (cd "$output";cpio -idm --quiet --no-absolute-filenames)
full=$output/senemos-uke-linux-kernel-mainline-unstable.spec
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$full" | sha256sum -c --strict --quiet -
tar -xJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work"
profile=$work/native-profile
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
jq -e '.source_commit=="780dd1a0642bad824e3d6491d4f7a8fb4e0fc665" and .kernel_release=="7.3.3-13-unstable" and .speaker_gain_ceiling==223' "$profile/source-composition.json" >/dev/null
install -m644 "$profile/source-composition.json" "$profile/gravity-parent-source-composition.json"
while IFS= read -r path;do install -Dm644 "$owner/$path" "$profile/$path";done < <(jq -r '.payload_assets[]' "$manifest")
commit=$(git -C "$owner" rev-parse HEAD)
tree=$(git -C "$owner" rev-parse HEAD^{tree})
jq --arg commit "$commit" --arg tree "$tree" '.+{source_commit:$commit,source_tree:$tree}' "$manifest" > "$profile/gravity-source-qualification.json"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work" native-profile
release=$(jq -er .source_check_release "$manifest")
{
 cat <<'SPEC'
%global debug_package %{nil}
%global _uke_out %{_topdir}/native-kernel-out
%global senemos_build_release 13
%global krel %{version}-%{senemos_build_release}-unstable
Name: uke-kernel-migration-check
Version: 7.3.3
SPEC
 printf 'Release: %s%%{?dist}\n' "$release"
 cat <<'SPEC'
Summary: Native Uke SSC gravity and linear acceleration source qualification
License: GPL-2.0-only AND MIT AND BSD-3-Clause
URL: https://github.com/MCC45TR/senemos-uke-kernel-mainline
SPEC
 sed -n '/^Source0:/,/^BuildRequires: rsync/p' "$full"
 cat <<'SPEC'
BuildRequires: libfdt-devel nodejs ripgrep gzip cpio

%description
Text-only actual SSC callbacks, binding and AArch64 object qualification.
No full kernel, runtime provider or physical sensor acceptance is supplied.

SPEC
 awk '$0=="%prep"{emit=1} $0=="%build"{exit} emit{print}' "$full"
 cat <<'SPEC'
%build
export ARCH=arm64 LLVM=1 LLVM_IAS=1
mkdir -p %{_uke_out}
SPEC
 awk '/^bash native-profile\/tests\/mainline-boot-status-contract.sh$/{emit=1} emit{print} emit&&/^bash native-profile\/packaging\/native\/prepare-pcm-surround-full733.sh .* source$/{found++;exit}END{if(found!=1)exit 1}' "$full"
 cat <<'SPEC'
cmp native-profile/native.config boot-recipe/packaging/native/native.config
cp native-profile/native.config %{_uke_out}/.config
make O=%{_uke_out} ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-13-unstable olddefconfig
make O=%{_uke_out} ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-13-unstable -j4 modules_prepare
bash native-profile/packaging/native/check-gravity733.sh "$PWD" %{_uke_out}

%install
install -Dm644 native-profile/gravity-source-qualification.json %{buildroot}%{_docdir}/%{name}/gravity-source-qualification.json
install -Dm644 native-profile/gravity-parent-source-composition.json %{buildroot}%{_docdir}/%{name}/gravity-parent-source-composition.json
install -Dm644 native-generated/ssc-gravity733/applied.sha256 %{buildroot}%{_docdir}/%{name}/actual-source.sha256
install -Dm644 native-profile/SHA256SUMS %{buildroot}%{_docdir}/%{name}/source-assets.sha256
install -Dm644 COPYING %{buildroot}%{_licensedir}/%{name}/COPYING

%files
%{_docdir}/%{name}
%{_licensedir}/%{name}

%changelog
SPEC
 printf '* Tue Nov 10 2026 Uke contributors - 7.3.3-%s\n- Qualify native six-value gravity and linear acceleration over full13.\n- Preserve old sensor paths, protected audio and the original config.\n' "$release"
} > "$output/uke-kernel-migration-check.spec"
rm "$full"
printf 'Native gravity source prepared over exact admitted full13; no full kernel reservation or runtime package added.\n'
