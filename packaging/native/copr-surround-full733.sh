#!/usr/bin/bash
# One cumulative candidate from immutable source65 and focused profile67.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/speaker-surround-delivery-20261110.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
tuple=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json")
jq -e '.version=="7.3.3" and .release==12 and .source_check_release==65' <<< "$tuple" >/dev/null
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 240 "$(jq -er .qualified_srpm_url "$manifest")" -o "$work/source65.rpm"
printf '%s  %s\n' "$(jq -er .qualified_srpm_sha256 "$manifest")" "$work/source65.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$work/source65.rpm") == uke-kernel-migration-check-7.3.3-65 ]]
rpm2cpio "$work/source65.rpm" | cpio -t --quiet > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
rpm2cpio "$work/source65.rpm" | (cd "$output";cpio -idm --quiet --no-absolute-filenames)
printf '%s  %s\n' "$(jq -er .qualified_spec_sha256 "$manifest")" "$output/uke-kernel-migration-check.spec" | sha256sum -c --strict --quiet -
mv "$output/uke-kernel-migration-check.spec" "$work/source65.spec"
for proof in stream profiles;do
 id=$(jq -er ".proofs.$proof.build" "$manifest")
 version=$(jq -er ".proofs.$proof.version" "$manifest")
 url=$(curl -qfsSL --max-time 40 "https://copr.fedorainfracloud.org/api_3/build-chroot/$id/fedora-rawhide-aarch64" | jq -er 'if .state=="succeeded" then .result_url else error("Unqualified parent") end')
 curl -qfsSL --max-time 60 "${url}uke-kernel-migration-check-$version.fc46.aarch64.rpm" -o "$work/$proof.rpm"
 printf '%s  %s\n' "$(jq -er ".proofs.$proof.receipt_sha256" "$manifest")" "$work/$proof.rpm" | sha256sum -c --strict --quiet -
done
rpm2cpio "$work/stream.rpm" | cpio -i --to-stdout --quiet '*source-composition.json' > "$work/proof65.json"
rpm2cpio "$work/profiles.rpm" | cpio -i --to-stdout --quiet '*surround-profile-qualification.json' > "$work/profiles67.json"
jq -e '.source_commit=="5472538a8d64416b985e4469ab3aa259e080fd4b" and .required_stream_build==11293736 and .physical_output_count==4 and .protected_gain==223 and (.physical_accepted|not)' "$work/profiles67.json" >/dev/null
curl -qfsSL --max-time 40 "$(jq -er .full_parent_spec_url "$manifest")" -o "$work/full11.spec"
bash "$owner/tests/surround-full-spec733.sh" "$owner" "$work/full11.spec"
bash "$owner/packaging/native/rewrite-surround-full733.sh" "$work/full11.spec" "$output/senemos-uke-linux-kernel-mainline-unstable.spec" "$owner/manifests/cumulative-release.json"
tar -xJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
cmp "$work/proof65.json" "$profile/source-composition.json"
jq -e '.source_commit=="584afd2ea3a9426863e9e45a765a4edfb1aa3f08" and .speaker_surround_stream_layer==1 and .audio_health_freezable_queue_sites==6 and .speaker_gain_ceiling==223 and (.physical_acceptance|not)' "$work/proof65.json" >/dev/null
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs.sha256"
bash "$owner/packaging/native/retarget-audio-tuple733.sh" "$profile" "$boot" "$owner/manifests/cumulative-release.json" "$(jq -er .parent_audio_card_sha256 "$manifest")"
for tree in "$profile" "$boot";do
 while IFS= read -r path;do install -Dm644 "$owner/$path" "$tree/$path";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/speaker-surround-delivery-20261110.json"
 install -Dm644 "$owner/manifests/cumulative-release.json" "$tree/manifests/cumulative-release.json"
 git -C "$tree" apply --check --whitespace=error "$owner/src/audio/0032-surround-delivery-views.patch"
 git -C "$tree" apply --whitespace=error "$owner/src/audio/0032-surround-delivery-views.patch"
done
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --argjson tuple "$tuple" '.+{
 source_commit:$commit,kernel_release:$tuple.kernel_release,rpm_revision:($tuple.release|tostring),diagnostic_audio_driver:$tuple.audio_driver,
 speaker_surround_native_admitted:true,speaker_surround_coeff_native_admitted:true,speaker_surround_stream_native_admitted:true,audio_freezable_worker_native_admitted:true,
 speaker_surround_delivery_layer:1,speaker_surround_qualified_source:"584afd2ea3a9426863e9e45a765a4edfb1aa3f08",speaker_surround_native_build:11293736,speaker_surround_profile_build:11293867,
 speaker_surround_profile_source:"5472538a8d64416b985e4469ab3aa259e080fd4b",speaker_surround_topology_fe_max:8,speaker_surround_profiles_prepared:true,
 speaker_surround_full_linked_accepted:false,speaker_surround_physical_accepted:false,audio_system_sleep_physical_accepted:false
}' "$work/proof65.json" > "$work/composition.json"
install -m644 "$work/composition.json" "$profile/source-composition.json"
# A qualification flag is promoted only from its pinned successful proof.
# All other feature fields remain byte/structure-equivalent to native65.
jq --slurpfile old "$work/proof65.json" -e '. as $new|all($old[0]|to_entries[];
 .key as $key|(["source_commit","kernel_release","rpm_revision","diagnostic_audio_driver","speaker_surround_native_admitted","speaker_surround_coeff_native_admitted","speaker_surround_stream_native_admitted","audio_freezable_worker_native_admitted"]|index($key))!=null or $new[$key]==.value)' "$profile/source-composition.json" >/dev/null
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
printf 'Cumulative full12 prepared from source65/profile67 and admitted full11 recipe; unchanged production config, four physical outputs and223 protection.\n'
