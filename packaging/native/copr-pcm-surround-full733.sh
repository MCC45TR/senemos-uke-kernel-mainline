#!/usr/bin/bash
# One cumulative full13 from admitted full12 and independently pinned proofs.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/pcm-surround-delivery-20261110.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
tuple=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json")
jq -e '.version=="7.3.3" and .release==13 and .source_check_release==72' <<< "$tuple" >/dev/null
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 240 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$work/parent.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-12 ]]
rpm2cpio "$work/parent.rpm" | cpio -t --quiet > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
rpm2cpio "$work/parent.rpm" | (cd "$output";cpio -idm --quiet --no-absolute-filenames)
mv "$output/senemos-uke-linux-kernel-mainline-unstable.spec" "$work/full12.spec"
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$work/full12.spec" | sha256sum -c --strict --quiet -
for proof in pcm profiles;do
 id=$(jq -er ".proofs.$proof.build" "$manifest")
 version=$(jq -er ".proofs.$proof.version" "$manifest")
 url=$(curl -qfsSL --max-time 40 "https://copr.fedorainfracloud.org/api_3/build-chroot/$id/fedora-rawhide-aarch64" | jq -er 'if .state=="succeeded" then .result_url else error("Unqualified source") end')
 curl -qfsSL --max-time 60 "${url}uke-kernel-migration-check-$version.fc46.aarch64.rpm" -o "$work/$proof.rpm"
 printf '%s  %s\n' "$(jq -er ".proofs.$proof.receipt_sha256" "$manifest")" "$work/$proof.rpm" | sha256sum -c --strict --quiet -
done
rpm2cpio "$work/pcm.rpm" | cpio -i --to-stdout --quiet '*pcm-surround-qualification.json' > "$work/pcm.json"
rpm2cpio "$work/profiles.rpm" | cpio -i --to-stdout --quiet '*surround-profile-qualification.json' > "$work/profiles.json"
jq --arg sha "$(jq -er .proofs.pcm.source "$manifest")" -e '.source_commit==$sha and .source_check_release==72 and .parent_full_build==11293945 and .physical_output_count==4 and .protected_gain==223 and (.physical_accepted|not)' "$work/pcm.json" >/dev/null
jq -e '.source_commit=="3421d4be69e5e0a85d01ca677ebea1a51b086269" and .source_check_release==69 and .physical_output_count==4 and .protected_gain==223 and (.physical_accepted|not)' "$work/profiles.json" >/dev/null
# Each delivered source asset must be exactly the qualified one.
for proof in pcm profiles;do
 (cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$work/$proof.json" | sha256sum -c --strict --quiet -)
done
bash "$owner/packaging/native/rewrite-pcm-surround-full733.sh" "$work/full12.spec" "$output/senemos-uke-linux-kernel-mainline-unstable.spec" "$owner/manifests/cumulative-release.json"
tar -xJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq -e '.source_commit=="b14c66405258832ccf92ba9a46cfceb03f635755" and .kernel_release=="7.3.3-12-unstable" and .speaker_gain_ceiling==223' "$profile/source-composition.json" >/dev/null
cp "$profile/source-composition.json" "$work/composition12.json"
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs.sha256"
bash "$owner/packaging/native/retarget-audio-tuple733.sh" "$profile" "$boot" "$owner/manifests/cumulative-release.json" "$(jq -er .parent_audio_card_sha256 "$manifest")"
for tree in "$profile" "$boot";do
 printf '%s  %s\n' 41da7286b53e9ae958a4472d0f9152081162ba37e9279c0f4db9cb3f8e592c4c "$tree/packaging/native/prepare-surround-full733.sh" | sha256sum -c --strict --quiet -
 while IFS= read -r path;do install -Dm644 "$owner/$path" "$tree/$path";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/pcm-surround-delivery-20261110.json"
 install -Dm644 "$owner/manifests/cumulative-release.json" "$tree/manifests/cumulative-release.json"
done
mkdir -p "$profile/referances"
parser=$owner/manifests/speaker-surround-profiles-20261110.json
curl -qfsSL --max-time 60 "$(jq -er .alsa_ucm_source.url "$parser")" -o "$profile/referances/alsa-ucm-parser.c"
printf '%s  %s\n' "$(jq -er .alsa_ucm_source.sha256 "$parser")" "$profile/referances/alsa-ucm-parser.c" | sha256sum -c --strict --quiet -
curl -qfsSL --max-time 60 "$(jq -er .alsa_ucm_source.license_url "$parser")" -o "$profile/referances/COPYING.alsa-lib"
printf '%s  %s\n' "$(jq -er .alsa_ucm_source.license_sha256 "$parser")" "$profile/referances/COPYING.alsa-lib" | sha256sum -c --strict --quiet -
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --argjson tuple "$tuple" --arg pcm "$(jq -er .proofs.pcm.source "$manifest")" --argjson build "$(jq -er .proofs.pcm.build "$manifest")" '.+{
 source_commit:$commit,kernel_release:$tuple.kernel_release,rpm_revision:($tuple.release|tostring),diagnostic_audio_driver:$tuple.audio_driver,
 speaker_surround_profile_build:11295383,speaker_surround_profile_source:"3421d4be69e5e0a85d01ca677ebea1a51b086269",
 speaker_ucm_semantic_names_admitted:true,pcm_surround_layer:1,pcm_surround_native_admitted:true,pcm_surround_source:$pcm,pcm_surround_native_build:$build,
 pcm_surround_max_channels:8,pcm_surround_logical_media_lengths:true,pcm_surround_dma_changed:false,pcm_surround_physical_accepted:false
}' "$work/composition12.json" > "$profile/source-composition.json"
jq --slurpfile old "$work/composition12.json" -e '. as $new|all($old[0]|to_entries[];
 .key as $key|(["source_commit","kernel_release","rpm_revision","diagnostic_audio_driver","speaker_surround_profile_build","speaker_surround_profile_source"]|index($key))!=null or $new[$key]==.value)' "$profile/source-composition.json" >/dev/null
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
printf 'Cumulative full13 prepared from full12 and pinned PCM/semantic proofs; existing config/features/gates, gain223 and six runtime names retained.\n'
