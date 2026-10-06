#!/usr/bin/env bash
# Run with host dtc/fdtoverlay in the pinned container and regular-file inputs.
set -Eeuo pipefail
[[ $# == 3 ]] || exit 2
root=$(realpath "$1") inputs=$(realpath "$2") out=$(realpath -m "$3")
# shellcheck source=../src/boot/stock-dt.sh
# shellcheck disable=SC1091
source "$root/src/boot/stock-dt.sh"
die() { echo "$*" >&2; exit 1; }
mkdir -p "$out"
vendor=$inputs/vendor_boot.img overlay=$inputs/dtbo.img
sha256sum "$vendor" "$overlay" > "$out/input-before.sha256"
reject() {
    local name=$1; shift
    if (stock_extract "$@" "$out/$name") > "$out/$name.log" 2>&1; then die "Accepted corrupt stock input: $name"; fi
}
cp --reflink=auto "$vendor" "$out/bad-vendor.img"
printf BADMAGIC | dd of="$out/bad-vendor.img" conv=notrunc status=none
reject magic "$out/bad-vendor.img" "$overlay"
head -c 2128 "$vendor" > "$out/short-vendor.img"
reject truncated "$out/short-vendor.img" "$overlay"
cp --reflink=auto "$vendor" "$out/bad-vendor.img"
printf '\377\377\377\377' | dd of="$out/bad-vendor.img" bs=1 seek=2100 conv=notrunc status=none
reject dtb-length "$out/bad-vendor.img" "$overlay"
cp --reflink=auto "$vendor" "$out/bad-vendor.img"
printf '\003\000\000\000' | dd of="$out/bad-vendor.img" bs=1 seek=8 conv=notrunc status=none
reject version "$out/bad-vendor.img" "$overlay"
cp --reflink=auto "$overlay" "$out/bad-dtbo.img"
printf '\000\000\000\000' | dd of="$out/bad-dtbo.img" bs=1 seek=16 conv=notrunc status=none
reject no-overlay "$vendor" "$out/bad-dtbo.img"
cp --reflink=auto "$overlay" "$out/bad-dtbo.img"
printf '\377\377\377\377' | dd of="$out/bad-dtbo.img" bs=1 seek=36 conv=notrunc status=none
reject overlay-bounds "$vendor" "$out/bad-dtbo.img"
sha256sum -c "$out/input-before.sha256" > "$out/read-only.txt"
echo 'Six corrupt/truncated stock input cases rejected; original image hashes unchanged'
