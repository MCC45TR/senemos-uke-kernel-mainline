#!/usr/bin/bash
# Read-only generic ABI addition; no crash worker or recovery change.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$kernel/native-profile
manifest=$profile/manifests/rproc-crash-count-20261109.json
driver=drivers/remoteproc/remoteproc_sysfs.c
delta=$profile/src/health/rproc-crash-count.patch
[[ ! -e $kernel/native-generated/rproc-count-before.c ]]
printf '%s  %s\n' "$(jq -er .driver_before_sha256 "$manifest")" "$kernel/$driver" | sha256sum -c --strict --quiet -
install -m644 "$kernel/$driver" "$kernel/native-generated/rproc-count-before.c"
sha256sum "$kernel/drivers/remoteproc/remoteproc_core.c" > "$kernel/native-generated/rproc-count-worker.sha256"
git -C "$kernel" apply --check --whitespace=error "$delta"
git -C "$kernel" apply --whitespace=error "$delta"
printf '%s  %s\n' "$(jq -er .driver_after_sha256 "$manifest")" "$kernel/$driver" | sha256sum -c --strict --quiet -
install -Dm644 "$profile/src/health/sysfs-class-remoteproc-crash-count" "$kernel/Documentation/ABI/testing/sysfs-class-remoteproc-crash-count"
sha256sum -c --strict --quiet "$kernel/native-generated/rproc-count-worker.sha256"
