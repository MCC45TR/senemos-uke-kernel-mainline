#!/usr/bin/bash
# Focused original ALSA/topology qualification; no redundant kernel rebuild.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/speaker-surround-profiles-20261110.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 240 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$work/parent.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-11 ]]
mkdir "$work/parent" "$work/proof" "$output"
rpm2cpio "$work/parent.rpm" | cpio -t --quiet > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
rpm2cpio "$work/parent.rpm" | (cd "$work/parent";cpio -idm --quiet --no-absolute-filenames)
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$work/parent/senemos-uke-linux-kernel-mainline-unstable.spec" | sha256sum -c --strict --quiet -
tar -xJf "$work/parent/senemos-native-profile-7.3.3.tar.xz" -C "$work/parent"
parent=$work/parent/native-profile
(cd "$parent";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$parent";jq -r '.parent_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
profile=$work/proof/kernel/native-profile
mkdir -p "$profile" "$work/proof/kernel/native-generated"
while IFS= read -r path;do install -Dm644 "$parent/$path" "$profile/$path";done < <(jq -r '.parent_assets[].path' "$manifest")
while IFS= read -r path;do install -Dm644 "$owner/$path" "$profile/$path";done < <(jq -r '.payload_assets[]' "$manifest")
install -m644 "$parent/source-composition.json" "$work/proof/parent-source-composition.json"
jq -e '.source_commit=="4b4cf375b2a749a1961cda7e8927b8a7d27cb4d1" and .kernel_release=="7.3.3-11-unstable" and .speaker_gain_ceiling==223' "$work/proof/parent-source-composition.json" >/dev/null
commit=$(git -C "$owner" rev-parse HEAD)
tree=$(git -C "$owner" rev-parse HEAD^{tree})
jq --arg commit "$commit" --arg tree "$tree" '.+{source_commit:$commit,source_tree:$tree}' "$manifest" > "$work/proof/surround-profile-qualification.json"
mkdir -p "$profile/referances"
curl -qfsSL --max-time 60 "$(jq -er .alsa_ucm_source.url "$manifest")" -o "$profile/referances/alsa-ucm-parser.c"
printf '%s  %s\n' "$(jq -er .alsa_ucm_source.sha256 "$manifest")" "$profile/referances/alsa-ucm-parser.c" | sha256sum -c --strict --quiet -
curl -qfsSL --max-time 60 "$(jq -er .alsa_ucm_source.license_url "$manifest")" -o "$work/proof/COPYING.alsa-lib"
printf '%s  %s\n' "$(jq -er .alsa_ucm_source.license_sha256 "$manifest")" "$work/proof/COPYING.alsa-lib" | sha256sum -c --strict --quiet -
install -m644 "$owner/LICENSE" "$work/proof/LICENSE"
(cd "$work/proof";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/surround-profiles-proof.tar.xz" -C "$work" proof
release=$(jq -er .source_check_release "$manifest")
cat > "$output/uke-kernel-migration-check.spec" <<'SPEC'
Name: uke-kernel-migration-check
Version: 7.3.3
Release: @RELEASE@%{?dist}
Summary: Focused Uke protected surround profile source qualification
License: GPL-2.0-only AND MIT AND LGPL-2.0-or-later
URL: https://github.com/MCC45TR/senemos-uke-kernel-mainline
Source0: surround-profiles-proof.tar.xz
BuildRequires: gcc-c++, clang, alsa-utils, alsa-topology-utils, alsa-lib-devel, pkgconf-pkg-config, nodejs, jq
ExclusiveArch: aarch64
%global debug_package %{nil}

%description
Text-only source qualification of the original ALSA topology and UCM profiles.
No kernel, runtime helper or hardware acceptance is provided by this package.

%prep
%setup -q -n proof
sha256sum -c --strict --quiet SHA256SUMS

%build
kernel=$PWD/kernel
profile=$kernel/native-profile
bash "$profile/src/audio/build-protected-topology.sh" "$kernel/native-generated/protected.conf"
cat "$kernel/native-generated/protected.conf" "$profile/src/audio/POCO-Pad-X1-Microphone-Capture.conf" > "$kernel/native-generated/POCO-Pad-X1.conf"
alsatplg -c "$kernel/native-generated/POCO-Pad-X1.conf" -o "$kernel/native-generated/POCO-Pad-X1-tplg.bin"
bash "$profile/packaging/native/check-surround-profiles733.sh" "$kernel"

%install
install -Dm644 surround-profile-qualification.json %{buildroot}%{_docdir}/%{name}/surround-profile-qualification.json
install -Dm644 parent-source-composition.json %{buildroot}%{_docdir}/%{name}/parent-source-composition.json
install -Dm644 SHA256SUMS %{buildroot}%{_docdir}/%{name}/source-assets.sha256
install -Dm644 LICENSE %{buildroot}%{_licensedir}/%{name}/LICENSE
install -Dm644 COPYING.alsa-lib %{buildroot}%{_licensedir}/%{name}/COPYING.alsa-lib

%files
%{_docdir}/%{name}
%{_licensedir}/%{name}

%changelog
* Tue Nov 10 2026 Uke contributors - 7.3.3-@RELEASE@
- Qualify protected topology and standard six/eight input UCM profiles.
- Keep physical output count, gain and production kernel unchanged.
SPEC
sed -i "s/@RELEASE@/$release/g" "$output/uke-kernel-migration-check.spec"
printf 'Focused ALSA/topology source prepared; no kernel compile or runtime package added.\n'
