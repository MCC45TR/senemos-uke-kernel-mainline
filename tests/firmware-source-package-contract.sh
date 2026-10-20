#!/usr/bin/env bash
# Host-only source inventory. Never applies a candidate patch or probes hardware.
set -Eeuo pipefail
[[ $# == 2 && -d $1 && $2 =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]] || exit 2
root=$(realpath -- "$1")
series=$root/patches/$2/series
[[ -f $series ]]
count=0
for name in iris-source ufs-source cpucp-read accessory-source thermal-source; do
    manifest=$root/manifests/$name-candidate-20261020.json
    jq -e '.active_series == false and (.dt_enabled // false) == false and
      (.protocol_registered // false) == false and (.consumer_added // false) == false and
      (.crypto_enabled // false) == false and (.state_changing_messages // false) == false and
      (.patches|type)=="array" and (.patches|length)>0' "$manifest" >/dev/null
    records=$(jq -er '.patches[], .source_assets[]? | [.path,.sha256] | @tsv' "$manifest")
    while IFS=$'\t' read -r path expected; do
        [[ $path =~ ^(src|patches)/[a-zA-Z0-9_./-]+$ && $path != *..* && $expected =~ ^[a-f0-9]{64}$ ]]
        resolved=$(realpath -e -- "$root/$path")
        [[ $resolved == "$root/"* && -f $resolved ]]
        actual=$(sha256sum -- "$resolved"); actual=${actual%% *}
        [[ $actual == "$expected" ]]
        if [[ $path == patches/* ]] && grep -Fxq -- "${path##*/}" "$series"; then
            echo 'Inactive firmware patch entered the active series' >&2; exit 1
        fi
        count=$((count+1))
    done <<< "$records"
done
printf 'Inactive firmware source inventory: %s pinned files, no activation\n' "$count"
