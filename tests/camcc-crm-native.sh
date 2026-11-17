#!/usr/bin/bash
# COPR only: compile the actual constructor and caller boundary fixtures.
set -Eeuo pipefail
[[ $# == 1 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(realpath "$1")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$work/linux"
for header in compiler mutex types;do printf '#pragma once\n' > "$work/linux/$header.h";done
for header in core lut clock startup floor native;do
 cp "$owner/src/camera/provider/camcc-sm7675-crm-$header.h" "$work/"
done
for compiler in gcc clang;do
 for mode in plain sanitized;do
  flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -Wno-unused-function)
  [[ $mode != sanitized ]] || flags+=("-fsanitize=address,undefined" -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" "${flags[@]}" -I"$work" "$owner/tests/fixtures/camcc-crm-native-check.c" -o "$work/check"
  readelf -h "$work/check" | grep -F AArch64
  timeout --kill-after=2s 20s "$work/check"
 done
done
