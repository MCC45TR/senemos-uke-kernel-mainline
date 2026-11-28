#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
[[ $# == 2 ]]
assets=$(cd -- "$(dirname -- "$0")" && pwd -P)
tree=$(realpath -e -- "$2")
patch=$assets/0001-arm64-admit-fitted-uke-camss.patch
graph=arch/arm64/kernel/uke-camss-dt.h
binding=Documentation/devicetree/bindings/media/qcom,sm7675-camss.yaml
cd "$tree"

case "$1" in
    prepare)
        [[ ! -e $graph && ! -L $graph && ! -e $binding && ! -L $binding ]]
        sha256sum -c --strict "$assets/before.sha256"
        git apply --check -p2 --whitespace=error "$patch"
        git apply -p2 --whitespace=error "$patch"
        sha256sum -c --strict "$assets/after.sha256"
        ;;
    restore)
        sha256sum -c --strict "$assets/after.sha256"
        git apply -R --check -p2 --whitespace=error "$patch"
        git apply -R -p2 --whitespace=error "$patch"
        [[ ! -e $graph && ! -L $graph && ! -e $binding && ! -L $binding ]]
        sha256sum -c --strict "$assets/before.sha256"
        ;;
    *) exit 64 ;;
esac
