#!/usr/bin/bash
# COPR only: add the bounded replay rule to the exact cumulative SSC postimage.
set -Eeuo pipefail
[[ ! -e /etc/senemos/kernel-update.conf && $# == 2 ]]
kernel=$(realpath "$1")
profile=$(realpath "$2")
driver=drivers/iio/common/uke-ssc/uke-ssc-iio.c
manifest=$profile/manifests/ssc-stream-freshness-20261113.json
before=$(jq -er .driver_before_sha256 "$manifest")
after=$(jq -er .driver_after_sha256 "$manifest")
printf '%s  %s\n' "$before" "$kernel/$driver" | sha256sum -c --strict --quiet -
git -C "$kernel" apply --check --whitespace=error "$profile/src/sensors/0019-ssc-streaming-buffer-fresh-sample.patch"
git -C "$kernel" apply --whitespace=error "$profile/src/sensors/0019-ssc-streaming-buffer-fresh-sample.patch"
printf '%s  %s\n' "$after" "$kernel/$driver" | sha256sum -c --strict --quiet -
printf 'SSC streaming buffer freshness applied; no protocol, frame, rates or demand change\n'
