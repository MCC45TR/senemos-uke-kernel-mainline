#!/usr/bin/bash
# Source-only endpoint lifecycle checks; no full build or runtime admission.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
manifest=$owner/manifests/dual-light-endpoint-20261108.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
[[ $# == 4 && $3 == check ]]
output=$(realpath -m "${1:?Source result directory}")
bash "$owner/packaging/native/copr-ssc-stream-owners733.sh" "$@"
version=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json" | jq -er .version)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
native=senemos-native-profile-$version.tar.xz
tar -xJf "$output/$native" -C "$work"
profile=$work/native-profile
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
sha256sum "$profile/src/sensors/uke-ssc-iio.c" "$profile/src/display/uke-abl-native.h" "$profile/src/boot/uke-hardware.h" "$profile/native.config" > "$work/legacy.sha256"
while IFS= read -r path; do install -Dm644 "$owner/$path" "$profile/$path"; done < <(jq -r '.payload_assets[]' "$manifest")
install -Dm644 "$manifest" "$profile/manifests/${manifest##*/}"
cp "$profile/source-composition.json" "$profile/source-composition-before-dual-light-endpoint.json"
jq '.+{dual_light_endpoint_layer:1,dual_light_endpoint_standard_iio:true,dual_light_endpoint_raw_channels_retained:true,dual_light_endpoint_passive_lid:true,dual_light_endpoint_board_phandle:true,dual_light_endpoint_new_polling:false,dual_light_endpoint_native_admitted:false,dual_light_endpoint_binding_qualified:false,dual_light_endpoint_original_proxy_parity:false,dual_light_endpoint_physical_accepted:false}' \
 "$profile/source-composition-before-dual-light-endpoint.json" > "$work/composition.json"
install -m644 "$work/composition.json" "$profile/source-composition.json"
spec=$output/uke-kernel-migration-check.spec
awk '
 $0=="bash native-profile/packaging/native/check-ssc-stream-owners733.sh \"$PWD\" %{_uke_out} prepared" {print;print "bash native-profile/packaging/native/check-dual-light-endpoint733.sh \"$PWD\" %{_uke_out} prepared";p++;next}
 $0=="bash native-profile/packaging/native/check-ssc-stream-owners733.sh \"$PWD\" %{_uke_out} objects" {print;print "bash native-profile/packaging/native/check-dual-light-endpoint733.sh \"$PWD\" %{_uke_out} objects";o++;next}
 {print}END{if(p!=1||o!=1)exit 1}
' "$spec" > "$work/updated.spec"
install -m644 "$work/updated.spec" "$spec"
sha256sum -c --strict --quiet "$work/legacy.sha256"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work" native-profile
printf 'Source-only dual-light endpoint/input/DT checks prepared; full image, original proxy parity and physical acceptance remain separate.\n'
