#!/bin/sh
# Passive snapshot collection. Never calls firmware or writes boot partitions.
set -eu
printf 'UKE EL2 query snapshot\n'
uname -r
found=0
for path in /sys/bus/platform/devices/*/uke_el2_query; do
    [ -r "$path" ] || continue
    printf '\n%s\n' "$path"
    cat "$path"
    found=1
done
if [ "$found" -eq 0 ]; then
    printf 'Snapshot is absent; inspect the query kernel/SCM probe logs.\n' >&2
fi
printf '\nKernel query and KVM messages\n'
if [ "$(id -u)" -eq 0 ]; then
    dmesg | grep -E 'UKE_EL2_QUERY:|[Kk][Vv][Mm]|HYP mode|All CPU.*EL[12]' || :
else
    printf 'Run as root to include restricted kernel messages.\n'
fi
[ "$found" -eq 1 ]
