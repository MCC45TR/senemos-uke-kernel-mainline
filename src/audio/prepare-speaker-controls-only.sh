#!/usr/bin/env bash
# Source-only cumulative integration: preserve DT/topology/UCM/firmware/config.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel source}")
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
bash "$owner/src/audio/prepare-control-links.sh" "$kernel"
install -Dm644 "$owner/src/audio/uke-fs19xx-guard.h" "$kernel/include/sound/uke-fs19xx-guard.h"
for name in uke-fs19xx-runtime.c uke-fs19xx-runtime.h uke-fs19xx-protocol.h uke-fs19xx-safety.h; do
 install -m644 "$owner/src/audio/$name" "$kernel/sound/soc/qcom/qdsp6/$name"
done
# Keep every legacy amplifier callback and electrical write byte-identical.
git -C "$kernel" apply --check --exclude=sound/soc/codecs/fs19xx.c "$owner/patches/boot/0073-uke-fs19xx-protected-runtime.patch"
git -C "$kernel" apply --exclude=sound/soc/codecs/fs19xx.c "$owner/patches/boot/0073-uke-fs19xx-protected-runtime.patch"
printf '\nCFLAGS_uke-fs19xx-runtime.o += -DUKE_FS19XX_CONTROLS_ONLY\n' >> "$kernel/sound/soc/qcom/qdsp6/Makefile"
printf '%s\n' 'Uke provisioning controls compiled; protected graph requires separate DT admission; gain ceiling223.'
