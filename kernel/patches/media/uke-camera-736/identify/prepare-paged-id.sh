#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
[[ $# == 2 ]]
assets=$(cd -- "$(dirname -- "$0")" && pwd -P)
source=$(realpath -e -- "$2")
patchfile="$assets/0001-media-verify-fitted-uke-front-paged-id.patch"
cd "$source"

case "$1" in
    prepare)
        sha256sum -c --strict "$assets/before.sha256"
        patch --batch --forward --dry-run --fuzz=0 -d drivers/media/i2c -p1 -i "$patchfile"
        patch --batch --forward --fuzz=0 -d drivers/media/i2c -p1 -i "$patchfile"
        sha256sum -c --strict "$assets/after.sha256"
        ;;
    restore)
        sha256sum -c --strict "$assets/after.sha256"
        patch --batch --reverse --dry-run --fuzz=0 -d drivers/media/i2c -p1 -i "$patchfile"
        patch --batch --reverse --fuzz=0 -d drivers/media/i2c -p1 -i "$patchfile"
        sha256sum -c --strict "$assets/before.sha256"
        ;;
    *)
        exit 64
        ;;
esac
