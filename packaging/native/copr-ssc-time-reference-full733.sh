#!/usr/bin/bash
# Cumulative full26: exact full25 plus the separately qualified SSC diagnostic.
set -Eeuo pipefail
[[ $# == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/ssc-time-reference-delivery-20261113.json
[[ ! -e $output && ! -L $output && -z $(git -C "$owner" status --porcelain) ]]
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --max-time 60 'https://copr.fedorainfracloud.org/api_3/build/list?ownername=mcc45tr&projectname=uke-linux-unstable&limit=1000&order=id&order_type=DESC' > "$work/history.json"
jq -e '(.items|length)<1000' "$work/history.json" >/dev/null
jq '{items:[.items[]|select(.source_package.name=="senemos-uke-linux-kernel-mainline-unstable")]}' "$work/history.json" > "$work/family.json"
[[ $(bash "$owner/scripts/kernel-release.sh" next "$work/family.json" 7.3.3 senemos-uke-linux-kernel-mainline-unstable) == 26 ]]
curl -qfsSL --retry 2 --max-time 600 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{SOURCEPACKAGE}' "$work/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-25.1 ]]
rpm2cpio "$work/parent.src.rpm" > "$work/parent.cpio"
cpio -t --quiet < "$work/parent.cpio" > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
(cd "$output";cpio -idm --quiet --no-absolute-filenames < "$work/parent.cpio")
mv "$output/senemos-uke-linux-kernel-mainline-unstable.spec" "$work/parent.spec"
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$work/parent.spec" | sha256sum -c --strict --quiet -
for pair in parent_profile_sha256:senemos-native-profile-7.3.3.tar.xz parent_boot_recipe_sha256:senemos-uke-boot-recipe.tar.xz;do
 printf '%s  %s\n' "$(jq -er ".${pair%%:*}" "$manifest")" "$output/${pair#*:}" | sha256sum -c --strict --quiet -
done
find "$output" -maxdepth 1 -type f ! -name senemos-native-profile-7.3.3.tar.xz ! -name senemos-uke-boot-recipe.tar.xz ! -name boot-payload.json -print0 | sort -z | xargs -0 sha256sum > "$work/retained.sha256"
for pair in receipt_sha256:receipt_url qualification_sha256:qualification_url incremental_source_sha256:incremental_source_url;do
 key=${pair%%:*};urlkey=${pair#*:}
 curl -qfsSL --retry 2 --max-time 180 "$(jq -er ".proof.$urlkey" "$manifest")" -o "$work/$key"
 printf '%s  %s\n' "$(jq -er ".proof.$key" "$manifest")" "$work/$key" | sha256sum -c --strict --quiet -
done
mkdir -m700 "$work/gnupg" "$work/rpmdb"
curl -qfsSL --max-time 60 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/pubkey.gpg -o "$work/signing-key.asc"
gpg --homedir "$work/gnupg" --batch --show-keys --with-colons "$work/signing-key.asc" | awk -F: '$1=="fpr"{print $10}' | grep -Fx 2204A661EA630A5303500085538797E72A3E4ECA
rpm --dbpath "$work/rpmdb" --initdb
rpmkeys --dbpath "$work/rpmdb" --import "$work/signing-key.asc"
rpmkeys --dbpath "$work/rpmdb" --checksig --verbose "$work/receipt_sha256" > "$work/signatures.txt"
[[ $(grep -c 'key fingerprint: 2204a661ea630a5303500085538797e72a3e4eca: OK' "$work/signatures.txt") == 2 ]]
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}' "$work/receipt_sha256") == uke-kernel-migration-check-7.3.3-110.fc46.aarch64 ]]
mkdir "$work/bundle" "$work/report"
tar -tJf "$work/incremental_source_sha256" > "$work/bundle-paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/bundle-paths"
tar -xJf "$work/incremental_source_sha256" -C "$work/bundle"
tar -xJf "$work/bundle/actual-source/uke-ssc-time-reference.tar.xz" -C "$work"
mv "$work/ssc-time-reference" "$work/ssc-time-reference-full"
rpm2cpio "$work/receipt_sha256" | (cd "$work/report";cpio -idm --quiet --no-absolute-filenames)
node - "$work" "$manifest" <<'JS'
const fs=require('fs'),assert=require('assert/strict'),c=require('crypto'),[w,f]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(f)),q=JSON.parse(fs.readFileSync(w+'/qualification_sha256')),r=w+'/report/usr/share/uke-kernel-migration-check',sha=p=>c.createHash('sha256').update(fs.readFileSync(p)).digest('hex');assert.equal(q.build,m.proof.build);assert.equal(q.source_check_release,110);assert.equal(q.parent_native_build,11318588);assert(q.native_qualified&&q.actual_final_ssc_aarch64_object&&!q.clock_mapping_admitted&&!q.gravity_frame_admitted&&!q.full_kernel_built&&!q.device_changed);assert.equal(q.report_sha256,m.proof.receipt_sha256);assert.equal(q.source_commit,m.proof.source);assert.equal(fs.readFileSync(r+'/source-commit','utf8').trim(),m.proof.source);assert.equal(sha(r+'/ssc-time-reference-20261113.json'),sha(w+'/ssc-time-reference-full/manifests/ssc-time-reference-20261113.json'));assert.equal(sha(w+'/bundle/actual-source/uke-ssc-time-reference.tar.xz'),q.source_packet_sha256);const checks=fs.readFileSync(r+'/camcc-resource-checks.txt','utf8');for(const [marker,count]of Object.entries(q.all_native_marker_counts))assert.equal(checks.split(marker).length-1,count,marker);
JS
(cd "$work/ssc-time-reference-full";jq -r '.source_assets[]|.sha256+"  "+.path' manifests/ssc-time-reference-20261113.json | sha256sum -c --strict --quiet -)
mv "$work/ssc-time-reference-full/source-commit" "$work/ssc-time-reference-full/native110-source-commit"
mapfile -t assets < <(jq -er '.source_assets[].path' "$manifest")
git -C "$owner" archive --prefix=ssc-time-reference-full/ HEAD "${assets[@]}" manifests/ssc-time-reference-delivery-20261113.json | tar -xf - -C "$work"
mkdir "$work/ssc-time-reference-full/proof"
install -m644 "$work/receipt_sha256" "$work/ssc-time-reference-full/proof/native110-report.rpm"
install -m644 "$work/qualification_sha256" "$work/ssc-time-reference-full/proof/native110-qualification.json"
git -C "$owner" rev-parse HEAD > "$work/ssc-time-reference-full/source-commit"
tar -xJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile;boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq '.full_release=26|.source_check_release=110' "$profile/manifests/cumulative-release.json" > "$work/full-plan.json"
tuple=$(bash "$owner/scripts/kernel-release.sh" json "$work/full-plan.json")
node "$owner/packaging/native/rewrite-ssc-time-reference-full733.mjs" "$work/parent.spec" "$output/senemos-uke-linux-kernel-mainline-unstable.spec" "$manifest" "$tuple"
cp "$profile/source-composition.json" "$work/parent-composition.json"
[[ $(jq 'keys|length' "$work/parent-composition.json") == 793 ]]
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs.sha256"
bash "$owner/packaging/native/retarget-audio-tuple733.sh" "$profile" "$boot" "$work/full-plan.json" "$(jq -er .parent_audio_card_sha256 "$manifest")"
for tree in "$profile" "$boot";do install -m644 "$work/full-plan.json" "$tree/manifests/cumulative-release.json";done
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --argjson tuple "$tuple" --argjson build "$(jq -er .proof.build "$manifest")" '.+{source_commit:$commit,kernel_release:$tuple.kernel_release,rpm_revision:($tuple.release|tostring),diagnostic_audio_driver:$tuple.audio_driver,ssc_time_reference_diagnostic_layer:1,ssc_time_reference_native_build:$build,ssc_time_reference_native_release:110,ssc_time_reference_root_mode:"0400",ssc_time_reference_demand_only:true,ssc_time_reference_clock_mapping_admitted:false,ssc_time_reference_gravity_frame_admitted:false,ssc_time_reference_production_motion_admission:false}' "$work/parent-composition.json" > "$profile/source-composition.json"
jq --slurpfile old "$work/parent-composition.json" -e '. as $new|all($old[0]|to_entries[];.key as $key|(["source_commit","kernel_release","rpm_revision","diagnostic_audio_driver"]|index($key))!=null or $new[$key]==.value)' "$profile/source-composition.json" >/dev/null
sha256sum -c --strict --quiet "$work/configs.sha256"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/boot-assets"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/boot-assets" > "$work/assets.json"
jq --slurpfile assets "$work/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/lock.json"
install -m644 "$work/lock.json" "$boot/lock.json"
install -m644 "$work/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for pair in senemos-native-profile-7.3.3.tar.xz:native-profile senemos-uke-boot-recipe.tar.xz:boot-recipe uke-ssc-time-reference-delivery.tar.xz:ssc-time-reference-full;do
 tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/${pair%%:*}" -C "$work" "${pair#*:}"
done
sha256sum -c --strict --quiet "$work/retained.sha256"
printf 'Cumulative full26 source:exact full25/793 parent fields except four tuple/provenance keys,raw configs,all old checks and signed native110 diagnostic;no device or physical admission\n'
