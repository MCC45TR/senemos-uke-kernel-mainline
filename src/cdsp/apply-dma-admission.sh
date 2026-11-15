#!/usr/bin/bash
# COPR source preparation only; retain the existing PAS/DT/SMMU contracts.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
kernel=$(realpath "${1:?Prepared Linux tree}")
source=$kernel/drivers/misc/fastrpc.c
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
extract() { awk '/^static int fastrpc_cb_probe\(/{p=1}p{print}p&&/^}/{exit}' "$1"; }
extract "$source" > "$work/actual"
extract "$owner/src/cdsp/fastrpc-cb-probe731-fixed.h" > "$work/fixed"
if cmp -s "$work/actual" "$work/fixed"; then
    printf 'Exact FastRPC DMA admission already present\n'
    exit 0
fi
extract "$owner/tests/fixtures/fastrpc-cb-probe731-original.h" > "$work/original"
cmp "$work/actual" "$work/original"
git -C "$kernel" apply --check "$owner/src/cdsp/0002-fastrpc-dma-before-session.patch"
git -C "$kernel" apply "$owner/src/cdsp/0002-fastrpc-dma-before-session.patch"
extract "$source" > "$work/actual"
cmp "$work/actual" "$work/fixed"
