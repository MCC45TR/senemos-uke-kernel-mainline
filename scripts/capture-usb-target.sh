#!/usr/bin/env bash
# Host-side cached-state collection. Power-supply getters may issue firmware transactions.
set -Eeuo pipefail
target=${1:?Pass the existing SSH target; no password argument}
output=${2:?Pass a new private output directory}
[[ $target != -* && $target =~ ^[a-zA-Z0-9_.@:-]+$ ]]
[[ ! -e $output ]]
umask 077
mkdir -m700 -p -- "$output"
ssh -oBatchMode=yes -oConnectTimeout=10 -- "$target" /bin/sh -s > "$output/classes.txt" <<'SH'
set -eu
printf 'kernel_release='
uname -r
for group in /sys/class/typec /sys/class/usb_role /sys/class/udc; do
    printf '\nclass=%s\n' "$group"
    for object in "$group"/*; do
        [ -e "$object" ] || continue
        printf 'object=%s\n' "${object##*/}"
        for field in data_role power_role vconn_source orientation power_operation_mode role \
            state current_speed maximum_speed; do
            [ -r "$object/$field" ] || continue
            printf '%s=' "$field"
            cat "$object/$field"
        done
        if [ -L "$object/device/driver" ]; then readlink -f "$object/device/driver"; fi
    done
done
for object in /sys/bus/i2c/devices/*; do
    [ -L "$object/driver" ] || continue
    driver=$(readlink -f "$object/driver")
    case ${driver##*/} in wcd939x-usb-uke|wcd939x-usbss|wcd939x) ;; *) continue;; esac
    printf '\nwcd_driver=%s\n' "${driver##*/}"
    if [ -r "$object/silicon_revision" ]; then cat "$object/silicon_revision"; else printf 'revision=unavailable\n'; fi
    if [ -r "$object/of_node/compatible" ]; then tr '\000' '\n' < "$object/of_node/compatible"; fi
done
for object in /sys/class/remoteproc/*; do
    [ -r "$object/firmware" ] || continue
    printf '\nremoteproc=%s\n' "${object##*/}"
    cat "$object/firmware"
    [ ! -r "$object/state" ] || cat "$object/state"
done
printf '\npower_supply=not_read_pending_qualified_charging_provider\n'
SH
if ssh -oBatchMode=yes -oConnectTimeout=10 -- "$target" /bin/sh -s > "$output/effective.dtb" <<'SH'
test -r /sys/firmware/fdt && cat /sys/firmware/fdt
SH
then
    sha256sum "$output/effective.dtb" > "$output/effective.dtb.sha256"
else
    rm -f -- "$output/effective.dtb"
    printf 'Effective FDT unavailable to this SSH account; no privilege escalation attempted\n' > "$output/effective-dt.unavailable"
fi
printf 'Private class inventory collected. No role, module, power, storage, display or firmware write requested.\n'
