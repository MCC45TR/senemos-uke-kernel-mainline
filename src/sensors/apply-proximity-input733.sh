#!/usr/bin/bash
# Additive native input endpoint; preserve the exact qualified cumulative IIO path.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$kernel/native-profile
manifest=$profile/manifests/ssc-proximity-input-20261109.json
driver=drivers/iio/common/uke-ssc/uke-ssc-iio.c
delta=$profile/src/sensors/0010-ssc-proximity-input.patch
printf '%s  %s\n' "$(jq -er .driver_before_sha256 "$manifest")" "$kernel/$driver" | sha256sum -c --strict --quiet -
[[ ! -e $kernel/drivers/iio/common/uke-ssc/uke-ssc-proximity-input.h ]]
git -C "$kernel" apply --check --whitespace=error "$delta"
git -C "$kernel" apply --whitespace=error "$delta"
printf '%s  %s\n' "$(jq -er .driver_after_sha256 "$manifest")" "$kernel/$driver" | sha256sum -c --strict --quiet -
install -m644 "$profile/src/sensors/uke-ssc-proximity-input.h" "$kernel/drivers/iio/common/uke-ssc/"
