#!/usr/bin/bash
# Single cumulative full candidate from immutable qualified source57 assets.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
manifest=$owner/manifests/mst-power-delivery-20261109.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
tuple=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json")
jq -e '.version=="7.3.3" and .release>=11 and .source_check_release==57' <<< "$tuple" >/dev/null
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 240 "$(jq -er .qualified_srpm_url "$manifest")" -o "$work/parent.rpm"
printf '%s  %s\n' "$(jq -er .qualified_srpm_sha256 "$manifest")" "$work/parent.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$work/parent.rpm") == uke-kernel-migration-check-7.3.3-57 ]]
rpm2cpio "$work/parent.rpm" | cpio -t --quiet > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
rpm2cpio "$work/parent.rpm" | (cd "$output";cpio -idm --quiet --no-absolute-filenames)
printf '%s  %s\n' "$(jq -er .qualified_spec_sha256 "$manifest")" "$output/uke-kernel-migration-check.spec" | sha256sum -c --strict --quiet -
mv "$output/uke-kernel-migration-check.spec" "$work/qualified57.spec"
url=$(curl -qfsSL --max-time 45 https://copr.fedorainfracloud.org/api_3/build-chroot/11292922/fedora-rawhide-aarch64 | jq -er '.state as $state|if $state=="succeeded" then .result_url else error("Native57 not terminal successful") end')
curl -qfsSL --max-time 90 "${url}uke-kernel-migration-check-7.3.3-57.fc46.aarch64.rpm" -o "$work/proof.rpm"
printf '%s  %s\n' "$(jq -er .qualified_receipt_sha256 "$manifest")" "$work/proof.rpm" | sha256sum -c --strict --quiet -
rpm2cpio "$work/proof.rpm" | cpio -i --to-stdout --quiet '*source-composition.json' > "$work/proof.json"
curl -qfsSL --max-time 45 "$(jq -er .full_parent_spec_url "$manifest")" -o "$work/full10.spec"
printf '%s  %s\n' "$(jq -er .full_parent_spec_sha256 "$manifest")" "$work/full10.spec" | sha256sum -c --strict --quiet -
bash "$owner/tests/mst-power-full-spec733.sh" "$owner" "$work/full10.spec"
bash "$owner/packaging/native/rewrite-mst-power-full733.sh" "$work/full10.spec" "$output/senemos-uke-linux-kernel-mainline-unstable.spec" "$owner/manifests/cumulative-release.json"
native=senemos-native-profile-7.3.3.tar.xz
tar -xJf "$output/$native" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
cmp "$work/proof.json" "$profile/source-composition.json"
jq -e '.source_commit=="94519d8219168251bbdd074ff601aaceff42d980" and .power_response_candidate_layer==1 and .mst_depth_candidate_layer==1 and .speaker_gain_ceiling==223 and (.physical_acceptance|not)' "$work/proof.json" >/dev/null
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs.sha256"
bash "$owner/tests/audio-tuple-delivery733.sh" "$owner" "$profile/src/audio/uke-audio-card.c"
bash "$owner/packaging/native/retarget-audio-tuple733.sh" "$profile" "$boot" "$owner/manifests/cumulative-release.json"
for tree in "$profile" "$boot";do
 while IFS= read -r file;do install -Dm644 "$owner/$file" "$tree/$file";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/mst-power-delivery-20261109.json"
 install -Dm644 "$owner/manifests/cumulative-release.json" "$tree/manifests/cumulative-release.json"
done
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --argjson tuple "$tuple" '.+{
 source_commit:$commit,kernel_release:$tuple.kernel_release,rpm_revision:($tuple.release|tostring),
 diagnostic_audio_driver:$tuple.audio_driver,
 mst_power_delivery_layer:1,mst_power_qualified_source:"94519d8219168251bbdd074ff601aaceff42d980",
 mst_power_native_qualification_build:11292922,mst_power_full_recipe_prepared:true,
 mst_power_full_linked_accepted:false,mst_power_physical_accepted:false,
 storage_encryption_enabled_in_full_candidate:false
}' "$work/proof.json" > "$work/composition.json"
install -m644 "$work/composition.json" "$profile/source-composition.json"
# Only tuple/recipe provenance may differ from the complete native receipt.
jq --slurpfile old "$work/proof.json" -e '. as $new|all($old[0]|to_entries[];
 .key as $key|(["source_commit","kernel_release","rpm_revision","diagnostic_audio_driver"]|index($key))!=null or $new[$key]==.value)' "$profile/source-composition.json" >/dev/null
sha256sum -c --strict --quiet "$work/configs.sha256"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/boot-assets"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/boot-assets" > "$work/assets.json"
jq --slurpfile assets "$work/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/lock.json"
install -m644 "$work/lock.json" "$boot/lock.json"
install -m644 "$work/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work" boot-recipe
printf 'Full11 prepared from exact admitted57 assets and full10 spec; MST/power delivery, production config and all existing phases retained.\n'
