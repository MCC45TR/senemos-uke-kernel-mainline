#!/usr/bin/bash
# COPR only: actual read-only startup snapshot and semantic refusal controls.
set -Eeuo pipefail
[[ $# == 0 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
mkdir "$work/linux"
printf '%s\n' '#pragma once' > "$work/linux/types.h"
cp "$owner"/src/camera/provider/camcc-sm7675-crm-{core,lut,startup}.h "$work/"
for compiler in gcc clang;do
 for mode in plain sanitized;do
  flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror)
  [[ $mode != sanitized ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" "${flags[@]}" -I"$work" "$owner/tests/fixtures/camcc-crm-startup-check.c" -o "$work/check"
  readelf -h "$work/check" | grep -F AArch64
  timeout --kill-after=2s 20s "$work/check"
 done
done
for mutant in changing-vote pending-status;do
 node - "$owner/src/camera/provider/camcc-sm7675-crm-startup.h" "$work/camcc-sm7675-crm-startup.h" "$mutant" <<'JS'
const fs=require('fs'),[src,out,kind]=process.argv.slice(2),s=fs.readFileSync(src,'utf8');
const a=kind==='changing-vote'?'if (pass && raw != result.words[client][state])':'if (raw)';
const b=kind==='changing-vote'?'if (false && pass && raw != result.words[client][state])':'if (raw && false)';
if(s.split(a).length!==(kind==='changing-vote'?2:3))throw Error('Exact startup mutation anchors');
fs.writeFileSync(out,s.replaceAll(a,b));
JS
 gcc -std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -I"$work" "$owner/tests/fixtures/camcc-crm-startup-check.c" -o "$work/mutant"
 status=0
 timeout --kill-after=2s 20s "$work/mutant" > "$work/mutant.log" 2>&1 || status=$?
 [[ $status == 134 ]]
 printf 'Startup semantic mutant refused: %s\n' "$mutant"
done
