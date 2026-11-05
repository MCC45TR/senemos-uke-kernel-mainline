#!/usr/bin/env bash
# COPR only: the same admitted codec and contract in both build recipes.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
profile=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
printf '%s  %s\n' d8391eacf845448f3134892f1be431ba1e3f51c58aa522370728ff4965f3dcfa "$profile/src/boot/boot-image.cpp" | sha256sum -c --strict -
printf '%s  %s\n' 2ff6a874fb60749ced1504aff552557fb1e732c52c6ee91dbb96e5ad17e776fc "$profile/tests/boot-image-contract.sh" | sha256sum -c --strict -
for compiler in g++ clang++; do
 "$compiler" -std=c++20 -O2 -Wall -Wextra -Werror "$profile/src/boot/boot-image.cpp" -o "$work/codec"
 bash "$profile/tests/boot-image-contract.sh" "$work/codec"
done
