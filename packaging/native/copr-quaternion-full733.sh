#!/usr/bin/bash
# One cumulative full kernel from the admitted full14 and quaternion79 inputs.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/quaternion-delivery-20261110.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
# A qualified source receipt is not the allocator's next unbuilt check ID.
# Derive the full revision from complete successful-family history instead.
curl -qfsSL --max-time 40 'https://copr.fedorainfracloud.org/api_3/build/list?ownername=mcc45tr&projectname=uke-linux-unstable&limit=1000&order=id&order_type=DESC' > "$work/history.json"
jq -e '(.items|length)<1000' "$work/history.json" >/dev/null
jq '{items:[.items[]|select(.source_package.name=="senemos-uke-linux-kernel-mainline-unstable")]}' "$work/history.json" > "$work/family-history.json"
version=$(jq -er .upstream.version "$owner/manifests/cumulative-release.json")
full=$(bash "$owner/scripts/kernel-release.sh" next "$work/family-history.json" "$version" senemos-uke-linux-kernel-mainline-unstable)
proof_release=$(jq -er .proof.source_check_release "$manifest")
jq --argjson full "$full" --argjson check "$proof_release" '.full_release=$full|.source_check_release=$check' "$owner/manifests/cumulative-release.json" > "$work/full-plan.json"
tuple=$(bash "$owner/scripts/kernel-release.sh" json "$work/full-plan.json")
jq --argjson tuple "$tuple" -e '.parent_full_release+1==$tuple.release and
 .proof.source_check_release==$tuple.source_check_release and $tuple.version=="7.3.3"' "$manifest" >/dev/null
printf 'Derived cumulative tuple:%s; admitted quaternion source:%s; successful-only full revision.\n' "$(jq -er .kernel_release <<< "$tuple")" "$proof_release"
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
receipt_version=$(jq -er .proof.version "$manifest")
url=$(curl -qfsSL --max-time 40 "https://copr.fedorainfracloud.org/api_3/build-chroot/$id/fedora-rawhide-aarch64" | jq -er 'if .state=="succeeded" then .result_url else error("Unqualified quaternion source") end')
curl -qfsSL --max-time 60 "${url}uke-kernel-migration-check-$receipt_version.fc46.aarch64.rpm" -o "$work/proof.rpm"
printf '%s  %s\n' "$(jq -er .proof.receipt_sha256 "$manifest")" "$work/proof.rpm" | sha256sum -c --strict --quiet -
rpm2cpio "$work/proof.rpm" | cpio -i --to-stdout --quiet '*quaternion-source-qualification.json' > "$work/proof.json"
jq --arg source "$(jq -er .proof.source "$manifest")" --argjson proof "$proof_release" -e '.source_commit==$source and .source_check_release==$proof and
 .parent_full_build==11297525 and .datatypes==["rotv","game_rv","geomag_rv"] and .components==["x","y","z","w"] and
 .protected_gain==223 and (.physical_accepted|not)' "$work/proof.json" >/dev/null
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$work/proof.json" | sha256sum -c --strict --quiet -)
bash "$owner/packaging/native/rewrite-quaternion-full733.sh" "$work/parent.spec" "$output/senemos-uke-linux-kernel-mainline-unstable.spec" "$manifest" "$work/full-plan.json"
bash "$owner/tests/quaternion-recipe-scope.sh" "$output/senemos-uke-linux-kernel-mainline-unstable.spec"
tar -xJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq -e '.source_commit=="909b7eb39cb97fc164964b4cb92bc1dc1da7b48c" and .kernel_release=="7.3.3-14-unstable" and .speaker_gain_ceiling==223' "$profile/source-composition.json" >/dev/null
cp "$profile/source-composition.json" "$work/composition-parent.json"
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs.sha256"
bash "$owner/packaging/native/retarget-audio-tuple733.sh" "$profile" "$boot" "$work/full-plan.json" "$(jq -er .parent_audio_card_sha256 "$manifest")"
for tree in "$profile" "$boot";do
 while IFS= read -r path;do install -Dm644 "$owner/$path" "$tree/$path";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/quaternion-delivery-20261110.json"
 install -Dm644 "$work/full-plan.json" "$tree/manifests/cumulative-release.json"
done
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --argjson tuple "$tuple" --arg source "$(jq -er .proof.source "$manifest")" --argjson build "$id" '.+{
 source_commit:$commit,kernel_release:$tuple.kernel_release,rpm_revision:($tuple.release|tostring),diagnostic_audio_driver:$tuple.audio_driver,
 ssc_quaternion_native_admitted:true,ssc_quaternion_source:$source,ssc_quaternion_native_build:$build,
 ssc_quaternion_datatypes:["rotv","game_rv","geomag_rv"],ssc_quaternion_components:4,
 ssc_quaternion_atomic_direct:true,ssc_quaternion_physical_accepted:false,ssc_quaternion_legacy_projection:true
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
printf 'Cumulative quaternion delivery prepared: complete full14 recipe/config/features, admitted source79, derived tuple, gain223 and six runtime names retained.\n'
