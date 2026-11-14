#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR only: actual passive adapter and independent, hash-pinned OEM topology.
set -Eeuo pipefail
[[ $# == 1 && ! -e /etc/senemos/kernel-update.conf ]]
project=$(cd -- "$(dirname -- "$0")/.." && pwd)
oem=$(realpath "$1")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
printf '%s  %s\n' 1a76c029c51710af6684a6d4f87e1486c125cd25badfce7b80ba642d820affe6 "$oem" | sha256sum -c --strict --quiet -
node "$project/tests/camcc-crm-passive-catalog.mjs" "$oem" "$project/src/camera/provider/camcc-sm7675-crm-passive.h" "$work/passive-catalog.h"
cp "$project/src/camera/provider/camcc-sm7675-crm-passive.h" "$work/passive.h"
for compiler in gcc clang;do
 for sanitizer in plain address-undefined;do
  flags=()
  if [[ $sanitizer == address-undefined ]];then
   flags=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  fi
  "$compiler" -std=gnu11 -O1 -g -Wall -Wextra -Werror -I"$work" "${flags[@]}" \
   "$project/tests/fixtures/camcc-crm-passive-check.c" -o "$work/check"
  ASAN_OPTIONS=detect_leaks=1:halt_on_error=1 "$work/check"
 done
done
ulimit -c 0
for mutation in pll-rounding branch-rate-propagation native-write-ops early-pm-put;do
 cp "$project/src/camera/provider/camcc-sm7675-crm-passive.h" "$work/passive.h"
 node - "$work/passive.h" "$mutation" <<'JS'
const fs=require('fs'),[p,m]=process.argv.slice(2),s=fs.readFileSync(p,'utf8');
const edits={
 'pll-rounding':['((value + 999) / 1000) * 1000','(value / 1000) * 1000'],
 'branch-rate-propagation':['if (cam_cc_crm_passive[i].kind != CAM_CC_CRM_BRANCH)','if (true)'],
 'native-write-ops':['clock->ops = (struct clk_ops) { .recalc_rate = cam_cc_crm_passive_recalc };','clock->ops.recalc_rate = cam_cc_crm_passive_recalc;'],
 'early-pm-put':['ret = cam_cc_crm_passive_snapshot(i);\n\tif (ret)\n\t\t/* An uncertain powered read retains this reference in quarantine. */\n\t\treturn cam_cc_clock_fail(ret, 0);\n\tpm_runtime_put_noidle(cam_cc_power.dev);','pm_runtime_put_noidle(cam_cc_power.dev);\n\tret = cam_cc_crm_passive_snapshot(i);\n\tif (ret)\n\t\treturn cam_cc_clock_fail(ret, 0);']
};
const [a,b]=edits[m];if(s.split(a).length!==2)throw Error('Passive mutation anchor');fs.writeFileSync(p,s.replace(a,b));
JS
 gcc -std=gnu11 -O1 -g -Wall -Wextra -Werror -I"$work" \
  "$project/tests/fixtures/camcc-crm-passive-check.c" -o "$work/mutant"
 set +e
 "$work/mutant" > "$work/$mutation.log" 2>&1
 status=$?
 set -e
 [[ $status == 134 ]]
 grep -Fq Assertion "$work/$mutation.log"
 printf 'Actual CRM passive semantic mutant refused134: %s\n' "$mutation"
done
