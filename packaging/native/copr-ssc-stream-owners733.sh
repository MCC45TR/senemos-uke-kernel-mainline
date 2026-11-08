#!/usr/bin/bash
# Source-only native lifecycle preparation. Full entry remains refused.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
manifest=$owner/manifests/ssc-stream-owners-20261108.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
[[ $# == 4 && $3 == check ]]
output=$(realpath -m "${1:?Source result directory}")
bash "$owner/packaging/native/copr-dual-light-events733.sh" "$@"
version=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json" | jq -er .version)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
native=senemos-native-profile-$version.tar.xz
tar -xJf "$output/$native" -C "$work"
profile=$work/native-profile
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
sha256sum "$profile/src/sensors/uke-ssc-iio.c" "$profile/src/boot/uke-hardware.h" "$profile/native.config" > "$work/legacy.sha256"
while IFS= read -r path; do install -Dm644 "$owner/$path" "$profile/$path"; done < <(jq -r '.payload_assets[]' "$manifest")
install -Dm644 "$manifest" "$profile/manifests/${manifest##*/}"
cp "$profile/source-composition.json" "$profile/source-composition-before-stream-owners.json"
jq '.+{ssc_shared_stream_owners_layer:1,ssc_shared_stream_raw_buffer_wired:true,ssc_shared_stream_last_owner_stop:true,ssc_shared_stream_cached_valid_raw:true,ssc_shared_stream_demand_survives_restart:true,ssc_shared_stream_combined_endpoint:false,ssc_shared_stream_hall_subscription:false,ssc_shared_stream_native_admitted:false,ssc_shared_stream_physical_accepted:false}' \
 "$profile/source-composition-before-stream-owners.json" > "$work/composition.json"
install -m644 "$work/composition.json" "$profile/source-composition.json"
spec=$output/uke-kernel-migration-check.spec
awk '
 $0=="bash native-profile/packaging/native/check-dual-light-events733.sh \"$PWD\" %{_uke_out} prepared" {print;print "bash native-profile/packaging/native/check-ssc-stream-owners733.sh \"$PWD\" %{_uke_out} prepared";prepared++;next}
 $0=="bash native-profile/packaging/native/check-dual-light-events733.sh \"$PWD\" %{_uke_out} objects" {print;print "bash native-profile/packaging/native/check-ssc-stream-owners733.sh \"$PWD\" %{_uke_out} objects";objects++;next}
 {print}END{if(prepared!=1||objects!=1)exit 1}
' "$spec" > "$work/updated.spec"
install -m644 "$work/updated.spec" "$spec"
sha256sum -c --strict --quiet "$work/legacy.sha256"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work" native-profile
printf 'Source-only native SSC shared stream owner checks prepared; full kernel still refused until event endpoint and lifecycle integration.\n'
