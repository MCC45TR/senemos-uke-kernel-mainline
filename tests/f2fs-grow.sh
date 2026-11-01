#!/usr/bin/env bash
# Host-only original f2fs-tools on a temporary regular file; no block target.
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
mkdir -p build/tests
compiler=${CXX:-c++}
flags=(-std=c++20 -O2 -Wall -Wextra -Werror -Wno-unused-function)
if [[ ${SANITIZE:-0} == 1 ]]; then flags+=(-O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer); fi
"$compiler" "${flags[@]}" tests/f2fs-grow.cpp -o build/tests/f2fs-grow
"$compiler" -std=c++20 -O2 -Wall -Wextra -Werror src/boot/f2fs-grow.cpp -o build/tests/uke-f2fs-grow
fixture=$(mktemp -d);trap 'rm -rf -- "$fixture"' EXIT
truncate -s 512M "$fixture/root.img"
mkfs.f2fs -f -l UKE_LINUX -O extra_attr,inode_checksum,sb_checksum "$fixture/root.img" > "$fixture/mkfs.log" 2>&1
build/tests/f2fs-grow "$fixture/root.img"
if build/tests/uke-f2fs-grow "$fixture/root.img" > "$fixture/refused.log" 2>&1; then
    echo 'Production grower must refuse a regular-file target' >&2;exit 1
fi
grep -Fq 'UKE_F2FS_GROW_REJECTED' "$fixture/refused.log"
grep -Fq '/usr/libexec/uke-f2fs-grow "$candidate"' src/boot/dracut/root-guard.sh
grep -Fxq 'Before=sysroot.mount' src/boot/dracut/uke-root-guard.service
grep -Fq 'inst_binary "$moddir/uke-f2fs-grow"' src/boot/dracut/module-setup.sh
