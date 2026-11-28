#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
[[ $# == 2 ]]
assets=$(cd -- "$(dirname -- "$0")" && pwd -P)
tree=$(realpath -e -- "$2")
patchfile=$assets/0001-media-admit-fitted-uke-rear-identity.patch
makefile=drivers/media/i2c/Makefile
front_rule='obj-$(CONFIG_SM_CAMCC_7675) += uke-front-camera-id.o'
rear_rule='obj-$(CONFIG_SM_CAMCC_7675) += uke-rear-camera-id.o'
new_files=(
    arch/arm64/kernel/uke-rear-camera-id-dt.h
    Documentation/devicetree/bindings/media/i2c/xiaomi,uke-rear-camera-identify.yaml
    drivers/media/i2c/uke-camera-sensor-clock.h
    drivers/media/i2c/uke-rear-camera-id.c
    drivers/media/i2c/uke-rear-camera-power.h
)
cd "$tree"
[[ -f $makefile && ! -L $makefile ]]
[[ $(grep -Fxc "$front_rule" "$makefile") == 1 ]]
case "$1" in
    prepare)
        ! grep -Fq 'uke-rear-camera-id.o' "$makefile"
        [[ $(tail -c 1 "$makefile" | od -An -tx1 | tr -d '[:space:]') == 0a ]]
        for file in "${new_files[@]}"; do [[ ! -e $file && ! -L $file ]]; done
        sha256sum -c --strict "$assets/before.sha256"
        git apply --check -p2 --whitespace=error "$patchfile"
        git apply -p2 --whitespace=error "$patchfile"
        printf '%s\n' "$rear_rule" >> "$makefile"
        sha256sum -c --strict "$assets/after.sha256"
        ;;
    restore)
        [[ $(tail -n1 "$makefile") == "$rear_rule" ]]
        [[ $(grep -Fxc "$rear_rule" "$makefile") == 1 ]]
        [[ ! -e drivers/media/i2c/uke-front-camera-clock.h ]]
        sha256sum -c --strict "$assets/after.sha256"
        git apply --reverse --check -p2 --whitespace=error "$patchfile"
        git apply --reverse -p2 --whitespace=error "$patchfile"
        sed -i '$d' "$makefile"
        for file in "${new_files[@]}"; do [[ ! -e $file && ! -L $file ]]; done
        sha256sum -c --strict "$assets/before.sha256"
        ;;
    *) exit 64 ;;
esac
