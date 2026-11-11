#!/usr/bin/env bash
# COPR/source only. Preserve the full prepared kernel and every admission gate.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
owner=$(cd -- "$(dirname -- "$0")/../../.." && pwd)
source_file=$kernel/drivers/clk/qcom/gcc-cliffs.c
patch_file=$owner/src/camera/provider/0006-gcc-cliffs-camera-config.patch
before=8d6235495d6176a344989f289470e6187e56a9e3d6a157566200729c0a6c8568
after=f57b6a5aecebc265fdfe25b6f06acae992853f139a3980103c9b86f3870bca7b
[[ -f $source_file && ! -L $source_file ]]
digest=$(sha256sum "$source_file"); digest=${digest%% *}
if [[ $digest == "$after" ]]; then
    printf '%s  %s\n' "$before" "$kernel/native-generated/gcc-before-camera-config.c" | sha256sum -c --strict -
    printf 'Exact GCC camera configuration layer already present; no mutation\n'
    exit 0
fi
printf '%s  %s\n' "$before" "$source_file" | sha256sum -c --strict -
git -C "$kernel" apply --check "$patch_file"
install -Dm644 "$source_file" "$kernel/native-generated/gcc-before-camera-config.c"
git -C "$kernel" apply "$patch_file"
printf '%s  %s\n' "$after" "$source_file" | sha256sum -c --strict -
printf 'Exact OEM GCC camera configuration delta applied; physical cameras remain unqualified\n'
