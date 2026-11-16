#!/usr/bin/bash
# Separate the sanitized ALSA identifier from the dotted firmware/module alias.
set -Eeuo pipefail
[[ $# == 1 || $# == 2 ]]
profile=$(realpath "$1")
tuple=$(bash "$profile/scripts/kernel-release.sh" json "$profile/manifests/cumulative-release.json")
driver=$(jq -er .audio_driver <<< "$tuple")
alias=$(jq -er .firmware_alias <<< "$tuple")
[[ ${alias//./_} == "$driver" ]]
jq -e --arg driver "$driver" --arg abi "$(jq -er .kernel_release <<< "$tuple")" \
 --arg release "$(jq -er .release <<< "$tuple")" \
 '.diagnostic_audio_driver==$driver and .kernel_release==$abi and .rpm_revision==$release' \
 "$profile/source-composition.json" >/dev/null
if [[ $# == 2 ]];then
 object=$(realpath "$2")
 llvm-readelf -h "$object" | grep -F AArch64
 strings "$object" | grep -Fx "$alias"
 printf 'Actual audio object/metadata identity passed: driver=%s alias=%s.\n' "$driver" "$alias"
else
 printf 'Audio metadata identity passed: driver=%s alias=%s; no object acceptance.\n' "$driver" "$alias"
fi
