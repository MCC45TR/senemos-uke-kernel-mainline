#!/bin/sh
# Explicit development profiles only; never changes Type-C or power roles.
set -eu
umask 077
state=/run/senemos-uke
g=/sys/kernel/config/usb_gadget/uke_debug
# The watcher never holds the configfs lock while sleeping or running another instance.
if [ "${1-}" = watch-auto ]; then
    trap 'exit 0' INT TERM
    while :; do
        "$0" reconcile-auto || exit "$?"
        sleep 2 & wait "$!" || :
    done
fi
[ "$(id -u)" = 0 ] || { echo 'USB gadget management requires root' >&2; exit 1; }
mkdir -p "$state"
[ ! -L "$state" ] && [ "$(stat -c %u "$state")" = 0 ] || exit 1
chmod 700 "$state"
exec 9>"$state/usb-gadget.lock"
flock -w 5 -x 9

debug_authorized() {
    [ ! -e "$state/usb-gadget-inhibit" ] || return 1
    case " $(cat /proc/cmdline) " in *' senemos.debug=cdc-acm '*) ;; *) return 1;; esac
    uke-boot-status --cdc --wait 15 >/dev/null
}
resolve_udc() {
    set -- /sys/class/udc/*
    [ "$#" = 1 ] && [ -e "$1" ] || return 1
    udc=${1##*/}
    provider=$(readlink -f "$1")
    while [ "$provider" != /sys/devices ] && [ "$provider" != / ]; do
        if [ -r "$provider/of_node/compatible" ] &&
            tr '\000' '\n' < "$provider/of_node/compatible" | grep -Fxq qcom,sm7675-dwc3; then
            dr_mode=$(tr -d '\000' < "$provider/of_node/dr_mode")
            return 0
        fi
        provider=${provider%/*}
    done
    return 1
}
auto_ready() {
    auto_reason=POLICY_DISABLED
    [ -f /etc/senemos/usb-sharing ] &&
        [ "$(cat /etc/senemos/usb-sharing)" = auto-debug ] || return 1
    auto_reason=DEBUG_NOT_AUTHORIZED
    debug_authorized || return 1
    auto_reason=UDC_UNAVAILABLE
    resolve_udc || return 1
    auto_reason=DATA_ROLE_UNVERIFIED
    case $dr_mode in
        peripheral|otg) ;;
        *) return 1;;
    esac
    matches=0
    for role in /sys/class/usb_role/*; do
        [ -e "$role" ] || continue
        role_path=$(readlink -f "$role")
        case $role_path in "$provider"/*|"$provider":*) ;; *) continue;; esac
        [ "$(cat "$role/role")" = device ] || return 1
        matches=$((matches + 1))
    done
    [ "$matches" = 1 ] || return 1
    # A Type-C partner's UFP role is attachment evidence; an unattached UDC is not.
    ports=0
    pc_attached=no
    for port in /sys/class/typec/port*; do
        [ -d "$port" ] || continue
        case ${port##*/} in port[0-9]|port[0-9][0-9]) ;; *) continue;; esac
        ports=$((ports + 1))
        if [ -d "$port-partner" ] && [ -r "$port/data_role" ]; then
            case $(cat "$port/data_role") in device|*'[device]'*) pc_attached=yes;; esac
        fi
    done
    if [ "$ports" = 1 ]; then
        auto_reason=NO_PC_PARTNER
        [ "$pc_attached" = yes ] || return 1
    elif [ "$ports" = 0 ]; then
        # Battery getters issue firmware GETs; no qualified cached attachment API exists yet.
        auto_reason=PC_ATTACHMENT_UNVERIFIED
        return 1
    else
        auto_reason=PORT_ASSOCIATION_AMBIGUOUS
        return 1
    fi
    auto_reason=PC_DEVICE_ROLE_OBSERVED
}
auto_status() {
    previous=
    [ ! -r "$state/usb-auto-state" ] || previous=$(cat "$state/usb-auto-state")
    [ "$previous" = "$1" ] || printf 'Uke USB auto: %s\n' "$1"
    printf '%s\n' "$1" > "$state/usb-auto-state"
}

