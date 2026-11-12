#!/usr/bin/bash
# One cumulative unstable candidate from accepted24 and signed native108.
set -Eeuo pipefail
[[ ! -e /etc/senemos/kernel-update.conf && $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/native-hardware-delivery-20261113.json
[[ ! -e $output && ! -L $output && -z $(git -C "$owner" status --porcelain) ]]
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --max-time 60 'https://copr.fedorainfracloud.org/api_3/build/list?ownername=mcc45tr&projectname=uke-linux-unstable&limit=1000&order=id&order_type=DESC' > "$work/history.json"
jq -e '(.items|length)<1000' "$work/history.json" >/dev/null
jq '{items:[.items[]|select(.source_package.name=="senemos-uke-linux-kernel-mainline-unstable")]}' "$work/history.json" > "$work/family.json"
release=$(bash "$owner/scripts/kernel-release.sh" next "$work/family.json" 7.3.3 senemos-uke-linux-kernel-mainline-unstable)
[[ $release == 25 ]]
curl -qfsSL --retry 2 --max-time 600 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$work/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-24 ]]
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
curl -qfsSL --max-time 60 "$(jq -er .proof.public_key_url "$manifest")" -o "$work/signing-key.asc"
gpg --homedir "$work/gnupg" --batch --show-keys --with-colons "$work/signing-key.asc" | awk -F: '$1=="fpr"{print $10}' > "$work/fingerprints"
grep -Fx 2204A661EA630A5303500085538797E72A3E4ECA "$work/fingerprints"
rpm --dbpath "$work/rpmdb" --initdb
rpmkeys --dbpath "$work/rpmdb" --import "$work/signing-key.asc"
rpmkeys --dbpath "$work/rpmdb" --checksig --verbose "$work/receipt_sha256" > "$work/signatures.txt"
[[ $(grep -c 'key fingerprint: 2204a661ea630a5303500085538797e72a3e4eca: OK' "$work/signatures.txt") == 2 ]]
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}' "$work/receipt_sha256") == uke-kernel-migration-check-7.3.3-108.fc46.aarch64 ]]
tar -tJf "$work/incremental_source_sha256" > "$work/bundle-paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/bundle-paths"
mkdir "$work/bundle" "$work/report"
tar -xJf "$work/incremental_source_sha256" -C "$work/bundle"
rpm2cpio "$work/receipt_sha256" | (cd "$work/report";cpio -idm --quiet --no-absolute-filenames)
tar -xJf "$work/bundle/actual-source/uke-camcc-resource.tar.xz" -C "$work"
tar -xJf "$work/bundle/actual-source/uke-ssc-stream-freshness.tar.xz" -C "$work"
mkdir "$work/native-hardware"
mv "$work/camcc-resource" "$work/native-hardware/camcc"
mv "$work/ssc-stream-freshness" "$work/native-hardware/ssc"
node - "$work" "$manifest" <<'JS'
const fs=require('fs'),crypto=require('crypto'),[w,f]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(f)),q=JSON.parse(fs.readFileSync(w+'/qualification_sha256')),sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'),r=w+'/report/usr/share/uke-kernel-migration-check';if(q.build!==11318588||!q.native_qualified||q.report_sha256!==m.proof.receipt_sha256||q.source_commit!==m.proof.source||q.parent_full_build!==11309609||q.actual_ssc_objects!==2||q.complete_runtime_units!==16||q.device_changed||q.full_kernel_built||q.gravity_frame_admitted)throw Error('Native admission drift');if(fs.readFileSync(r+'/source-commit','utf8').trim()!==m.proof.source)throw Error('Signed report source');for(const [packet,name]of [['camcc','camera-crmc-owner-20261113.json'],['ssc','ssc-stream-freshness-20261113.json']])if(sha(r+'/'+name)!==sha(w+'/native-hardware/'+packet+'/manifests/'+name))throw Error('Signed source packet');const checks=fs.readFileSync(r+'/camcc-resource-checks.txt','utf8');for(const [marker,count]of Object.entries(q.all_native_marker_counts))if(checks.split(marker).length-1!==count)throw Error('Native result count');
JS
for packet in camcc ssc;do
 name=camera-crmc-owner-20261113.json;[[ $packet != ssc ]] || name=ssc-stream-freshness-20261113.json
 (cd "$work/native-hardware/$packet";jq -r '.source_assets[]|.sha256+"  "+.path' "manifests/$name" | sha256sum -c --strict --quiet -)
done
mapfile -t assets < <(jq -er '.source_assets[].path' "$manifest")
git -C "$owner" archive --prefix=native-hardware/ HEAD "${assets[@]}" manifests/native-hardware-delivery-20261113.json | tar -xf - -C "$work"
mkdir "$work/native-hardware/proof"
install -m644 "$work/receipt_sha256" "$work/native-hardware/proof/native108-report.rpm"
install -m644 "$work/qualification_sha256" "$work/native-hardware/proof/native108-qualification.json"
git -C "$owner" rev-parse HEAD > "$work/native-hardware/source-commit"
tar -xJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile;boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq '.full_release=25|.source_check_release=108' "$profile/manifests/cumulative-release.json" > "$work/full-plan.json"
tuple=$(bash "$owner/scripts/kernel-release.sh" json "$work/full-plan.json")
bash "$owner/packaging/native/rewrite-native-hardware-full733.sh" "$work/parent.spec" "$output/senemos-uke-linux-kernel-mainline-unstable.spec" "$manifest" "$work/full-plan.json"
cp "$profile/source-composition.json" "$work/parent-composition.json"
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs.sha256"
bash "$owner/packaging/native/retarget-audio-tuple733.sh" "$profile" "$boot" "$work/full-plan.json" "$(jq -er .parent_audio_card_sha256 "$manifest")"
for tree in "$profile" "$boot";do install -m644 "$work/full-plan.json" "$tree/manifests/cumulative-release.json";done
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --argjson tuple "$tuple" '.+{source_commit:$commit,kernel_release:$tuple.kernel_release,rpm_revision:($tuple.release|tostring),diagnostic_audio_driver:$tuple.audio_driver,native_hardware_resource_layer:1,native_hardware_source_build:11318588,native_hardware_source_release:108,native_hardware_source_qualified:true,native_hardware_runtime_source_units:18,native_hardware_camcc_permanent_crmc:true,native_hardware_crm_activation_allowed:false,native_hardware_gravity_frame_admitted:false,native_hardware_ssc_streaming_buffer_freshness:true,native_hardware_physical_camera_accepted:false,native_hardware_physical_sensor_accepted:false}' "$work/parent-composition.json" > "$profile/source-composition.json"
jq --slurpfile old "$work/parent-composition.json" -e '. as $new|all($old[0]|to_entries[];.key as $key|(["source_commit","kernel_release","rpm_revision","diagnostic_audio_driver"]|index($key))!=null or $new[$key]==.value)' "$profile/source-composition.json" >/dev/null
sha256sum -c --strict --quiet "$work/configs.sha256"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/boot-assets"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/boot-assets" > "$work/assets.json"
jq --slurpfile assets "$work/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/lock.json"
install -m644 "$work/lock.json" "$boot/lock.json"
install -m644 "$work/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work" boot-recipe
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/uke-native-hardware-delivery.tar.xz" -C "$work" native-hardware
sha256sum -c --strict --quiet "$work/retained.sha256"
printf 'Cumulative full25 source prepared from exact full24 plus signed native108; all782 parent fields/raw configs/old checks retained except declared tuple provenance. No device or physical admission.\n'
