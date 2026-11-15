#!/usr/bin/env bash
# COPR only: the same admitted codec and contract in both build recipes.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
profile=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
printf '%s  %s\n' deab992b29201d6973f6f8f1a694c356e7c7ba5f2d6b5f4d31ddca35f085358b "$profile/src/boot/boot-image.cpp" | sha256sum -c --strict -
printf '%s  %s\n' 2ff6a874fb60749ced1504aff552557fb1e732c52c6ee91dbb96e5ad17e776fc "$profile/tests/boot-image-contract.sh" | sha256sum -c --strict -
printf '%s  %s\n' 81dcec546b0352e1231209ae0ce94452875f1891e2f792dcb3e323e2c711897b "$profile/tests/bootloader-compat-contract.sh" | sha256sum -c --strict -
for compiler in g++ clang++; do
 for mode in ordinary sanitized;do
  flags=();[[ $mode == ordinary ]] || flags=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" -std=c++20 -O2 -Wall -Wextra -Werror "${flags[@]}" "$profile/src/boot/boot-image.cpp" -o "$work/codec"
  bash "$profile/tests/boot-image-contract.sh" "$work/codec"
  bash "$profile/tests/bootloader-compat-contract.sh" "$work/codec"
 done
done
