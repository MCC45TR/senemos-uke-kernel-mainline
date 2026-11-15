#!/usr/bin/env bash
# COPR only; executes the actual prospective OOB core with an independent peer.
set -Eeuo pipefail
kernel=${1:?Prepared kernel}
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cc=${CC:-gcc}
sanitize=${SANITIZE:-0}
[[ $sanitize == 0 || $sanitize == 1 ]]
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -fno-omit-frame-pointer)
if [[ $sanitize == 1 ]];then flags+=(-fsanitize=address,undefined);fi
header=$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-oob.h
test -s "$header"
"$cc" "${flags[@]}" -I "${header%/*}" "$owner/tests/audio-fs19xx-oob.c" -o "$work/peer"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/peer"
printf 'Protected OOB core independent peer passed: %s/sanitize%s.\n' "$cc" "$sanitize"
if [[ $sanitize == 0 ]];then
 for mutant in config-timeout unmap-error module-error page-alignment;do
  mkdir "$work/$mutant"
  awk -v mutant="$mutant" '
   mutant=="config-timeout" && /if \(response.sent && !response.complete\)/ {$0="\tif (false)";changed++}
   mutant=="unmap-error" && /if \(!response.sent \|\| !response.complete \|\| response.error\)/ {$0="\tif (false)";changed++}
   mutant=="module-error" && /else if \(uke_oob_get32\(b->data \+ 12\)\)/ {$0="\t\telse if (false)";changed++}
   mutant=="page-alignment" && /b->address_low & 4095/ {sub("4095", "31");changed++}
   {print} END {if(changed!=1)exit 1}
  ' "$header" > "$work/$mutant/uke-fs19xx-oob.h"
  "$cc" "${flags[@]}" -I "$work/$mutant" "$owner/tests/audio-fs19xx-oob.c" -o "$work/$mutant/peer"
  set +e
  (ulimit -c 0; "$work/$mutant/peer") > "$work/$mutant/result" 2>&1
  result=$?
  set -e
  [[ $result == 134 ]]
  printf 'Protected OOB assertion mutant detected: %s/%s/status134.\n' "$cc" "$mutant"
 done
fi
