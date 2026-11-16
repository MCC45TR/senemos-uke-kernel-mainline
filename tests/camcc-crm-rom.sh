#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR only. Never compile this fixture on the tablet or development PC.
set -Eeuo pipefail
[[ $# == 0 && ! -e /etc/senemos/kernel-update.conf ]]
project=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/linux"
printf '%s\n' '#pragma once' > "$work/linux/types.h"
cp "$project"/src/camera/provider/camcc-sm7675-crm-{core,lut}.h "$work/"
cp "$project/src/camera/provider/camcc-sm7675-crm-rom.h" "$work/rom.h"
node - "$project/src/camera/provider/camcc-sm7675-crm-passive.h" "$work/passive-pll.h" <<'JS'
const fs=require('fs'),[input,output]=process.argv.slice(2),s=fs.readFileSync(input,'utf8');
const begin='static int cam_cc_crm_passive_pll_rate(',end='static int cam_cc_crm_passive_index(';
if(s.split(begin).length!==2||s.split(end).length!==2)throw Error('Exact production arithmetic anchors');
fs.writeFileSync(output,s.slice(s.indexOf(begin),s.indexOf(end)));
JS
for compiler in gcc clang; do
 for mode in plain address-undefined; do
  flags=()
  if [[ $mode != plain ]]; then flags=("-fsanitize=address,undefined" -fno-sanitize-recover=all -fno-omit-frame-pointer); fi
  "$compiler" -std=gnu11 -O1 -g -Wall -Wextra -Werror "${flags[@]}" -I"$work" \
   "$project/tests/fixtures/camcc-crm-rom-check.c" -o "$work/check"
  ASAN_OPTIONS=detect_leaks=1:halt_on_error=1 "$work/check"
 done
done
