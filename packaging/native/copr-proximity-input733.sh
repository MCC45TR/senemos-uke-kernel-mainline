#!/usr/bin/bash
# Extend the single cumulative source/full queue, retaining every parent gate.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR source result}")
mode=${3:?check or full}
[[ $mode == check || $mode == full ]]
for name in ssc-proximity-input rproc-crash-count; do
 manifest=$owner/manifests/$name-20261109.json
 (cd "$owner"; jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
done
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
if [[ $mode == full ]]; then
 [[ $# == 5 && $4 =~ ^[1-9][0-9]*$ && $5 =~ ^[a-f0-9]{64}$ ]]
 jq -e '.full_recipe_prepared and (.full_release_reserved|not)' "$owner/manifests/ssc-proximity-input-20261109.json" >/dev/null
 url=$(curl -qfsSL --max-time 45 "https://copr.fedorainfracloud.org/api_3/build-chroot/$4/fedora-rawhide-aarch64" | jq -er .result_url)
 evr=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json" | jq -er .source_check_evr)
 curl -qfsSL --max-time 90 "${url}uke-kernel-migration-check-$evr.fc46.aarch64.rpm" -o "$work/proof.rpm"
 printf '%s  %s\n' "$5" "$work/proof.rpm" | sha256sum -c --strict --quiet -
 rpm2cpio "$work/proof.rpm" | cpio -i --to-stdout --quiet '*source-composition.json' > "$work/proof.json"
 jq -e '.ssc_proximity_input_layer==1 and .ssc_proximity_raw_iio_unchanged and .ssc_proximity_shared_per_suid_demand and .ssc_proximity_no_timer and (.ssc_proximity_native_admitted|not) and (.ssc_proximity_physical_accepted|not) and (.original_sensor_proxy_retired|not) and .rproc_crash_count_layer==1 and .rproc_crash_count_read_only and .rproc_crash_count_no_firmware_query and .rproc_crash_worker_unchanged and (.rproc_crash_count_native_admitted|not) and (.rproc_crash_count_physical_accepted|not) and .proximity_delivery_layer==1 and .proximity_delivery_both_archives and .proximity_delivery_authenticated_legacy_inverse and .critical_crash_count_control_required and (.proximity_delivery_linked_accepted|not)' "$work/proof.json" >/dev/null
else
 [[ $# == 4 ]]
fi
# The parent also authenticates terminal success, EVR and exact current commit,
# plus every retained audio/display/sensor/camera qualification entry.
bash "$owner/packaging/native/copr-speaker-quad733.sh" "$@"
version=$(jq -er .upstream.version "$owner/manifests/cumulative-release.json")
native=senemos-native-profile-$version.tar.xz
tar -xJf "$output/$native" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs.sha256"
curl -qfsSL --max-time 45 --max-filesize 1048576 \
 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11289655/senemos-uke-linux-kernel-mainline-unstable.spec -o "$work/full9.spec"
bash "$owner/tests/proximity-delivery-spec.sh" "$owner" "$work/full9.spec"
for tree in "$profile" "$boot"; do
 install -Dm644 "$work/full9.spec" "$tree/tests/fixtures/proximity-full9.spec"
done
spec=$output/uke-kernel-migration-check.spec
[[ $mode != full ]] || spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
bash "$owner/packaging/native/stage-proximity-input733.sh" "$profile" "$boot" "$spec" "$mode"
sha256sum -c --strict --quiet "$work/configs.sha256"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/boot-assets"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/boot-assets" > "$work/assets.json"
jq --slurpfile assets "$work/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/lock.json"
install -m644 "$work/lock.json" "$boot/lock.json"
install -m644 "$work/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work" boot-recipe
printf 'Cumulative proximity/crash-history delivery prepared:%s; both archives and linked gates retained; no physical parity or provider retirement.\n' "$mode"
