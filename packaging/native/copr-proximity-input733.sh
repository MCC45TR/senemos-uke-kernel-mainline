#!/usr/bin/bash
# Source-only continuation of the one cumulative qualified kernel workstream.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR source result}")
[[ ${3:-} == check && $# == 4 ]]
manifest=$owner/manifests/ssc-proximity-input-20261109.json
(cd "$owner"; jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
bash "$owner/packaging/native/copr-speaker-quad733.sh" "$@"
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
version=$(jq -er .upstream.version "$owner/manifests/cumulative-release.json")
native=senemos-native-profile-$version.tar.xz
tar -xJf "$output/$native" -C "$work"
profile=$work/native-profile
while IFS= read -r file; do
 install -Dm644 "$owner/$file" "$profile/$file"
done < <(jq -r '.payload_assets[]' "$manifest")
install -Dm644 "$manifest" "$profile/manifests/${manifest##*/}"
# Run after the retained cumulative source/object gates. Their unchanged
# preimage checks still execute, followed by the actual new driver composite.
awk '
 $0=="%install" {
  print "bash native-profile/src/sensors/apply-proximity-input733.sh \"$PWD\""
  print "bash native-profile/packaging/native/check-proximity-input733.sh \"$PWD\" %{_uke_out} source"
  print "make O=%{_uke_out} ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-%{senemos_build_release}-unstable KCFLAGS=-Werror W=1 -j4 drivers/iio/common/uke-ssc/uke-ssc.o"
  print "bash native-profile/packaging/native/check-proximity-input733.sh \"$PWD\" %{_uke_out} objects"
  n++
 }
 {print}
 END {if(n!=1)exit 1}
' "$output/uke-kernel-migration-check.spec" > "$work/spec"
install -m644 "$work/spec" "$output/uke-kernel-migration-check.spec"
jq '.+{ssc_proximity_input_layer:1,ssc_proximity_raw_iio_unchanged:true,
 ssc_proximity_shared_per_suid_demand:true,ssc_proximity_no_timer:true,
 ssc_proximity_native_admitted:false,ssc_proximity_physical_accepted:false,
 original_sensor_proxy_retired:false}' "$profile/source-composition.json" > "$work/composition.json"
install -m644 "$work/composition.json" "$profile/source-composition.json"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work" native-profile
printf 'Cumulative proximity source candidate prepared; no full kernel recipe or runtime retirement.\n'
