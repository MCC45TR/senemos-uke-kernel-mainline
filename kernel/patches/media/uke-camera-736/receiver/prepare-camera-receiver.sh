#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
[[ $# == 2 ]]
assets=$(cd -- "$(dirname -- "$0")" && pwd -P)
tree=$(realpath -e -- "$2")
patches=(
    "$assets/cliffs-camera-ahb.patch"
    "$assets/uke-camss-smmu.patch"
    "$assets/uke-rear-camera-rails.patch"
    "$assets/cci-pm-lifetime.patch"
)
cd "$tree"
case "$1" in
    prepare)
        sha256sum -c --strict "$assets/before.sha256"
        git apply --check --whitespace=error "${patches[@]}"
        git apply --whitespace=error "${patches[@]}"
        sha256sum -c --strict "$assets/after.sha256"
        ;;
    restore)
        sha256sum -c --strict "$assets/after.sha256"
        git apply --reverse --check --whitespace=error "${patches[@]}"
        git apply --reverse --whitespace=error "${patches[@]}"
        test ! -e drivers/iommu/arm/arm-smmu/uke-camss-smmu.c
        sha256sum -c --strict "$assets/before.sha256"
        ;;
    *) exit 64 ;;
esac
