#!/usr/bin/bash
# Single-coordinator continuation of the complete qualified release recipe.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR source result}")
mode=${3:?check or full}
[[ $mode == check || $mode == full ]]
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' manifests/speaker-quad-20261108.json | sha256sum -c --strict --quiet -)
if [[ $mode == full ]];then
 jq -e '.full_recipe_prepared' "$owner/manifests/speaker-quad-20261108.json" >/dev/null
fi
bash "$owner/packaging/native/copr-release733.sh" "$@"
version=$(jq -er .upstream.version "$owner/manifests/cumulative-release.json")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
# The parent admits terminal success, release, exact source commit and the
# independently supplied receipt digest. Also require the quad-specific source
# entry: a successful older entry at the same commit is insufficient.
if [[ $mode == full ]];then
 [[ $# == 5 && $4 =~ ^[1-9][0-9]*$ && $5 =~ ^[a-f0-9]{64}$ ]]
 proof_evr=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json" | jq -er .source_check_evr)
 proof_url="https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable:custom:kernel-migration-20261105/fedora-rawhide-aarch64/$4-uke-kernel-migration-check/uke-kernel-migration-check-$proof_evr.fc46.aarch64.rpm"
 curl -qfsSL --max-time 90 "$proof_url" -o "$work/proof.rpm"
 printf '%s  %s\n' "$5" "$work/proof.rpm" | sha256sum -c --strict --quiet -
 rpm2cpio "$work/proof.rpm" | cpio -i --to-stdout --quiet '*source-composition.json' > "$work/proof.json"
 jq -e '.speaker_quad_coefficient_api==1 and .speaker_quad_no_output_format_change and .speaker_quad_default_prepare_extra_dsp_commands==0 and .speaker_quad_layer==1 and .speaker_quad_mfc_only and .speaker_quad_physical_protection_map_unchanged and .speaker_quad_graph_lifetime_mutex and .speaker_quad_rollback_fault and (.speaker_quad_native_admitted|not) and (.speaker_quad_new_daemon|not) and (.speaker_quad_live_firmware_accepted|not) and (.speaker_quad_physical_accepted|not)' "$work/proof.json" >/dev/null
fi
native=senemos-native-profile-$version.tar.xz
tar -xJf "$output/$native" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
spec=$output/uke-kernel-migration-check.spec
[[ $mode != full ]] || spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
bash "$owner/packaging/native/stage-speaker-quad733.sh" "$work/native-profile" "$work/boot-recipe" "$spec" "$mode"
(cd "$work/native-profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$work/boot-recipe";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/boot-assets"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/boot-assets" > "$work/assets.json"
jq --slurpfile assets "$work/assets.json" '.source_assets=$assets[0]' "$work/boot-recipe/lock.json" > "$work/lock.json"
install -m644 "$work/lock.json" "$work/boot-recipe/lock.json"
install -m644 "$work/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work" boot-recipe
printf 'Complete cumulative quad candidate prepared:%s; original release/AVR source and payload retained, full gate independent.\n' "$mode"
