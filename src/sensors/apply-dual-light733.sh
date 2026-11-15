#!/usr/bin/bash
# COPR-only production source preparation before Image/modules.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$kernel/native-profile
manifest=$profile/manifests/dual-light-endpoint-20261108.json
driver=drivers/iio/common/uke-ssc/uke-ssc-iio.c
native=arch/arm64/kernel/uke-abl-native.h
binding=Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml
kconfig=drivers/iio/common/uke-ssc/Kconfig
history=$kernel/native-generated/before-dual-light
[[ ! -e $history ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
printf '%s  %s\n' \
 c7a271fb57d329cdbc31f0d8876af4c4ef95ee16e880137e7fd003a8f45630fd "$kernel/$driver" \
 98ef66222134bd061b185ccc4b38a5c271621057f13049ba49a2e017cdbf08f5 "$kernel/$native" \
 6ac44534fd8510a2d7e58d0b8652110212f5163ee3ca06f18b7f06b1509876bc "$kernel/$binding" \
 | sha256sum -c --strict --quiet -
cmp "$profile/src/sensors/Kconfig" "$kernel/$kconfig"
paths=("$driver" "$native" "$binding" "$kconfig")
patches=(0004-ssc-shared-stream-owners.patch 0005-ssc-dual-light-endpoint.patch
 0006-ssc-dual-light-native-dt.patch 0007-ssc-dual-light-binding.patch
 0008-ssc-dual-light-input-dependency.patch 0009-ssc-mount-matrix-nonunique-binding.patch)
for path in "${paths[@]}"; do
  install -Dm644 "$kernel/$path" "$work/view/$path"
done
for patch in "${patches[@]}"; do
  git -C "$work/view" apply --check --whitespace=error "$profile/src/sensors/$patch"
  git -C "$work/view" apply --whitespace=error "$profile/src/sensors/$patch"
done
printf '%s  %s\n' "$(jq -er .driver_after_sha256 "$manifest")" "$work/view/$driver" \
 "$(jq -er .native_header_after_sha256 "$manifest")" "$work/view/$native" \
 | sha256sum -c --strict --quiet -
for path in "${paths[@]}"; do
  install -Dm644 "$work/view/$path" "$work/post/$path"
done
for ((i=${#patches[@]}-1;i>=0;i--)); do
  git -C "$work/view" apply --reverse --check --whitespace=error "$profile/src/sensors/${patches[i]}"
  git -C "$work/view" apply --reverse --whitespace=error "$profile/src/sensors/${patches[i]}"
done
for path in "${paths[@]}"; do
  cmp "$work/view/$path" "$kernel/$path"
done
mkdir -p "$history"
for path in "${paths[@]}"; do
  install -Dm644 "$kernel/$path" "$history/$path"
  install -m644 "$work/post/$path" "$kernel/$path"
done
install -m644 "$profile/src/sensors/uke-ssc-dual-light.h" "$kernel/${driver%/*}/"
install -m644 "$profile/src/boot/uke-dual-light.h" "$kernel/arch/arm64/kernel/"
(cd "$history";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
printf 'Cumulative dual-light source preparation and four-file inverse passed; linked Image/modules and physical acceptance remain separate.\n'