allow_legacy() {
    # A policy owner inhibits legacy fallback before any planned role/profile handoff.
    debug_authorized || return 1
    if [ -e /etc/senemos/usb-sharing ]; then
        [ "$(cat /etc/senemos/usb-sharing)" = legacy-debug ] || return 1
    fi
    # Until a complete Type-C profile is admitted, only the fixed peripheral FDT is accepted.
    resolve_udc && [ "$dr_mode" = peripheral ]
}
owned() {
    [ -f "$state/usb-gadget-owner" ] && [ ! -L "$state/usb-gadget-owner" ] &&
    [ "$(cat "$state/usb-gadget-owner")" = "$(stat -c '%d:%i' "$g")" ]
}
cleanup() {
    owned || { echo 'Refusing an unowned configfs gadget' >&2; return 1; }
    [ ! -e "$g/UDC" ] || printf '\n' > "$g/UDC"
    for function in acm.gs0 ecm.usb0; do
        link=$g/configs/c.1/$function
        if [ -L "$link" ]; then
            [ "$(readlink -f "$link")" = "$g/functions/$function" ] || return 1
            rm -- "$link"
        fi
    done
    # No recursive deletion: unexpected functions/configurations remain an ownership error.
    for dir in configs/c.1/strings/0x409 configs/c.1 functions/acm.gs0 functions/ecm.usb0 strings/0x409; do
        [ ! -d "$g/$dir" ] || rmdir "$g/$dir"
    done
    rmdir "$g"
    rm -- "$state/usb-gadget-owner"
    rm -f -- "$state/usb-gadget-profile"
}
profile=network
case ${1-} in
    allow-legacy) allow_legacy; exit;;
    start-acm)
        allow_legacy
        [ ! -d "$g" ] || { echo 'Configfs profile owns the port' >&2; exit 1; }
        modprobe g_serial use_acm=1
        exit;;
    stop-acm)
        [ ! -d /sys/module/g_serial ] || modprobe -r g_serial
        exit;;
    stop) [ ! -d "$g" ] || cleanup; exit;;
    stop-auto)
        if [ -d "$g" ] && [ -r "$state/usb-gadget-profile" ] &&
            [ "$(cat "$state/usb-gadget-profile")" = auto-acm ]; then cleanup; fi
        exit;;
    reconcile-auto)
        if ! auto_ready; then
            auto_status "$auto_reason"
            if [ -d "$g" ] && [ -r "$state/usb-gadget-profile" ] &&
                [ "$(cat "$state/usb-gadget-profile")" = auto-acm ]; then cleanup; fi
            exit 0
        fi
        if [ -d /sys/module/g_serial ]; then
            auto_status LEGACY_G_SERIAL_OWNS_PORT
            exit 0
        fi
        profile=auto-acm;;
    start) allow_legacy;;
    *) echo 'Usage: uke-usb-network start|stop|start-acm|stop-acm|allow-legacy|watch-auto|reconcile-auto|stop-auto' >&2; exit 2;;
esac
# Resolve exactly one UDC admitted by the device identity prerequisite, not a fixed name.
set -- /sys/class/udc/*
[ "$#" = 1 ] && [ -e "$1" ] || exit 1
udc=${1##*/}
if [ -d "$g" ]; then
    owned
    [ -r "$state/usb-gadget-profile" ] && [ "$(cat "$state/usb-gadget-profile")" = "$profile" ]
    [ "$(cat "$g/UDC")" = "$udc" ]
    [ "$(readlink -f "$g/configs/c.1/acm.gs0")" = "$g/functions/acm.gs0" ]
    if [ "$profile" = network ]; then
        [ "$(readlink -f "$g/configs/c.1/ecm.usb0")" = "$g/functions/ecm.usb0" ]
    else
        auto_status AUTO_ACM_PREPARED_NOT_HOST_VERIFIED
    fi
    [ "$(cat "$g/configs/c.1/MaxPower")" = 500 ]
    exit 0
fi
# The debug profile explicitly authorizes replacing its inherited initramfs ACM transport.
[ ! -d /sys/module/g_serial ] || modprobe -r g_serial
modprobe libcomposite
[ "$profile" != network ] || modprobe usb_f_ecm
modprobe usb_f_acm
mkdir "$g"
stat -c '%d:%i' "$g" > "$state/usb-gadget-owner"
printf '%s\n' "$profile" > "$state/usb-gadget-profile"
trap 'rc=$?; cleanup || echo "USB gadget cleanup incomplete" >&2; exit "$rc"' EXIT
cd "$g"
printf '0x1d6b\n' > idVendor
printf '0x0104\n' > idProduct
printf '0x0200\n' > bcdUSB
printf '0xEF\n' > bDeviceClass
printf '0x02\n' > bDeviceSubClass
printf '0x01\n' > bDeviceProtocol
mkdir strings/0x409 configs/c.1 configs/c.1/strings/0x409
printf 'Senemos\n' > strings/0x409/manufacturer
printf 'Uke USB debug\n' > strings/0x409/product
printf '%s\n' "$profile" > configs/c.1/strings/0x409/configuration
# Configfs takes mA, not the USB2 descriptor's 2 mA wire units.
printf '500\n' > configs/c.1/MaxPower
mkdir functions/acm.gs0
ln -s "$g/functions/acm.gs0" configs/c.1/acm.gs0
if [ "$profile" = network ]; then
    mkdir functions/ecm.usb0
    printf '02:77:00:00:00:02\n' > functions/ecm.usb0/dev_addr
    printf '02:77:00:00:00:01\n' > functions/ecm.usb0/host_addr
    ln -s "$g/functions/ecm.usb0" configs/c.1/ecm.usb0
fi
# Publish only after descriptors, both functions and links are complete.
if [ "$profile" = network ]; then allow_legacy; else auto_ready; fi
printf '%s\n' "$udc" > UDC
trap - EXIT
[ "$profile" != auto-acm ] || auto_status AUTO_ACM_PREPARED_NOT_HOST_VERIFIED
