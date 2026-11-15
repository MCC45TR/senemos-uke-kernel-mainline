#!/usr/bin/bash
# COPR only. Catch affected callback errors before the retained full source gates.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$kernel/native-profile
contract=$profile/manifests/ssc-quaternion-buffer-20261110.json
path=drivers/iio/common/uke-ssc/uke-ssc-iio.c
work=$(mktemp -d "$kernel/native-generated/quaternion-buffer-fast.XXXXXX")
trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/drivers/iio/common/uke-ssc" "$work/include/uapi/linux/iio"
install -m644 "$kernel/drivers/iio/industrialio-buffer.c" "$work/drivers/iio/industrialio-buffer.c"
ln -s "$profile" "$work/native-profile"
install -m644 "$profile/src/sensors/uke-ssc-iio.c" "$work/$path"
for file in uke-ssc-protocol.c uke-ssc-protocol.h;do
 install -m644 "$kernel/drivers/iio/common/uke-ssc/$file" "$work/drivers/iio/common/uke-ssc/$file"
done
install -m644 "$kernel/include/uapi/linux/iio/types.h" "$work/include/uapi/linux/iio/types.h"
git -C "$work" init -q
for patch in "$profile"/src/sensors/000*.patch "$profile"/src/sensors/001[0-5]-*.patch;do
 git -C "$work" apply --whitespace=error --include="$path" "$patch"
done
before=$(jq -er --arg path "$path" '.source_units[]|select(.path==$path)|.before_sha256' "$contract")
printf '%s  %s\n' "$before" "$work/$path" | sha256sum -c --strict --quiet -
git -C "$work" apply --whitespace=error --include="$path" "$profile/src/sensors/0016-ssc-quaternion-scan-alignment.patch"
after=$(jq -er --arg path "$path" '.source_units[]|select(.path==$path)|.after_sha256' "$contract")
printf '%s  %s\n' "$after" "$work/$path" | sha256sum -c --strict --quiet -
status=0
bash "$profile/tests/ssc-quaternion-buffer.sh" "$work" > "$work/callbacks.log" 2>&1 || status=$?
if [[ $status != 0 ]];then cat "$work/callbacks.log";exit "$status";fi
printf 'Fast quaternion buffer preflight: exact full15/new source and actual IIO scan sizing pass before cumulative gates.\n'
