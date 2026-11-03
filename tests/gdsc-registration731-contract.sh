#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Native COPR fault fixture. Never run project compilation on the tablet.
set -Eeuo pipefail
[[ $# == 3 ]] || exit 2
original=$(realpath -- "$1")
header=$(realpath -- "$2")
production=$(realpath -- "$3")
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
printf '%s  %s\n' \
    04c66019948835d4b0def6f96d940500a85eb3e9c277f69de06c953f7d6475d2 "$original" \
    bea8e934482c13e1318ebe59bfd881cb91536e32afd9dae2676da9514d140ae9 "$header" | sha256sum -c -
mkdir -p "$work/drivers/clk/qcom"
cp "$original" "$work/drivers/clk/qcom/gdsc.c"
sed '/^#include /d' "$header" > "$work/gdsc-header.h"
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -Wno-unused-function
       -Wno-unused-parameter -Wno-sign-compare -I"$work")
fixture=$project/tests/fixtures/gdsc-registration731.c
sed '/^#include /d' "$original" > "$work/gdsc-functions.c"
"${CC:-cc}" "${flags[@]}" -DBASELINE "$fixture" -o "$work/baseline"
"$work/baseline"
"${CC:-cc}" "${flags[@]}" "$fixture" -o "$work/before"
set +e
"$work/before" > "$work/before.log" 2>&1
status=$?
set -e
[[ $status == 134 ]]
grep -Fq '!registered' "$work/before.log"
printf 'GDSC: identical cleanup assertions reproduce the unpatched registration leak (exit %s)\n' "$status"
git -C "$work" apply --check "$project/src/camera/provider/0001-gdsc-registration-unwind731.patch"
git -C "$work" apply "$project/src/camera/provider/0001-gdsc-registration-unwind731.patch"
cmp "$production" "$work/drivers/clk/qcom/gdsc.c"
sed '/^#include /d' "$production" > "$work/gdsc-functions.c"
"${CC:-cc}" "${flags[@]}" "$fixture" -o "$work/candidate"
"$work/candidate"
"${CC:-cc}" "${flags[@]}" -fsanitize=address,undefined -fno-omit-frame-pointer \
    "$fixture" -o "$work/candidate-sanitized"
ASAN_OPTIONS=detect_leaks=1 "$work/candidate-sanitized"
printf 'GDSC: actual patched production source matches the tested source; plain and ASan/UBSan checks passed\n'
