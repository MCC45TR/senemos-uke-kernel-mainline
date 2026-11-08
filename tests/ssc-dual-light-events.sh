#!/usr/bin/env bash
# COPR-only reducer contract. Does not claim driver integration or physical parity.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cc=${CC:-gcc}
sanitize=${SANITIZE:-0}
[[ $sanitize == 0 || $sanitize == 1 ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/include/linux"
printf '#include <stdbool.h>\n#include <stdint.h>\ntypedef uint64_t u64;\ntypedef int64_t s64;\n' > "$work/include/linux/types.h"
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -UNDEBUG -fno-omit-frame-pointer)
[[ $sanitize == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
cp "$root/src/sensors/uke-ssc-dual-light.h" "$work/include/"
"$cc" "${flags[@]}" -I"$work/include" "$root/tests/ssc-dual-light-events.c" -o "$work/test"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/test"
if [[ $sanitize == 0 ]];then
 for mutation in always-both front-while-closed stale-epoch accept-duplicate keep-old-front;do
  awk -v m="$mutation" '
   m=="always-both" && /return pair->lid_known && pair->lid_closed \? 2U : 3U;/ {sub(/2U : 3U/,"3U : 3U");n++}
   m=="front-while-closed" && /^\tif \(required == 3U && / {sub(/required == 3U && /,"");n++}
   m=="stale-epoch" && /^\tif \(epoch != pair->epoch / {sub(/epoch != pair->epoch \|\| /,"");n++}
   m=="accept-duplicate" && /ticks <= pair->ticks\[side\]/ {sub(/ticks <=/,"ticks <");n++}
   m=="keep-old-front" && /pair->valid &= ~1U;/ {sub(/pair->valid &= ~1U;/,"pair->valid |= 0U;");n++}
   {print} END {if(n!=1)exit 1}
  ' "$root/src/sensors/uke-ssc-dual-light.h" > "$work/include/uke-ssc-dual-light.h"
  "$cc" "${flags[@]}" -I"$work/include" "$root/tests/ssc-dual-light-events.c" -o "$work/mutant"
  set +e
  (ulimit -c 0; "$work/mutant") > "$work/mutant.log" 2>&1
  status=$?
  set -e
  [[ $status == 134 ]]
  grep -Eq 'Assertion .* failed' "$work/mutant.log"
  printf 'Dual-light event assertion mutant refused:%s/%s.\n' "$cc" "$mutation"
 done
fi
printf 'Actual dual-light reducer passed:%s/sanitize%s; acquisition/input/IIO/DDC integration remains pending.\n' "$cc" "$sanitize"
