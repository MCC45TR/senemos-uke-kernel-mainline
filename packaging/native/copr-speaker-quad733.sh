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
 jq -e '.full_delivery_source_qualified' "$owner/manifests/speaker-quad-20261108.json" >/dev/null
fi
bash "$owner/packaging/native/copr-release733.sh" "$@"
version=$(jq -er .upstream.version "$owner/manifests/cumulative-release.json")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
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
