#!/usr/bin/bash
# COPR-only binding qualification; no runtime device data or writes.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
phase=${2:?prepared or objects}
[[ $phase == prepared || $phase == objects ]]
profile=$kernel/native-profile
path=Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
install -Dm644 "$profile/src/boot/bindings/firmware/xiaomi,uke-ssc-sensors.yaml" "$work/view/$path"
printf '%s  %s\n' 6ac44534fd8510a2d7e58d0b8652110212f5163ee3ca06f18b7f06b1509876bc "$work/view/$path" | sha256sum -c --strict --quiet -
git -C "$work/view" apply --check --whitespace=error "$profile/src/sensors/0007-ssc-dual-light-binding.patch"
git -C "$work/view" apply --whitespace=error "$profile/src/sensors/0007-ssc-dual-light-binding.patch"
install -Dm644 "$work/view/$path" "$work/unique/$path"
git -C "$work/view" apply --check --whitespace=error "$profile/src/sensors/0009-ssc-mount-matrix-nonunique-binding.patch"
git -C "$work/view" apply --whitespace=error "$profile/src/sensors/0009-ssc-mount-matrix-nonunique-binding.patch"
if [[ $phase == prepared ]]; then
  bash "$profile/tests/ssc-dual-light-schema.sh" "$profile" "$work/view/$path" "$work/unique/$path"
else
  cmp "$work/view/$path" "$kernel/$path"
  cmp "$profile/src/boot/uke-hardware.h" "$kernel/arch/arm64/kernel/uke-hardware.h"
  cmp "$profile/src/boot/uke-dual-light.h" "$kernel/arch/arm64/kernel/uke-dual-light.h"
  printf 'Actual compiled early-DT producer headers and final binding match the qualified synthetic schema input; physical board acceptance separate.\n'
fi
