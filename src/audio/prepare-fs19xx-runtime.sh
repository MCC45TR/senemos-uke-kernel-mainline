#!/usr/bin/env bash
# Explicit protected candidate only; call after native adaptation and IMCL.
set -Eeuo pipefail
kernel=$(realpath "${1:?Prepared kernel source}")
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
install -Dm644 "$owner/src/audio/uke-fs19xx-guard.h" "$kernel/include/sound/uke-fs19xx-guard.h"
for name in uke-fs19xx-runtime.c uke-fs19xx-runtime.h uke-fs19xx-protocol.h uke-fs19xx-safety.h; do
    install -m644 "$owner/src/audio/$name" "$kernel/sound/soc/qcom/qdsp6/$name"
done
git -C "$kernel" apply --check "$owner/patches/boot/0073-uke-fs19xx-protected-runtime.patch"
git -C "$kernel" apply "$owner/patches/boot/0073-uke-fs19xx-protected-runtime.patch"
