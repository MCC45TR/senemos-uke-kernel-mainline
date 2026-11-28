#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
[[ $# == 1 ]]
base=$(realpath -e -- "$1")
[[ $base != / && -x $base/usr/lib/systemd/systemd ]]
dir=$base/usr/lib/systemd/system
[[ $(realpath -e -- "$dir") == "$dir" ]]
units=("$dir"/{uke-root-guard,uke-initrd-screen,uke-userdata-grow}.service)
for unit in "${units[@]}"; do
    [[ -f $unit && ! -L $unit ]]
    grep -Fxq '[Service]' "$unit"
done
chmod 0644 -- "${units[@]}"
