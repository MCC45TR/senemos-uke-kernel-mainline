#!/usr/bin/env bash
# COPR source preparation only. Existing topologies contain no IMCL tokens.
set -Eeuo pipefail
kernel=$(realpath "${1:?Pass prepared kernel source}")
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
patch=$owner/patches/boot/0072-audioreach-control-links.patch
install -m644 "$owner/src/audio/audioreach-control-links.h" \
    "$kernel/sound/soc/qcom/qdsp6/audioreach-control-links.h"
git -C "$kernel" apply --check "$patch"
git -C "$kernel" apply "$patch"
CC=clang bash "$owner/tests/audio-control-links-contract.sh"
CC=clang bash "$owner/tests/audio-control-links-integration.sh" "$kernel"
