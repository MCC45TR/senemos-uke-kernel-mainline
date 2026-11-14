#!/usr/bin/bash
# COPR source preparation only; no attribute read or firmware request.
set -Eeuo pipefail
[[ $# == 2 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1")
packet=$(realpath "$2")
manifest=$packet/manifests/ssc-time-reference-20261113.json
driver=$kernel/drivers/iio/common/uke-ssc/uke-ssc-iio.c
abi=$kernel/Documentation/ABI/testing/sysfs-driver-uke-ssc-time-reference
[[ ! -e $abi ]]
printf '%s  %s\n' "$(jq -er .driver_before_sha256 "$manifest")" "$driver" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/drivers/iio/common/uke-ssc"
cp "$driver" "$work/before.c"
git -C "$kernel" apply --check --whitespace=error "$packet/src/sensors/0020-ssc-time-reference.patch"
git -C "$kernel" apply --whitespace=error "$packet/src/sensors/0020-ssc-time-reference.patch"
printf '%s  %s\n' "$(jq -er .driver_after_sha256 "$manifest")" "$driver" | sha256sum -c --strict --quiet -
cp "$driver" "$work/drivers/iio/common/uke-ssc/uke-ssc-iio.c"
git -C "$work" apply --reverse --check "$packet/src/sensors/0020-ssc-time-reference.patch"
git -C "$work" apply --reverse "$packet/src/sensors/0020-ssc-time-reference.patch"
cmp "$work/before.c" "$work/drivers/iio/common/uke-ssc/uke-ssc-iio.c"
install -m644 "$packet/src/sensors/sysfs-driver-uke-ssc-time-reference" "$abi"
printf 'SSC time reference:exact post25 driver plus root-only diagnostic;whole-file inverse,all original operational callbacks retained;clock/frame mapping unadmitted\n'
