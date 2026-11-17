#!/usr/bin/bash
# COPR only: inherited AP0 vote floor lifetime; no MMIO.
set -Eeuo pipefail
[[ $# == 0 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
mkdir "$work/linux"
for name in types compiler mutex;do printf '%s\n' '#pragma once' > "$work/linux/$name.h";done
cp "$owner"/src/camera/provider/camcc-sm7675-crm-{core,floor}.h "$work/"
for compiler in gcc clang;do
 for mode in plain sanitized;do
  flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror)
  [[ $mode != sanitized ]] || flags+=("-fsanitize=address,undefined" -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" "${flags[@]}" -I"$work" "$owner/tests/fixtures/camcc-crm-floor-check.c" -o "$work/check"
  readelf -h "$work/check" | grep -F AArch64
  timeout --kill-after=2s 20s "$work/check"
 done
done
for mutant in drop-floor release-after-fault;do
 node - "$owner/src/camera/provider/camcc-sm7675-crm-floor.h" "$work/camcc-sm7675-crm-floor.h" "$mutant" <<'JS'
const fs=require('fs'),[src,out,kind]=process.argv.slice(2),s=fs.readFileSync(src,'utf8');
const a=kind==='drop-floor'?'!floor->released && value < floor->minimum[index]':'if (floor->fault) {';
const b=kind==='drop-floor'?'false && !floor->released && value < floor->minimum[index]':'if (false && floor->fault) {';
if(s.split(a).length!==(kind==='drop-floor'?2:3))throw Error('Exact floor mutant anchors');
fs.writeFileSync(out,s.replaceAll(a,b));
JS
 gcc -std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -I"$work" "$owner/tests/fixtures/camcc-crm-floor-check.c" -o "$work/mutant"
 status=0
 timeout --kill-after=2s 20s "$work/mutant" > "$work/mutant.log" 2>&1 || status=$?
 [[ $status == 134 ]]
 printf 'Inherited floor semantic mutant refused: %s\n' "$mutant"
done
