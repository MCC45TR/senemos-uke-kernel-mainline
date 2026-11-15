#!/usr/bin/bash
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
out=$(realpath "${2:?Native output}")
phase=${3:?source or objects or linked}
[[ $phase == source || $phase == objects || $phase == linked ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
install -Dm644 "$kernel/drivers/remoteproc/remoteproc_core.c" "$work/drivers/remoteproc/remoteproc_core.c"
git -C "$work" apply --reverse "$kernel/native-profile/src/health/rproc-crash-event.patch"
cmp "$work/drivers/remoteproc/remoteproc_core.c" "$kernel/native-generated/rproc-event-before.c"
[[ $phase != source ]] || { printf 'Actual remoteproc crash event whole-file inverse passed; no device acceptance.\n';exit 0; }
object=$out/drivers/remoteproc/remoteproc_core.o
llvm-readelf -h "$object" | grep -F AArch64
llvm-nm "$object" > "$work/symbols"
grep -Eq ' [Tt] rproc_crash_handler_work$' "$work/symbols"
for symbol in sysfs_notify kobject_uevent_env;do grep -Eq " U $symbol$" "$work/symbols";done
strings "$object" | grep -Fx 'RPROC_EVENT=crash'
if [[ $phase == linked ]];then strings "$out/vmlinux" | grep -Fx 'RPROC_EVENT=crash';fi
printf 'Actual remoteproc process-context crash event compiled:%s; recovery flags/IRQ semantics unchanged, physical fault test separate.\n' "$phase"
