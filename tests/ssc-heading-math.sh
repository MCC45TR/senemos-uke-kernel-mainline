#!/usr/bin/bash
# COPR only; the device never compiles or installs this fixture.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/include/linux"
cp "$owner/src/sensors/uke-ssc-heading.h" "$work/uke-ssc-heading.h"
cp "$work/uke-ssc-heading.h" "$work/good.h"
ulimit -c 0
printf '#include <stdint.h>\ntypedef int64_t s64;typedef int32_t s32;\n' > "$work/include/linux/types.h"
printf '#include <asm-generic/errno.h>\n' > "$work/include/linux/errno.h"
for compiler in gcc clang;do
 for mode in 0 1;do
  flags=(-std=gnu11 -O2 -Wall -Wextra -Werror -UNDEBUG)
  [[ $mode == 0 ]] || flags+=(-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" "${flags[@]}" -I"$work/include" -I"$work" "$owner/tests/ssc-heading-math.c" -lm -o "$work/check"
  "$work/check"
  printf 'Integer heading callbacks passed:%s/sanitize%s; no hardware.\n' "$compiler" "$mode"
 done
 for bad in direction norm;do
  cp "$work/good.h" "$work/uke-ssc-heading.h"
  if [[ $bad == direction ]];then sed -i 's/q\[0\] \* q\[1\] - q\[2\] \* q\[3\]/q[0] * q[1] + q[2] * q[3]/' "$work/uke-ssc-heading.h";else sed -i 's/norm < 980000000000LL || norm > 1020000000000LL/norm < 0/' "$work/uke-ssc-heading.h";fi
  ! cmp -s "$work/good.h" "$work/uke-ssc-heading.h"
  "$compiler" -std=gnu11 -O2 -Wall -Wextra -Werror -UNDEBUG -I"$work/include" -I"$work" "$owner/tests/ssc-heading-math.c" -lm -o "$work/bad"
  result=0;"$work/bad" > "$work/bad.log" 2>&1 || result=$?
  [[ $result == 134 ]]
  grep -F Assertion "$work/bad.log"
  printf 'Integer heading regression refused:%s/%s/status134.\n' "$compiler" "$bad"
 done
 cp "$work/good.h" "$work/uke-ssc-heading.h"
done
