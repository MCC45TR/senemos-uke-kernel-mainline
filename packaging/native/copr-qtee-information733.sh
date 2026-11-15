#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Preserve the actual qualified full27 SRPM; extend only the QTEE diagnostic.
set -Eeuo pipefail
[[ $# == 2 && ! -e /etc/senemos/kernel-update.conf && ($2 == check || $2 == full) ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1"); mode=$2
manifest=$owner/manifests/qtee-information-20261115.json
[[ ! -e $output && ! -L $output && -z $(git -C "$owner" status --porcelain) ]]
(cd "$owner"; jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 600 --max-filesize 314572800 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{SOURCEPACKAGE}' "$work/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-27.1 ]]
rpm2cpio "$work/parent.src.rpm" | cpio -t --quiet > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
rpm2cpio "$work/parent.src.rpm" | (cd "$output"; cpio -idm --quiet --no-absolute-filenames)
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$parent" | sha256sum -c --strict --quiet -
find "$output" -maxdepth 1 -type f ! -name "${parent##*/}" \
 ! -name senemos-native-profile-7.3.3.tar.xz ! -name senemos-uke-boot-recipe.tar.xz ! -name boot-payload.json \
 -print0 | sort -z | xargs -0 sha256sum > "$work/retained.sha256"
mapfile -t assets < <(jq -er '.source_assets[].path' "$manifest")
git -C "$owner" archive --prefix=qtee-information/ HEAD "${assets[@]}" manifests/qtee-information-20261115.json | tar -xf - -C "$work"
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$work/qtee-information/source-commit"
if [[ $mode == full ]]; then
 proof=$owner/manifests/qtee-information-qualified114-20261115.json
 jq -e '.native_qualified and .source_check_release==114 and .parent_full_build==11330023 and (.physical_tpm_qualified|not)' "$proof" >/dev/null
 curl -qfsSL --max-time 60 'https://copr.fedorainfracloud.org/api_3/build/list?ownername=mcc45tr&projectname=uke-linux-unstable&packagename=senemos-uke-linux-kernel-mainline-unstable' > "$work/full-history.json"
 [[ $(bash "$owner/scripts/kernel-release.sh" next "$work/full-history.json" 7.3.3 senemos-uke-linux-kernel-mainline-unstable) == 28 ]]
 curl -qfsSL --max-time 120 "$(jq -er .receipt_url "$proof")" -o "$work/native114.rpm"
 printf '%s  %s\n' "$(jq -er .receipt_sha256 "$proof")" "$work/native114.rpm" | sha256sum -c --strict --quiet -
 mkdir -m700 "$work/gpg" "$work/rpmdb"
 curl -qfsSL --max-time 60 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/pubkey.gpg -o "$work/key.gpg"
 gpg --homedir "$work/gpg" --batch --with-colons --show-keys "$work/key.gpg" | awk -F: '$1=="fpr"{print $10}' | grep -Fx 2204A661EA630A5303500085538797E72A3E4ECA
 rpmkeys --dbpath "$work/rpmdb" --import "$work/key.gpg"
 rpmkeys --dbpath "$work/rpmdb" --checksig --verbose "$work/native114.rpm" > "$work/qtee-information/native114-signature.txt"
 mkdir "$work/native114"
 rpm2cpio "$work/native114.rpm" | (cd "$work/native114"; cpio -idm --quiet --no-absolute-filenames)
 receipt=$work/native114/usr/share/uke-kernel-migration-check
 [[ $(cat "$receipt/source-commit") == "$(jq -er .source_commit "$proof")" ]]
 cmp "$manifest" "$receipt/qtee-information-20261115.json"
 cp "$proof" "$work/qtee-information/native114-qualification.json"
fi
tar -xJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile; boot=$work/boot-recipe
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
cp "$profile/source-composition.json" "$work/qtee-information/parent-composition.json"
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/raw-configs.sha256"
jq '.full_release=28|.source_check_release=114' "$profile/manifests/cumulative-release.json" > "$work/plan.json"
before_audio=$(awk '$2=="./src/audio/uke-audio-card.c" || $2=="src/audio/uke-audio-card.c"{print $1}' "$profile/SHA256SUMS")
[[ $before_audio =~ ^[a-f0-9]{64}$ ]]
bash "$owner/packaging/native/retarget-audio-tuple733.sh" "$profile" "$boot" "$work/plan.json" "$before_audio"
for tree in "$profile" "$boot"; do install -m644 "$work/plan.json" "$tree/manifests/cumulative-release.json"; done
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" '.+{source_commit:$commit,kernel_release:"7.3.3-28-unstable",rpm_revision:"28",diagnostic_audio_driver:"uke7_3_3-28u",qtee_tpm_information_diagnostic_v1:1,qtee_tpm_information_requests_at_probe:0}' \
 "$work/qtee-information/parent-composition.json" > "$profile/source-composition.json"
jq --slurpfile before "$work/qtee-information/parent-composition.json" -e '. as $after|all($before[0]|to_entries[];.key as $key|(["source_commit","kernel_release","rpm_revision","diagnostic_audio_driver"]|index($key))!=null or $after[$key]==.value)' "$profile/source-composition.json" >/dev/null
sha256sum -c --strict --quiet "$work/raw-configs.sha256"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/boot-assets.txt"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/boot-assets.txt" > "$work/boot-assets.json"
jq --slurpfile assets "$work/boot-assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/lock.json"
cp "$work/lock.json" "$boot/lock.json"
cp "$work/lock.json" "$output/boot-payload.json"
bash "$owner/packaging/native/rewrite-qtee-information733.sh" "$parent" "$work/full28.spec" "$manifest"
printf '%s  %s\n' "$(jq -er .result.planned_full_spec_sha256 "$manifest")" "$work/full28.spec" | sha256sum -c --strict --quiet -
cp "$work/full28.spec" "$parent"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for pair in senemos-native-profile-7.3.3.tar.xz:native-profile senemos-uke-boot-recipe.tar.xz:boot-recipe uke-qtee-information.tar.xz:qtee-information; do
 tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/${pair%%:*}" -C "$work" "${pair#*:}"
done
sha256sum -c --strict --quiet "$work/retained.sha256"
if [[ $mode == check ]]; then
 spec=$output/uke-kernel-migration-check.spec
 awk '/^%description/{exit}/^Name:/{$0="Name: uke-kernel-migration-check"}/^Release:/{$0="Release: 114%{?dist}"}/^Summary:/{$0="Summary: Full27-preserving kernel QTEE metadata source and object qualification"}/^(Requires|Provides|Recommends|Conflicts|Obsoletes)(\([^)]*\))?:/{next}{print}' "$parent" > "$spec"
 printf '\n%%description\nQualify unchanged full27 preparation and the explicit kernel-only TPM vendor-information route. No firmware calls, full Image or physical acceptance.\n\n' >> "$spec"
 awk '/^%prep$/{emit=1}/^%build$/{exit}emit{print}' "$parent" >> "$spec"
 awk '/^%build$/{emit=1;next}/^bash boot-recipe\/src\/boot\/build-payload[.]sh /{exit}emit{print}' "$parent" >> "$spec"
 cat >> "$spec" <<'SPEC'

%build
bash qtee-information/packaging/native/check-qtee-information733.sh "$PWD" "$PWD/qtee-native-objects"

%install
install -d %{buildroot}%{_datadir}/%{name}
install -m644 qtee-information/source-commit qtee-information/parent-composition.json \
 qtee-information/manifests/qtee-information-20261115.json \
 native-generated/qtee-information733/{source.sha256,native-objects.sha256,imports.txt,core-*.json} \
 %{buildroot}%{_datadir}/%{name}/

%check
test ! -e arch/arm64/boot/Image
test ! -e qtee-native-objects/arch/arm64/boot/Image
test -s %{buildroot}%{_datadir}/%{name}/native-objects.sha256
for file in %{buildroot}%{_datadir}/%{name}/core-*.json; do
 jq -e '.refused_cases==23 and .positive_types==3 and .all_owned_references_released and (.firmware_called|not)' "$file"
done

%files
%license qtee-information/LICENSES/GPL-2.0-only.txt
%{_datadir}/%{name}/*

%changelog
* Sun Nov 15 2026 Uke contributors - 7.3.3-114
- Preserve qualified full27 and compile explicit kernel QTEE metadata discovery without firmware access.
SPEC
 unlink "$parent"
fi
printf 'Exact full27 retained; candidate28 explicit QTEE metadata prepared for %s without kernel reservation or physical acceptance\n' "$mode"
