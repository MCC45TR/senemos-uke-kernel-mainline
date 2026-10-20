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
for name in iris-source ufs-source cpucp-read accessory-source thermal-source; do
    manifest=manifests/$name-candidate-20261020.json
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
echo 'Source hash corruption, escaping symlink and accidental activation refused'
