#!/usr/bin/bash
# COPR-only authenticated inverse source view; never substitutes old objects.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$kernel/native-profile
driver=drivers/iio/common/uke-ssc/uke-ssc-iio.c
native=arch/arm64/kernel/uke-abl-native.h
binding=Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml
kconfig=drivers/iio/common/uke-ssc/Kconfig
before=c7a271fb57d329cdbc31f0d8876af4c4ef95ee16e880137e7fd003a8f45630fd
history=$kernel/native-generated/before-dual-light
manifest=$profile/manifests/dual-light-endpoint-20261108.json
paths=("$driver" "$native" "$binding" "$kconfig")
originals=(src/sensors/uke-ssc-iio.c src/display/uke-abl-native.h
 src/boot/bindings/firmware/xiaomi,uke-ssc-sensors.yaml src/sensors/Kconfig)
actual=$(sha256sum "$kernel/$driver");actual=${actual%% *}
if [[ $actual == "$before" ]]; then
  [[ ! -e $history ]]
  for i in "${!paths[@]}"; do
    cmp "$profile/${originals[i]}" "$kernel/${paths[i]}"
  done
  printf '%s\n' "$kernel"
  exit 0
fi
printf '%s  %s\n' "$(jq -er .driver_after_sha256 "$manifest")" "$kernel/$driver" \
 "$(jq -er .native_header_after_sha256 "$manifest")" "$kernel/$native" \
 | sha256sum -c --strict --quiet -
[[ -d $history && -f $history/SHA256SUMS ]]
(cd "$history";sha256sum -c --strict --quiet SHA256SUMS)
for i in "${!paths[@]}"; do
  cmp "$profile/${originals[i]}" "$history/${paths[i]}"
done
for pair in "src/sensors/uke-ssc-dual-light.h:${driver%/*}/uke-ssc-dual-light.h" \
 "src/boot/uke-dual-light.h:arch/arm64/kernel/uke-dual-light.h"; do
  cmp "$profile/${pair%%:*}" "$kernel/${pair#*:}"
done
work=$(mktemp -d "$kernel/native-generated/dual-light-inverse.XXXXXX")
trap 'find "$work" -depth -delete' EXIT
for path in "${paths[@]}"; do install -Dm644 "$kernel/$path" "$work/$path"; done
patches=(0004-ssc-shared-stream-owners.patch 0005-ssc-dual-light-endpoint.patch
 0006-ssc-dual-light-native-dt.patch 0007-ssc-dual-light-binding.patch
 0008-ssc-dual-light-input-dependency.patch 0009-ssc-mount-matrix-nonunique-binding.patch)
for ((i=${#patches[@]}-1;i>=0;i--)); do
  git -C "$work" apply --reverse --check --whitespace=error "$profile/src/sensors/${patches[i]}"
  git -C "$work" apply --reverse --whitespace=error "$profile/src/sensors/${patches[i]}"
done
view=$kernel/native-generated/dual-light-legacy-view
for path in "${paths[@]}"; do
  cmp "$work/$path" "$history/$path"
done
for path in "${paths[@]}"; do install -Dm644 "$work/$path" "$view/$path"; done
# Only exact source comparisons use this view. Linked checks retain original
# $kernel/$out and inspect the actual new driver, module and early-DT objects.
printf '%s\n' "$view"
