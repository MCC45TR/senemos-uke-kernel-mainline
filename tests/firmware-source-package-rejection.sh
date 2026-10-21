#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# == 2 ]]
root=$(realpath -- "$1") version=$2
check=$root/tests/firmware-source-package-contract.sh
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
fixture=$work/profile
mkdir -p "$fixture/manifests" "$fixture/patches/$version"
cp "$root/patches/$version/series" "$fixture/patches/$version/series"
for name in iris-source-candidate-20261020 ufs-source-candidate-20261020 \
    cpucp-read-candidate-20261020 accessory-source-candidate-20261020 \
    thermal-source-candidate-20261020 camera-source-candidate-20261021 \
    camcc-source-candidate-20261021 camera-board-candidate-20261021; do
    manifest=manifests/$name.json
    cp "$root/$manifest" "$fixture/$manifest"
    paths=$(jq -er '.patches[], .source_assets[]? | .path' "$root/$manifest")
    while IFS= read -r path; do
        mkdir -p "$fixture/$(dirname -- "$path")"
        cp "$root/$path" "$fixture/$path"
    done <<< "$paths"
done
bash "$check" "$fixture" "$version"
asset=src/video/uke-videocc-votes.c
printf 'corrupt\n' >> "$fixture/$asset"
if bash "$check" "$fixture" "$version" >/dev/null 2>&1; then exit 1; fi
cp "$root/$asset" "$fixture/$asset"
mv "$fixture/$asset" "$work/external.c"
ln -s "$work/external.c" "$fixture/$asset"
if bash "$check" "$fixture" "$version" >/dev/null 2>&1; then exit 1; fi
printf '%s\n' "$(jq -r '.patches[0].path|split("/")|last' "$root/manifests/ufs-source-candidate-20261020.json")" >> "$fixture/patches/$version/series"
cp "$root/$asset" "$work/repaired.c"
mv "$work/repaired.c" "$fixture/$asset"
if bash "$check" "$fixture" "$version" >/dev/null 2>&1; then exit 1; fi
cp "$root/patches/$version/series" "$fixture/patches/$version/series"
printf '%s\n' '0001-dt-bindings-eeprom-camera-64k-models.patch' >> "$fixture/patches/$version/series"
if bash "$check" "$fixture" "$version" >/dev/null 2>&1; then exit 1; fi
cp "$root/patches/$version/series" "$fixture/patches/$version/series"
header=src/camera/include/dt-bindings/clock/qcom,sm7675-camcc.h
printf 'corrupt\n' >> "$fixture/$header"
if bash "$check" "$fixture" "$version" >/dev/null 2>&1; then exit 1; fi
cp "$root/$header" "$fixture/$header"
jq '.active_config = true' "$fixture/manifests/camcc-source-candidate-20261021.json" > "$work/activated.json"
cp "$work/activated.json" "$fixture/manifests/camcc-source-candidate-20261021.json"
if bash "$check" "$fixture" "$version" >/dev/null 2>&1; then exit 1; fi
echo 'Firmware/camera hash corruption, escaping symlink, patch activation and active clock configuration refused'
