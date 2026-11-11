#!/usr/bin/bash
# Native COPR source operation only; never runs remote processors.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$kernel/native-profile
[[ ! -e $kernel/native-generated/rproc-event-before.c ]]
install -Dm644 "$kernel/drivers/remoteproc/remoteproc_core.c" "$kernel/native-generated/rproc-event-before.c"
git -C "$kernel" apply --check "$profile/src/health/rproc-crash-event.patch"
git -C "$kernel" apply "$profile/src/health/rproc-crash-event.patch"
printf 'Remoteproc crash notification added in existing process-context worker; recovery policy and IRQ path retained.\n'
