#!/usr/bin/bash
# COPR-only authenticated source comparison; never substitutes old objects.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$kernel/native-profile
driver=drivers/iio/common/uke-ssc/uke-ssc-iio.c
manifest=$profile/manifests/ssc-proximity-input-20261109.json
before=$(jq -er .driver_before_sha256 "$manifest")
after=$(jq -er .driver_after_sha256 "$manifest")
actual=$(sha256sum "$kernel/$driver");actual=${actual%% *}
if [[ $actual == "$before" ]]; then
 printf '%s\n' "$kernel"
 exit 0
fi
[[ $actual == "$after" ]]
work=$(mktemp -d "$kernel/native-generated/proximity-inverse.XXXXXX")
trap 'find "$work" -depth -delete' EXIT
install -Dm644 "$kernel/$driver" "$work/$driver"
git -C "$work" apply --reverse --check --whitespace=error "$profile/src/sensors/0010-ssc-proximity-input.patch"
git -C "$work" apply --reverse --whitespace=error "$profile/src/sensors/0010-ssc-proximity-input.patch"
printf '%s  %s\n' "$before" "$work/$driver" | sha256sum -c --strict --quiet -
view=$kernel/native-generated/proximity-legacy-view
install -Dm644 "$work/$driver" "$view/$driver"
# Only the known additive input layer is inverted. The actual source, objects
# and signed modules remain the new postimage for independent linked checks.
printf '%s\n' "$view"
