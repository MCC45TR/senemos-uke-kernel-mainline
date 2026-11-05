#!/usr/bin/env bash
# COPR source preparation only; no device operation.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
kernel=$(realpath -- "${1:?Prepared cumulative kernel tree}")
directory=$kernel/drivers/iommu/arm/arm-smmu
test -f "$directory/uke-video-smmu.c"
test ! -e "$directory/uke-cdsp-smmu.c"
git -C "$kernel" apply --check "$owner/patches/cdsp/0001-uke-cdsp-actlr.patch"
git -C "$kernel" apply "$owner/patches/cdsp/0001-uke-cdsp-actlr.patch"
install -m644 "$owner/src/cdsp/uke-cdsp-smmu.c" "$directory/uke-cdsp-smmu.c"
