#!/usr/bin/bash
# Reconstruct exact affected source, without touching the later production tree.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Unmodified upstream source}")
profile=$kernel/native-profile
contract=$profile/manifests/ssc-heading-20261110.json
work=$(mktemp -d "$kernel/.heading-fast.XXXXXX")
trap 'find "$work" -depth -delete' EXIT
path=drivers/iio/common/uke-ssc/uke-ssc-iio.c
mkdir -p "$work/drivers/iio/common/uke-ssc" "$work/include/uapi/linux/iio"
ln -s "$profile" "$work/native-profile"
install -m644 "$kernel/include/uapi/linux/iio/types.h" "$work/include/uapi/linux/iio/types.h"
install -m644 "$profile/src/sensors/uke-ssc-iio.c" "$work/$path"
git -C "$work" init -q
for patch in "$profile"/src/sensors/000*.patch "$profile"/src/sensors/001[0-6]-*.patch;do git -C "$work" apply --whitespace=error --include="$path" "$patch";done
printf '%s  %s\n' "$(jq -er '.source_units[0].before_sha256' "$contract")" "$work/$path" | sha256sum -c --strict --quiet -
git -C "$work" apply --whitespace=error --include="$path" "$profile/src/sensors/0017-ssc-magnetic-heading.patch"
printf '%s  %s\n' "$(jq -er '.source_units[0].after_sha256' "$contract")" "$work/$path" | sha256sum -c --strict --quiet -
for name in uke-ssc-heading.h uke-ssc-heading-input.h;do install -m644 "$profile/src/sensors/$name" "$work/drivers/iio/common/uke-ssc/$name";done
status=0
bash "$profile/tests/ssc-heading-callbacks.sh" "$work" > "$work/callbacks.log" 2>&1 || status=$?
if [[ $status != 0 ]];then cat "$work/callbacks.log";exit "$status";fi
printf 'Fast heading preflight: exact full16/new driver and actual lifecycle callbacks pass before cumulative gates.\n'
