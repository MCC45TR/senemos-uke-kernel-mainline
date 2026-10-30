#!/usr/bin/env bash
# Read existing Linux input sysfs metadata only. Never open event/hidraw nodes.
set -Eeuo pipefail
[[ $# == 2 && $1 == --sysfs-input && -d $2 ]] || {
    echo 'Usage: input-capability-inventory.sh --sysfs-input /sys/class/input' >&2
    exit 2
}
input_root=$2
command -v jq >/dev/null
# Deliberately omit name, phys, uniq, full paths and driver uevents: those can
# contain personal names, addresses or device identifiers. Bus/vendor/product/
# version are shared type IDs, not a unit identity. Bitmap words stay opaque;
# decoding them requires the producing kernel word size and input ABI.
read_hex() {
    local path=$1 format=$2 value
    [[ -f $path && -r $path ]] || { echo 'Input metadata unavailable; no inventory emitted' >&2; return 1; }
    # Preserve trailing newlines until the size check; command substitution
    # would otherwise hide oversized/truncated newline-only input.
    value=$(head -c 4097 -- "$path" && printf '.') || return 1
    value=${value%.}
    [[ ${#value} -le 4096 ]] || return 1
    value=${value%$'\n'}
    if [[ $format == id ]]; then
        [[ $value =~ ^[[:xdigit:]]{4}$ ]] || return 1
    else
        [[ $value =~ ^[[:xdigit:]]+(\ [[:xdigit:]]+)*$ ]] || return 1
    fi
    printf '%s' "$value"
}
shopt -s nullglob
records='[]'
for entry in "$input_root"/event*; do
    node=${entry##*/}
    [[ $node =~ ^event[0-9]+$ ]] || continue
    [[ -d $entry/device ]] || { echo 'Input node changed during inventory' >&2; exit 1; }
    ids='{}' caps='{}'
    for key in bustype vendor product version; do
        value=$(read_hex "$entry/device/id/$key" id) || { echo 'Invalid or unavailable input type ID' >&2; exit 1; }
        ids=$(jq -c --arg key "$key" --arg value "$value" '. + {($key):$value}' <<< "$ids")
    done
    for key in ev key rel abs msc led snd ff sw; do
        value=$(read_hex "$entry/device/capabilities/$key" bitmap) || { echo 'Invalid or unavailable input capability bitmap' >&2; exit 1; }
        caps=$(jq -c --arg key "$key" --arg value "$value" '. + {($key):$value}' <<< "$caps")
    done
    # Hotplug can invalidate this snapshot at any time; never call it atomic.
    [[ -d $entry/device ]] || exit 1
    records=$(jq -c --arg node "$node" --argjson ids "$ids" --argjson caps "$caps" \
        '. + [{node:$node,type_ids:$ids,capability_hex_words:$caps}]' <<< "$records")
done
jq -n --argjson records "$records" '{schema:1,source:"linux-input-sysfs",snapshot_atomic:false,
  device_nodes_opened:false,physical_capabilities_verified:false,input_nodes:$records}'
