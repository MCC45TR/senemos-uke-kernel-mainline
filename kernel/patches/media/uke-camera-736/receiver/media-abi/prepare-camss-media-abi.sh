#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
[[ $# == 2 ]]
assets=$(cd -- "$(dirname -- "$0")" && pwd -P)
tree=$(realpath -e -- "$2")
patch=$assets/0001-media-camss-keep-standard-device-info-name.patch
cd "$tree"
case "$1" in
    prepare)
        sha256sum -c --strict "$assets/before.sha256"
        git apply --check --whitespace=error "$patch"
        git apply --whitespace=error "$patch"
        sha256sum -c --strict "$assets/after.sha256"
        ;;
    restore)
        sha256sum -c --strict "$assets/after.sha256"
        git apply --reverse --check --whitespace=error "$patch"
        git apply --reverse --whitespace=error "$patch"
        sha256sum -c --strict "$assets/before.sha256"
        ;;
    *) exit 64 ;;
esac
