#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
shopt -s nullglob

fail()
{
    printf '%s\n' "$*" >&2
    exit 78
}

[[ $# == 3 && $1 =~ ^7\.3\.6-[0-9]+-unstable$ && $2 =~ ^[0-9a-f]{64}$ ]] ||
    fail 'Expected a kernel release, source manifest checksum and observe/identify'
release=$1
source_sha=$2
case "$3" in observe|identify) ;; *) fail 'Unknown action' ;; esac
[[ $EUID == 0 && $(uname -m) == aarch64 && $(uname -r) == "$release" ]] ||
    fail 'The expected signed camera kernel is not running'

dt=/sys/firmware/devicetree/base
grep -azFxq xiaomi,uke "$dt/compatible" && grep -azFxq qcom,sm7675 "$dt/compatible" ||
    fail 'Unexpected tablet or SoC'
identity=/usr/share/senemos/uke/$release
printf '%s  %s\n' "$source_sha" "$identity/camera-discovery-source.sha256" |
    sha256sum -c --strict --quiet - || fail 'Missing or mismatched camera source record'
[[ $(wc -l < "$identity/camera-discovery-objects.sha256") == 8 ]] ||
    fail 'Missing linked camera object record'

device_for_path()
{
    local bus=$1 path=$2 dev
    local matches=()
    for dev in /sys/bus/"$bus"/devices/*; do
        [[ -L $dev/of_node ]] || continue
        if [[ $(realpath -e -- "$dev/of_node") == "$dt$path" ]]; then
            matches+=("$dev")
        fi
    done
    [[ "${#matches[@]}" == 1 ]] || return 1
    realpath -e -- "${matches[0]}"
}

camss=$(device_for_path platform /soc/isp@acb6000) || fail 'CAMSS is absent'
[[ -L $camss/driver && $(basename "$(realpath -e "$camss/driver")") == qcom-camss-sm7675 ]] ||
    fail 'The permanent native CAMSS driver is missing'
media=()
for candidate in /sys/class/media/media*; do
    [[ -L $candidate/device ]] || continue
    if [[ $(realpath -e -- "$candidate/device") == "$camss" ]]; then
        media+=("/dev/$(basename "$candidate")")
    fi
done
[[ "${#media[@]}" == 1 && -c "${media[0]}" ]] || fail 'Expected one native Media Controller device'
media_info=$(timeout 8 media-ctl -d "${media[0]}" -p) || fail 'Cannot read Media Controller information'
grep -Eq '^[[:space:]]*driver[[:space:]]+qcom-camss[[:space:]]*$' <<< "$media_info" || fail 'Unexpected Media Controller ABI name'
printf 'receiver=%s driver=qcom-camss pm=%s\n' "${media[0]}" "$(cat "$camss/power/runtime_status")"

if [[ $3 == identify ]]; then
    front=$(device_for_path i2c /soc/qcom,qupv3_1_geni_se@8c0000/i2c@880000/camera@10) ||
        fail 'Front identity device is absent'
    rear=$(device_for_path i2c /soc/i2c@ac15000/i2c-bus@1/camera@10) ||
        fail 'Rear identity device is absent'
    [[ $(basename "$(realpath -e "$front/driver")") == uke-front-camera-identify &&
       $(basename "$(realpath -e "$rear/driver")") == uke-rear-camera-identify ]] ||
        fail 'Unexpected identity driver'
    front_oem=$(timeout 12 cat "$front/sensor_id")
    front_model=$(timeout 12 cat "$front/paged_sensor_id")
    rear_oem=$(timeout 12 cat "$rear/sensor_id")
    rear_model=$(timeout 12 cat "$rear/model_id")
    printf 'front_oem=%s front_paged=%s rear_oem=%s rear_model=%s\n' \
        "$front_oem" "$front_model" "$rear_oem" "$rear_model"
    [[ $front_oem == 0x5647 && $front_model == 0x5608 &&
       $rear_oem == 0x0d42 && $rear_model == 0x560d42 ]] || fail 'Unexpected fitted camera identity'
fi
