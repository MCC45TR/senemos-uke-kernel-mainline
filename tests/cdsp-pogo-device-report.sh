#!/usr/bin/env bash
# Read-only tablet report. No firmware bytes, authentication data or unit IDs.
set -Eeuo pipefail
printf 'kernel=%s\n' "$(uname -r)"
for path in /sys/class/remoteproc/remoteproc*; do
    [[ -f $path/name && -f $path/state ]] || continue
    name=$(cat "$path/name")
    case $name in cdsp|adsp|wpss) printf 'remoteproc.%s=%s\n' "$name" "$(cat "$path/state")";; esac
done
for node in /dev/fastrpc-cdsp /dev/fastrpc-cdsp-secure; do
    if [[ -c $node ]]; then
        printf 'node.%s=%s\n' "${node##*/}" "$(stat -c '%a:%U:%G' "$node")"
    else
        printf 'node.%s=absent\n' "${node##*/}"
    fi
done
for relative in qcom/uke/cdsp/cdsp.mdt qcom/uke/cdsp/cdsp_dtb.mdt qcom/uke/nanosic/MCU_Upgrade.bin; do
    found=false
    permissions_unknown=false
    for prefix in "/usr/lib/firmware/$(uname -r)" /usr/lib/firmware/updates /usr/lib/firmware; do
        if [[ -f $prefix/$relative ]]; then
            printf 'firmware.%s=present:%s-bytes\n' "$relative" "$(stat -Lc %s "$prefix/$relative")"
            found=true
            break
        fi
        ancestor=$prefix/${relative%/*}
        while [[ $ancestor != / ]]; do
            if [[ -d $ancestor && ! -x $ancestor ]]; then permissions_unknown=true;break;fi
            ancestor=${ancestor%/*}
            [[ -n $ancestor ]] || ancestor=/
        done
    done
    if [[ $found != true ]]; then
        if [[ $permissions_unknown == true ]]; then printf 'firmware.%s=unverified-permissions\n' "$relative";
        else printf 'firmware.%s=absent\n' "$relative";fi
    fi
done
for path in /sys/bus/i2c/devices/*; do
    [[ -f $path/of_node/compatible ]] || continue
    compatible=$(tr '\0' ' ' < "$path/of_node/compatible")
    case $compatible in
        *nanosic*|*wn8030*)
            if [[ -L $path/driver ]]; then
                printf 'pogo.driver=%s\n' "$(basename "$(readlink "$path/driver")")"
            else
                printf 'pogo.driver=unbound\n'
            fi
            if [[ -r $path/bridge_health ]]; then cat "$path/bridge_health"; fi
            ;;
    esac
done
for path in /sys/class/input/input*/name; do
    [[ -f $path ]] || continue
    name=$(cat "$path")
    case $name in "Uke Pogo "*|"Uke Hall "*) printf 'input=%s\n' "$name";; esac
done
for path in /sys/class/leds/uke-pogo::*; do
    [[ -r $path/brightness ]] || continue
    printf 'led.%s=%s\n' "${path##*/}" "$(cat "$path/brightness")"
done
