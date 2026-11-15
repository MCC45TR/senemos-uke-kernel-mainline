#!/usr/bin/bash
# Source worker: retain the admitted full11 archives and all native57 tests.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR source result}")
manifest=$owner/manifests/speaker-surround-coeff-20261109.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 240 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$work/parent.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-11 ]]
rpm2cpio "$work/parent.rpm" | cpio -t --quiet > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
rpm2cpio "$work/parent.rpm" | (cd "$output";cpio -idm --quiet --no-absolute-filenames)
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$output/senemos-uke-linux-kernel-mainline-unstable.spec" | sha256sum -c --strict --quiet -
mv "$output/senemos-uke-linux-kernel-mainline-unstable.spec" "$work/full11.spec"
curl -qfsSL --max-time 45 "$(jq -er .native_spec_url "$manifest")" -o "$work/native57.spec"
printf '%s  %s\n' "$(jq -er .native_spec_sha256 "$manifest")" "$work/native57.spec" | sha256sum -c --strict --quiet -
tar -xJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq -e '.source_commit=="4b4cf375b2a749a1961cda7e8927b8a7d27cb4d1" and .kernel_release=="7.3.3-11-unstable" and .mst_power_delivery_layer==1 and .speaker_gain_ceiling==223 and (.physical_acceptance|not)' "$profile/source-composition.json" >/dev/null
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs.sha256"
for tree in "$profile" "$boot";do
 while IFS= read -r file;do install -Dm644 "$owner/$file" "$tree/$file";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/speaker-surround-coeff-20261109.json"
done
release=$(jq -er .source_check_release "$manifest")
awk -v release="$release" '
 $0=="%global senemos_build_release 10" {print "%global senemos_build_release 11";k++;next}
 /^Release: 57%\{\?dist\}$/ {print "Release: " release "%{?dist}";r++;next}
 $0=="%install" {print "bash native-profile/packaging/native/check-surround-map733.sh \"$PWD\" %{_uke_out}";print "bash native-profile/packaging/native/check-surround-coeff733.sh \"$PWD\" %{_uke_out}";i++}
 $0=="%changelog" {
  print;print "* Mon Nov 09 2026 Uke contributors - 7.3.3-" release
  print "- Bind quad coefficients to real channel IDs and qualify six/eight input maps."
  print "- Keep four physical outputs, gains, topology and profile admission unchanged."
  print "";c++;next
 }
 {print}
 END{if(k!=1||r!=1||i!=1||c!=1)exit 1}
' "$work/native57.spec" > "$output/uke-kernel-migration-check.spec"
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --argjson release "$release" '.+{
 source_commit:$commit,source_check_package:("uke-kernel-migration-check-7.3.3-"+($release|tostring)),
 speaker_surround_map_layer:1,speaker_quad_ids_from_actual_header:true,
 speaker_surround_map_alsa_standard_order:true,speaker_surround_counts:[6,8],
 speaker_surround_topology_expanded:false,speaker_surround_dsp_downmix_active:false,
 speaker_surround_desktop_profiles_advertised:false,speaker_surround_physical_accepted:false,
 speaker_surround_native_admitted:false,speaker_surround_parent_full_build:11293047,
 speaker_surround_coeff_layer:1,speaker_surround_coeff_tables:[4,6,8],
 speaker_surround_lfe_retained:true,speaker_surround_peak_bound_q14:16384,
 speaker_surround_coeff_native_admitted:false
}' "$profile/source-composition.json" > "$work/composition.json"
install -m644 "$work/composition.json" "$profile/source-composition.json"
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
printf 'Speaker channel identity/surround source prepared over full11 with all native57 tests; no topology, gain, new runtime package or speaker profile activation.\n'
