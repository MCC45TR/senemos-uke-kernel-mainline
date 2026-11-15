#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR source worker: exact full26 SRPM plus qualified camera112 and early HWKM.
set -Eeuo pipefail
[[ $# == 2 && ! -e /etc/senemos/kernel-update.conf && ($2 == check || $2 == full) ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1"); mode=$2
manifest=$owner/manifests/hwkm-early-20261115.json
[[ ! -e $output && ! -L $output && -z $(git -C "$owner" status --porcelain) ]]
(cd "$owner"; jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 600 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{SOURCEPACKAGE}' "$work/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-26.1 ]]
rpm2cpio "$work/parent.src.rpm" > "$work/parent.cpio"
cpio -t --quiet < "$work/parent.cpio" > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$work/parent.cpio")
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$parent" | sha256sum -c --strict --quiet -
find "$output" -maxdepth 1 -type f ! -name "${parent##*/}" \
 ! -name senemos-native-profile-7.3.3.tar.xz ! -name senemos-uke-boot-recipe.tar.xz ! -name boot-payload.json \
 -print0 | sort -z | xargs -0 sha256sum > "$work/retained.sha256"
mkdir -m700 "$work/gpg" "$work/rpmdb"
curl -qfsSL --max-time 60 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/pubkey.gpg -o "$work/key.gpg"
gpg --homedir "$work/gpg" --batch --with-colons --show-keys "$work/key.gpg" | awk -F: '$1=="fpr"{print $10}' | grep -Fx 2204A661EA630A5303500085538797E72A3E4ECA
curl -qfsSL --retry 2 --retry-delay 3 --retry-max-time 180 --max-time 120 "$(jq -er .camera_proof.receipt_url "$manifest")" -o "$work/native112.rpm"
printf '%s  %s\n' "$(jq -er .camera_proof.receipt_sha256 "$manifest")" "$work/native112.rpm" | sha256sum -c --strict --quiet -
rpmkeys --dbpath "$work/rpmdb" --import "$work/key.gpg"
rpmkeys --dbpath "$work/rpmdb" --checksig --verbose "$work/native112.rpm" > "$work/native112-signature.txt"
mkdir "$work/native112"
rpm2cpio "$work/native112.rpm" | (cd "$work/native112"; cpio -idm --quiet --no-absolute-filenames)
receipt=$work/native112/usr/share/uke-kernel-migration-check
[[ $(cat "$receipt/source-commit") == f03d7eb191a98feaf03d6806c14550ff97ef3c07 ]]
cmp "$receipt/camera-crm-passive-20261114.json" "$owner/manifests/camera-crm-passive-20261114.json"
if [[ $mode == full ]]; then
 proof=$owner/manifests/hwkm-early-qualified113-20261115.json
 [[ -f $proof ]]
 curl -qfsSL --max-time 60 'https://copr.fedorainfracloud.org/api_3/build/list?ownername=mcc45tr&projectname=uke-linux-unstable&packagename=senemos-uke-linux-kernel-mainline-unstable' -o "$work/full-history.json"
 [[ $(bash "$owner/scripts/kernel-release.sh" next "$work/full-history.json" 7.3.3 senemos-uke-linux-kernel-mainline-unstable) == 27 ]]
 jq -e '.native_qualified and .source_check_release==113 and .parent_full_build==11322009 and (.hardware_key_accepted|not)' "$proof" >/dev/null
 curl -qfsSL --max-time 120 "$(jq -er .receipt_url "$proof")" -o "$work/native113.rpm"
 printf '%s  %s\n' "$(jq -er .receipt_sha256 "$proof")" "$work/native113.rpm" | sha256sum -c --strict --quiet -
 rpmkeys --dbpath "$work/rpmdb" --checksig --verbose "$work/native113.rpm" > "$work/native113-signature.txt"
 mkdir "$work/native113"
 rpm2cpio "$work/native113.rpm" | (cd "$work/native113"; cpio -idm --quiet --no-absolute-filenames)
 [[ $(cat "$work/native113/usr/share/uke-kernel-migration-check/source-commit") == "$(jq -er .source_commit "$proof")" ]]
 cmp "$manifest" "$work/native113/usr/share/uke-kernel-migration-check/hwkm-early-20261115.json"
fi
mapfile -t camera_assets < <(jq -er '.archive_assets[]' "$owner/manifests/camera-crm-passive-20261114.json")
git -C "$owner" archive --prefix=crm-passive/ HEAD "${camera_assets[@]}" \
 manifests/camera-crm-passive-20261114.json LICENSES/GPL-2.0-only.txt | tar -xf - -C "$work"
mkdir "$work/crm-passive/oracle"
curl -qfsSL --max-time 90 "$(jq -er .oem_url "$owner/manifests/camera-crm-passive-20261114.json")" -o "$work/crm-passive/oracle/camcc-cliffs.c"
printf '%s  %s\n' "$(jq -er .oem_sha256 "$owner/manifests/camera-crm-passive-20261114.json")" "$work/crm-passive/oracle/camcc-cliffs.c" | sha256sum -c --strict --quiet -
mapfile -t own_assets < <(jq -er '.source_assets[].path' "$manifest")
git -C "$owner" archive --prefix=hwkm-early/ HEAD "${own_assets[@]}" manifests/hwkm-early-20261115.json | tar -xf - -C "$work"
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$work/hwkm-early/source-commit"
cp "$work/native112-signature.txt" "$work/hwkm-early/native112-signature.txt"
if [[ $mode == full ]]; then
 cp "$work/native113.rpm" "$work/hwkm-early/native113-report.rpm"
 cp "$proof" "$work/hwkm-early/native113-qualification.json"
fi
tar -xJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile; boot=$work/boot-recipe
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
cp "$profile/source-composition.json" "$work/parent-composition.json"
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/raw-configs.sha256"
jq '.full_release=27|.source_check_release=113' "$profile/manifests/cumulative-release.json" > "$work/plan.json"
before_audio=$(awk '$2=="./src/audio/uke-audio-card.c" || $2=="src/audio/uke-audio-card.c"{print $1}' "$profile/SHA256SUMS")
[[ $before_audio =~ ^[a-f0-9]{64}$ ]]
bash "$owner/packaging/native/retarget-audio-tuple733.sh" "$profile" "$boot" "$work/plan.json" "$before_audio"
for tree in "$profile" "$boot"; do install -m644 "$work/plan.json" "$tree/manifests/cumulative-release.json"; done
install -m644 "$owner/src/boot/dracut/uke-hwkm.conf" "$boot/src/boot/dracut/uke-hwkm.conf"
node - "$boot/src/boot/dracut/module-setup.sh" <<'JS'
const fs=require('fs'),assert=require('assert/strict'),p=process.argv[2],before=fs.readFileSync(p,'utf8'),a='    inst_simple "$moddir/uke-coresight-bringup.conf" /usr/lib/modprobe.d/uke-coresight-bringup.conf\n',b=a+'    # This candidate selects wrapped keys at the first ICE probe. A later\n    # vendor ramdisk or a live parameter change cannot rebuild that profile.\n    inst_simple "$moddir/uke-hwkm.conf" /usr/lib/modprobe.d/uke-hwkm.conf\n';assert.equal(before.split(a).length,2);const after=before.replace(a,()=>b);assert.equal(after.replace(b,()=>a),before);fs.writeFileSync(p,after);
JS
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" '.+{source_commit:$commit,kernel_release:"7.3.3-27-unstable",rpm_revision:"27",diagnostic_audio_driver:"uke7_3_3-27u",
 hwkm_early_wrapped_profile:1,hwkm_hardware_key_accepted:false,hwkm_hardware_io_accepted:false,
 passive_camera_native_build:11327411,passive_camera_objects:30,passive_camera_crm_activation_allowed:false}' \
 "$work/parent-composition.json" > "$profile/source-composition.json"
jq --slurpfile before "$work/parent-composition.json" -e '. as $after|all($before[0]|to_entries[];.key as $key|(["source_commit","kernel_release","rpm_revision","diagnostic_audio_driver"]|index($key))!=null or $after[$key]==.value)' "$profile/source-composition.json" >/dev/null
sha256sum -c --strict --quiet "$work/raw-configs.sha256"
cp "$work/parent-composition.json" "$work/hwkm-early/parent-composition.json"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/boot-assets.txt"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/boot-assets.txt" > "$work/boot-assets.json"
jq --slurpfile assets "$work/boot-assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/lock.json"
cp "$work/lock.json" "$boot/lock.json"
cp "$work/lock.json" "$output/boot-payload.json"
node "$owner/packaging/native/rewrite-hwkm-early733.mjs" "$parent" "$work/full27.spec" "$manifest"
sha256sum "$work/full27.spec"
printf '%s  %s\n' "$(jq -er .result.planned_full_spec_sha256 "$manifest")" "$work/full27.spec" | sha256sum -c --strict --quiet -
cp "$work/full27.spec" "$parent"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for pair in senemos-native-profile-7.3.3.tar.xz:native-profile senemos-uke-boot-recipe.tar.xz:boot-recipe uke-hwkm-early.tar.xz:hwkm-early uke-crm-passive.tar.xz:crm-passive; do
 tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/${pair%%:*}" -C "$work" "${pair#*:}"
done
sha256sum -c --strict --quiet "$work/retained.sha256"
if [[ $mode == check ]]; then
 spec=$output/uke-kernel-migration-check.spec
 awk '/^%description/{exit}/^Name:/{$0="Name: uke-kernel-migration-check"}/^Release:/{$0="Release: 113%{?dist}"}/^Summary:/{$0="Summary: Cumulative early HWKM and passive camera qualification"}/^(Requires|Provides|Recommends|Conflicts|Obsoletes)(\([^)]*\))?:/{next}{print}' "$parent" > "$spec"
 printf '\n%%description\nQualify complete full26 preparation, passive camera112 and candidate27 early HWKM prerequisites. No full Image, firmware call or physical key acceptance.\n\n' >> "$spec"
 awk '/^%prep$/{emit=1}/^%build$/{exit}emit{print}' "$parent" >> "$spec"
 node - "$parent" "$spec" <<'JS'
const fs=require('fs'),assert=require('assert/strict'),[i,o]=process.argv.slice(2),s=fs.readFileSync(i,'utf8'),a='\n%build\n',b='bash boot-recipe/src/boot/build-payload.sh "$PWD" %{_uke_out} %{uke_boot_userspace}/base \'%{krel}\' "$jobs"\n';assert.equal(s.split(a).length,2);assert.equal(s.split(b).length,2);fs.appendFileSync(o,s.slice(s.indexOf(a)+a.length,s.indexOf(b)));
JS
 cat >> "$spec" <<'SPEC'

%build
bash hwkm-early/packaging/native/check-hwkm-early733.sh "$PWD" "$PWD/hwkm-native-objects"
bash crm-passive/tests/camcc-crm-passive-object.sh "$PWD" "$PWD/passive-object" native-profile/native.config

%install
install -d %{buildroot}%{_datadir}/%{name}
install -m644 hwkm-early/source-commit hwkm-early/parent-composition.json hwkm-early/native112-signature.txt \
 hwkm-early/manifests/hwkm-early-20261115.json native-generated/hwkm-early733/{camera-checks.txt,kmod.conf,after.sha256,native-objects.sha256} \
 %{buildroot}%{_datadir}/%{name}/

%check
test ! -e arch/arm64/boot/Image
test ! -e hwkm-native-objects/arch/arm64/boot/Image
test ! -e passive-object/arch/arm64/boot/Image
test -s %{buildroot}%{_datadir}/%{name}/native-objects.sha256

%files
%license hwkm-early/LICENSES/GPL-2.0-only.txt
%{_datadir}/%{name}/*

%changelog
* Sun Nov 15 2026 Uke contributors - 7.3.3-113
- Retain exact full26 source preparation and camera112, qualify early HWKM candidate objects.
SPEC
 unlink "$parent"
fi
printf 'Exact full26 retained; candidate27 boot opt-in and qualified camera112 source prepared for %s, with no physical/key admission\n' "$mode"
