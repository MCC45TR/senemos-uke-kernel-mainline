#!/usr/bin/env bash
# COPR source-only milestone; refuse full builds until the native lifecycle exists.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
manifest=$owner/manifests/dual-light-events-20261108.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
[[ $# == 4 && $3 == check ]]
output=$(realpath -m "${1:?Source result directory}")
bash "$owner/packaging/native/copr-hall-initial733.sh" "$@"
# The tuple helper's JSON contract owns the upstream version.
version=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json" | jq -er .version)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
native=senemos-native-profile-$version.tar.xz
tar -xJf "$output/$native" -C "$work"
profile=$work/native-profile
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
sha256sum "$profile/src/sensors/uke-ssc-iio.c" "$profile/src/boot/uke-hardware.h" "$profile/native.config" > "$work/legacy.sha256"
while IFS= read -r path;do install -Dm644 "$owner/$path" "$profile/$path";done < <(jq -r '.payload_assets[]' "$manifest")
install -Dm644 "$manifest" "$profile/manifests/${manifest##*/}"
cp "$profile/source-composition.json" "$profile/source-composition-before-dual-light-events.json"
jq '.+{dual_light_event_reducer_layer:1,dual_light_event_reducer_only:true,dual_light_rear_only_closed_supported_in_reducer:true,dual_light_reducer_epoch_and_tick_gates:true,dual_light_runtime_integrated:false,dual_light_new_runtime_polling:false,dual_light_physical_accepted:false}' "$profile/source-composition-before-dual-light-events.json" > "$work/composition.json"
install -m644 "$work/composition.json" "$profile/source-composition.json"
spec=$output/uke-kernel-migration-check.spec
awk '
 $0=="bash native-profile/packaging/native/check-hall-initial733.sh \"$PWD\" %{_uke_out} prepared" {print;print "bash native-profile/packaging/native/check-dual-light-events733.sh \"$PWD\" %{_uke_out} prepared";prepared++;next}
 $0=="bash native-profile/packaging/native/check-hall-initial733.sh \"$PWD\" %{_uke_out} objects" {print;print "bash native-profile/packaging/native/check-dual-light-events733.sh \"$PWD\" %{_uke_out} objects";objects++;next}
 {print}END{if(prepared!=1||objects!=1)exit 1}
' "$spec" > "$work/updated.spec"
install -m644 "$work/updated.spec" "$spec"
sha256sum -c --strict --quiet "$work/legacy.sha256"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work" native-profile
printf 'Source-only dual-light event reduction prepared; full kernel submission refused until SSC, Hall input and standard IIO lifecycle integration.\n'
