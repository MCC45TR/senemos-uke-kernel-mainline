#!/usr/bin/bash
# COPR only: extend the original actual transport fixture with owner composition.
set -Eeuo pipefail
[[ $# == 1 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(realpath "$1")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
mkdir -p "$work/linux"
for header in completion compiler device interrupt io jiffies mutex spinlock errno types;do
 printf '%s\n' '#pragma once' > "$work/linux/$header.h"
done
for header in core transport pm owner;do
 cp "$owner/src/camera/provider/camcc-sm7675-crm-$header.h" "$work/"
done
cp "$work/camcc-sm7675-crm-transport.h" "$work/crm-transport.h"
cp "$owner/tests/fixtures/camcc-crm-owner-model.h" "$work/"
node - "$owner/tests/fixtures/camera-crm-transport-check.c" "$work/check.c" <<'JS'
const fs=require('fs'),[src,out]=process.argv.slice(2),s=fs.readFileSync(src,'utf8');
const needle='int main(void)\n{';
if(s.split(needle).length!==2)throw Error('Exact original transport main required');
fs.writeFileSync(out,s.replace(needle,'#include "camcc-crm-owner-model.h"\n'+needle+'\n    owner_checks();'));
JS
for compiler in gcc clang;do
 for mode in plain sanitized;do
  flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror)
  [[ $mode != sanitized ]] || flags+=("-fsanitize=address,undefined" -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" "${flags[@]}" -I"$work" "$work/check.c" -o "$work/check"
  readelf -h "$work/check" | grep -F AArch64
  timeout --kill-after=2s 20s "$work/check"
 done
done
cp "$work/camcc-sm7675-crm-owner.h" "$work/owner-original.h"
for mutant in drop-fault-owner drop-irq-mask;do
 node - "$work/owner-original.h" "$work/camcc-sm7675-crm-owner.h" "$mutant" <<'JS'
const fs=require('fs'),[src,out,kind]=process.argv.slice(2),s=fs.readFileSync(src,'utf8');
const needle=kind==='drop-fault-owner'?'cam_cc_power.transport_context = transport;':'cam_cc_crm_transport_fail(transport, error);';
if(s.split(needle).length!==2)throw Error('Exact owner mutation anchor');
fs.writeFileSync(out,s.replace(needle,'(void)error;'));
JS
 gcc -std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -I"$work" "$work/check.c" -o "$work/mutant"
 status=0
 timeout --kill-after=2s 20s "$work/mutant" > "$work/mutant.log" 2>&1 || status=$?
 [[ $status == 134 ]]
 printf 'Owner semantic mutant refused: %s\n' "$mutant"
done
