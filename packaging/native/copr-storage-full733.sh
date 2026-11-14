#!/usr/bin/bash
# Cumulative full kernel from actual23 and admitted native97;no volume changes.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/storage-config-delivery-20261111.json
[[ ! -e $output && ! -L $output ]]
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --max-time 40 'https://copr.fedorainfracloud.org/api_3/build/list?ownername=mcc45tr&projectname=uke-linux-unstable&limit=1000&order=id&order_type=DESC' > "$work/history.json"
jq -e '(.items|length)<1000' "$work/history.json" >/dev/null
jq '{items:[.items[]|select(.source_package.name=="senemos-uke-linux-kernel-mainline-unstable")]}' "$work/history.json" > "$work/family-history.json"
version=$(jq -er .upstream.version "$owner/manifests/cumulative-release.json")
full=$(bash "$owner/scripts/kernel-release.sh" next "$work/family-history.json" "$version" senemos-uke-linux-kernel-mainline-unstable)
proof_release=$(jq -er .proof.source_check_release "$manifest")
jq --argjson full "$full" --argjson check "$proof_release" '.full_release=$full|.source_check_release=$check' "$owner/manifests/cumulative-release.json" > "$work/full-plan.json"
tuple=$(bash "$owner/scripts/kernel-release.sh" json "$work/full-plan.json")
jq --argjson tuple "$tuple" -e '.parent_full_release+1==$tuple.release and .proof.source_check_release==$tuple.source_check_release and $tuple.version=="7.3.3"' "$manifest" >/dev/null
curl -qfsSL --retry 2 --max-time 240 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$work/parent.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-23 ]]
rpm2cpio "$work/parent.rpm" | cpio -t --quiet > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
rpm2cpio "$work/parent.rpm" | (cd "$output";cpio -idm --quiet --no-absolute-filenames)
mv "$output/senemos-uke-linux-kernel-mainline-unstable.spec" "$work/parent.spec"
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$work/parent.spec" | sha256sum -c --strict --quiet -
printf '%s  %s\n' "$(jq -er .parent_profile_sha256 "$manifest")" "$output/senemos-native-profile-7.3.3.tar.xz" | sha256sum -c --strict --quiet -
id=$(jq -er .proof.build "$manifest")
url=$(curl -qfsSL --max-time 40 "https://copr.fedorainfracloud.org/api_3/build-chroot/$id/fedora-rawhide-aarch64" | jq -er 'if .state=="succeeded" then .result_url else error("Native storage source unqualified") end')
curl -qfsSL --max-time 60 "${url}uke-kernel-migration-check-$(jq -er .proof.version "$manifest").fc46.aarch64.rpm" -o "$work/proof.rpm"
printf '%s  %s\n' "$(jq -er .proof.receipt_sha256 "$manifest")" "$work/proof.rpm" | sha256sum -c --strict --quiet -
rpm2cpio "$work/proof.rpm" | cpio -i --to-stdout --quiet '*storage-cohort-source-qualification.json' > "$work/proof.json"
jq --arg source "$(jq -er .proof.source "$manifest")" -e '.source_commit==$source and .source_check_release==97 and .parent_full_build==11306825 and .retained_parent_fields==774 and (.changes|length)==8' "$work/proof.json" >/dev/null
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$work/proof.json" | sha256sum -c --strict --quiet -)
jq -S 'del(.source_commit,.source_tree)' "$work/proof.json" > "$work/proof-contract.json"
jq -S . "$owner/$(jq -er .proof.manifest "$manifest")" > "$work/local-contract.json"
cmp "$work/proof-contract.json" "$work/local-contract.json"
bash "$owner/packaging/native/rewrite-storage-full733.sh" "$work/parent.spec" "$output/senemos-uke-linux-kernel-mainline-unstable.spec" "$manifest" "$work/full-plan.json"
bash "$owner/tests/proximity-abi-recipe-scope.sh" "$output/senemos-uke-linux-kernel-mainline-unstable.spec"
tar -xJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile;boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq -e '.source_commit=="dde9b3034a095f14581c0fd5e23c42f1caf43986" and .kernel_release=="7.3.3-23-unstable" and .speaker_gain_ceiling==223 and (.storage_encryption_native_admitted|not) and (.storage_encryption_enabled_in_full_candidate|not)' "$profile/source-composition.json" >/dev/null
cp "$profile/source-composition.json" "$work/composition-parent.json"
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs.sha256"
bash "$owner/packaging/native/retarget-audio-tuple733.sh" "$profile" "$boot" "$work/full-plan.json" "$(jq -er .parent_audio_card_sha256 "$manifest")"
for tree in "$profile" "$boot";do
 bash "$owner/packaging/native/apply-storage-config-full733.sh" "$tree" "$manifest"
 while IFS= read -r path;do install -Dm644 "$owner/$path" "$tree/$path";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/storage-config-delivery-20261111.json"
 install -Dm644 "$work/full-plan.json" "$tree/manifests/cumulative-release.json"
done
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --argjson tuple "$tuple" --arg source "$(jq -er .proof.source "$manifest")" --argjson build "$id" '.+{
 source_commit:$commit,kernel_release:$tuple.kernel_release,rpm_revision:($tuple.release|tostring),diagnostic_audio_driver:$tuple.audio_driver,
 storage_encryption_native_admitted:true,storage_encryption_enabled_in_full_candidate:true,
 storage_encryption_config_layer:1,storage_encryption_config_native_build:$build,storage_encryption_config_native_source:$source,
 storage_encryption_exact_effective_changes:8,storage_encryption_manager_references:6,storage_encryption_raw_configs_retained:true,
 storage_encryption_xts_builtin_required:true,storage_encryption_signed_crypto_modules_required:3
}' "$work/composition-parent.json" > "$profile/source-composition.json"
jq --slurpfile old "$work/composition-parent.json" --slurpfile policy "$manifest" -e '. as $new|all($old[0]|to_entries[];.key as $key|($policy[0].declared_changed_parent_fields|index($key))!=null or $new[$key]==.value)' "$profile/source-composition.json" >/dev/null
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
printf 'Storage full candidate:%s;actual23+native97,eight explicit config changes,six existing runtime names and all retained hardware gates;no encrypted-I/O/key/boot claim.\n' "$(jq -er .kernel_release <<< "$tuple")"
