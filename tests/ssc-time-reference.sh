#!/usr/bin/bash
# COPR only: actual diagnostic callback with controlled kernel boundaries.
set -Eeuo pipefail
[[ $# == 1 && ! -e /etc/senemos/kernel-update.conf ]]
driver=$(realpath "$1")
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
awk '/^#define SSC_SENSOR_COUNT /{print;n++}END{if(n!=1)exit 1}' "$driver" > "$work/count.inc"
for name in ssc_current ssc_time_reference_show;do
 awk -v name="$name" '$0~"^static .* "name"\\("{on=1}on{print}on&&/^}/{n++;exit}END{if(n!=1)exit 1}' "$driver" >> "$work/callbacks.inc"
done
grep -Fx 'static DEVICE_ATTR(ssc_time_reference, 0400, ssc_time_reference_show, NULL);' "$driver" >> "$work/callbacks.inc"
cp "$work/callbacks.inc" "$work/good.inc"
ulimit -c 0
for compiler in gcc clang;do
 for arch in enabled disabled;do
  for sanitizer in 0 1;do
   flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -Wno-unused-parameter)
   [[ $arch == disabled ]] || flags+=(-DCONFIG_ARM64=1 -DCONFIG_ARM_ARCH_TIMER=1)
   [[ $sanitizer == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
   "$compiler" "${flags[@]}" -I"$work" "$owner/tests/ssc-time-reference.c" -o "$work/check"
   "$work/check"
   printf 'SSC time-reference actual callback passed:%s/%s/sanitize%s\n' "$compiler" "$arch" "$sanitizer"
  done
 done
 for bad in stale permission admitted;do
  node - "$work/good.inc" "$work/callbacks.inc" "$bad" <<'JS'
const fs=require('fs'),[i,o,m]=process.argv.slice(2),pairs={stale:['if (connected) {','if (true) {'],permission:['ssc_time_reference, 0400,','ssc_time_reference, 0444,'],admitted:['schema=1 admitted=0','schema=1 admitted=1']},[old,next]=pairs[m],s=fs.readFileSync(i,'utf8');if(s.split(old).length!==2)throw Error('Time-reference mutant anchor');fs.writeFileSync(o,s.replace(old,()=>next));
JS
  "$compiler" -std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -Wno-unused-parameter -DCONFIG_ARM64=1 -DCONFIG_ARM_ARCH_TIMER=1 -I"$work" "$owner/tests/ssc-time-reference.c" -o "$work/bad"
  status=0;"$work/bad" > "$work/$bad.log" 2>&1 || status=$?
  [[ $status == 134 ]]
  printf 'SSC time-reference semantic regression refused:%s/%s/status%s\n' "$compiler" "$bad" "$status"
 done
 cp "$work/good.inc" "$work/callbacks.inc"
done
