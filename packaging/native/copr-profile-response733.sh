#!/usr/bin/bash
# Qualify a small experiment on the exact admitted cumulative source52 recipe.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR source result}")
manifest=$owner/manifests/platform-profile-response-20261109.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
parent=$(jq -er .parent_commit "$manifest")
git init -q "$work/base"
git -C "$work/base" remote add origin https://github.com/MCC45TR/senemos-uke-kernel-mainline.git
git -C "$work/base" fetch --depth=1 origin "$parent"
git -C "$work/base" checkout -q --detach FETCH_HEAD
[[ $(git -C "$work/base" rev-parse HEAD) == "$parent" ]]
# Keep the bound parent release tuple and every earlier qualification gate.
bash "$work/base/packaging/native/copr-proximity-input733.sh" "$output" 10 check 52
spec=$output/uke-kernel-migration-check.spec
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$spec" | sha256sum -c --strict --quiet -
version=$(jq -er .upstream.version "$work/base/manifests/cumulative-release.json")
release=$(jq -er .source_check_release "$manifest")
native=senemos-native-profile-$version.tar.xz
tar -xJf "$output/$native" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
for tree in "$profile" "$boot";do
 while IFS= read -r file;do install -Dm644 "$owner/$file" "$tree/$file";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/platform-profile-response-20261109.json"
done
awk -v release="$release" -v version="$version" '
 /^Release: 52%\{\?dist\}$/ {print "Release: " release "%{?dist}";r++;next}
 $0=="%install" {print "bash native-profile/packaging/native/check-profile-response733.sh \"$PWD\" %{_uke_out}";i++}
 $0=="%changelog" {
  print;print "* Mon Nov 09 2026 Uke contributors - " version "-" release
  print "- Qualify responsive CPU QoS over the exact cumulative source52 recipe."
  print "- Keep full delivery, energy and latency acceptance separate."
  print "";c++;next
 }
 {print}
 END{if(r!=1||i!=1||c!=1)exit 1}
' "$spec" > "$work/spec"
install -m644 "$work/spec" "$spec"
commit=$(git -C "$owner" rev-parse HEAD)
jq --arg parent "$parent" --arg commit "$commit" --arg version "$version" --argjson release "$release" '.+{
 source_commit:$commit,source_check_package:("uke-kernel-migration-check-"+$version+"-"+($release|tostring)),
 power_response_parent_commit:$parent,power_response_candidate_layer:1,
 power_response_cpu_ceiling_released:true,power_response_schedutil_unchanged:true,
 power_response_thermal_qos_unchanged:true,power_response_gpu_preference_unchanged:true,
 power_response_native_admitted:false,power_response_energy_accepted:false,
 power_response_latency_accepted:false,power_response_full_delivery_ready:false
}' "$profile/source-composition.json" > "$work/composition.json"
install -m644 "$work/composition.json" "$profile/source-composition.json"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/boot-assets"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/boot-assets" > "$work/assets.json"
jq --slurpfile assets "$work/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/lock.json"
install -m644 "$work/lock.json" "$boot/lock.json"
install -m644 "$work/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work" boot-recipe
printf 'Responsive saver experiment prepared over exact cumulative source52; all previous gates retained, no full delivery/default change or new runtime family.\n'
