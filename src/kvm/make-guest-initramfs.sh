#!/usr/bin/env bash
# Run in a native AArch64 build environment; no RPMs or Python enter the archive.
set -Eeuo pipefail
[[ $# == 1 && ! -e $1 && $(uname -m) == aarch64 ]] || exit 64
out=$(realpath -m "$1")
here=$(cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$out/root"/{dev,proc,sys}
g++ -std=c++17 -O2 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -Wl,--as-needed \
    "$here/guest-init.cpp" -o "$out/root/init"
readelf -h "$out/root/init" | grep -E 'Machine:.*AArch64' >/dev/null
interpreter=$(readelf -l "$out/root/init" | sed -n 's/.*interpreter: \(.*\)\]/\1/p')
[[ $interpreter == /lib/ld-linux-aarch64.so.1 || $interpreter == /lib64/ld-linux-aarch64.so.1 ]]
install -Dm755 "$interpreter" "$out/root$interpreter"
needed=$(readelf -d "$out/root/init" | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p')
[[ $needed == libc.so.6 ]]
libc=$(ldconfig -p | awk '$1 == "libc.so.6" { print $NF; exit }')
[[ -f $libc ]]
install -Dm755 "$libc" "$out/root$libc"
find "$out/root" -exec touch -h -d '@0' {} +
(cd "$out/root"; find . -print0 | LC_ALL=C sort -z | cpio --null --quiet --reproducible --owner=0:0 -o -H newc) |
    gzip -n > "$out/guest-initramfs.cpio.gz"
(cd "$out"; sha256sum guest-initramfs.cpio.gz > SHA256SUMS)
echo 'RAM-only guest initramfs built; no guest or Uke hardware test performed'
