#!/usr/bin/bash
# One cumulative production kernel from the admitted parent and gravity proof.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/gravity-delivery-20261110.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
tuple=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json")
jq --argjson tuple "$tuple" -e '.parent_full_release+1==$tuple.release and
 .proof.source_check_release==$tuple.source_check_release and $tuple.version=="7.3.3"' "$manifest" >/dev/null
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 240 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$work/parent.rpm") == "senemos-uke-linux-kernel-mainline-unstable-7.3.3-$(jq -er .parent_full_release "$manifest")" ]]
rpm2cpio "$work/parent.rpm" | cpio -t --quiet > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
rpm2cpio "$work/parent.rpm" | (cd "$output";cpio -idm --quiet --no-absolute-filenames)
mv "$output/senemos-uke-linux-kernel-mainline-unstable.spec" "$work/parent.spec"
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$work/parent.spec" | sha256sum -c --strict --quiet -
id=$(jq -er .proof.build "$manifest")
version=$(jq -er .proof.version "$manifest")
url=$(curl -qfsSL --max-time 40 "https://copr.fedorainfracloud.org/api_3/build-chroot/$id/fedora-rawhide-aarch64" | jq -er 'if .state=="succeeded" then .result_url else error("Unqualified gravity source") end')
curl -qfsSL --max-time 60 "$url""uke-kernel-migration-check-$version.fc46.aarch64.rpm" -o "$work/proof.rpm"
printf '%s  %s\n' "$(jq -er .proof.receipt_sha256 "$manifest")" "$work/proof.rpm" | sha256sum -c --strict --quiet -
rpm2cpio "$work/proof.rpm" | cpio -i --to-stdout --quiet '*gravity-source-qualification.json' > "$work/proof.json"
jq --arg source "$(jq -er .proof.source "$manifest")" --argjson proof "$(jq -er .proof.source_check_release "$manifest")" -e '.source_commit==$source and .source_check_release==$proof and
 .parent_full_build==11295536 and (.channels|length)==6 and .standard_linear_modifiers and
 .protected_gain==223 and (.physical_accepted|not)' "$work/proof.json" >/dev/null
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$work/proof.json" | sha256sum -c --strict --quiet -)
bash "$owner/packaging/native/rewrite-gravity-full733.sh" "$work/parent.spec" "$output/senemos-uke-linux-kernel-mainline-unstable.spec" "$manifest" "$owner/manifests/cumulative-release.json"
curl -qfsSL --max-time 40 --max-filesize 1048576 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11297002/senemos-uke-linux-kernel-mainline-unstable.spec -o "$work/unscoped.spec"
printf '%s  %s\n' 3abbb18d3366f193929a753fa2689c3385e44cfbac2b1e4dfe5051efdde8a5d3 "$work/unscoped.spec" | sha256sum -c --strict --quiet -
bash "$owner/tests/gravity-recipe-scope.sh" "$output/senemos-uke-linux-kernel-mainline-unstable.spec" "$work/unscoped.spec"
tar -xJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq -e '.source_commit=="780dd1a0642bad824e3d6491d4f7a8fb4e0fc665" and .kernel_release=="7.3.3-13-unstable" and .speaker_gain_ceiling==223' "$profile/source-composition.json" >/dev/null
cp "$profile/source-composition.json" "$work/composition-parent.json"
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs.sha256"
bash "$owner/packaging/native/retarget-audio-tuple733.sh" "$profile" "$boot" "$owner/manifests/cumulative-release.json" "$(jq -er .parent_audio_card_sha256 "$manifest")"
for tree in "$profile" "$boot";do
 while IFS= read -r path;do install -Dm644 "$owner/$path" "$tree/$path";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/gravity-delivery-20261110.json"
 install -Dm644 "$owner/manifests/cumulative-release.json" "$tree/manifests/cumulative-release.json"
done
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --argjson tuple "$tuple" --arg source "$(jq -er .proof.source "$manifest")" --argjson build "$(jq -er .proof.build "$manifest")" '.+{
 source_commit:$commit,kernel_release:$tuple.kernel_release,rpm_revision:($tuple.release|tostring),diagnostic_audio_driver:$tuple.audio_driver,
 ssc_gravity_layer:1,ssc_gravity_native_admitted:true,ssc_gravity_source:$source,ssc_gravity_native_build:$build,
 ssc_gravity_channels:6,ssc_gravity_standard_linear_axes:true,ssc_gravity_physical_accepted:false,ssc_gravity_legacy_projection:true
}' "$work/composition-parent.json" > "$profile/source-composition.json"
jq --slurpfile old "$work/composition-parent.json" -e '. as $new|all($old[0]|to_entries[];
 .key as $key|(["source_commit","kernel_release","rpm_revision","diagnostic_audio_driver"]|index($key))!=null or $new[$key]==.value)' "$profile/source-composition.json" >/dev/null
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
printf 'Cumulative gravity delivery prepared: full parent recipe/config/features, exact qualified source, central tuple, protected gain223 and six runtime names retained.\n'
