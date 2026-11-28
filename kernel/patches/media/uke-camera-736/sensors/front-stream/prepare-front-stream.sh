#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
[[ $# == 2 ]]
assets=$(cd -- "$(dirname -- "$0")" && pwd -P)
cd "$(realpath -e -- "$2")"
patch=$assets/0001-media-bind-fitted-uke-front-streaming.patch
case "$1" in
    prepare)
        test ! -e drivers/media/i2c/uke-front-camera-resources.h
        sha256sum -c --strict "$assets/before.sha256"
        git apply -p2 --check --whitespace=error "$patch"
        git apply -p2 --whitespace=error "$patch"
        sha256sum -c --strict "$assets/after.sha256"
        ;;
    restore)
        sha256sum -c --strict "$assets/after.sha256"
        git apply -R -p2 --check --whitespace=error "$patch"
        git apply -R -p2 --whitespace=error "$patch"
        test ! -e drivers/media/i2c/uke-front-camera-resources.h
        sha256sum -c --strict "$assets/before.sha256"
        ;;
    *) exit 64 ;;
esac
