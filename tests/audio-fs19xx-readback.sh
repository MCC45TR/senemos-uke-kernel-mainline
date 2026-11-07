#!/usr/bin/env bash
# Native compilation belongs in COPR; no audio, calibration or DMA is accessed.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
cc=${CC:-gcc}
sanitize=${SANITIZE:-0}
[[ $sanitize == 0 || $sanitize == 1 ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -fno-omit-frame-pointer)
[[ $sanitize == 0 ]] || flags+=(-fsanitize=address,undefined)
cp "$owner/src/audio/uke-fs19xx-readback.h" "$work/uke-fs19xx-readback.h"
sed '/^#include /d' "$owner/src/audio/uke-fs19xx-readback.c" > "$work/native-readback.inc"
"$cc" "${flags[@]}" -I "$work" "$owner/tests/audio-fs19xx-readback-backend.c" -o "$work/backend"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/backend"
"$cc" "${flags[@]}" -I "$work" "$owner/tests/audio-fs19xx-readback.c" -o "$work/parser"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/parser"
if [[ $sanitize == 0 ]];then
 cp "$work/uke-fs19xx-readback.h" "$work/original.h"
 for mutant in token identity inner-status boolean basic-ack padding reserved-byte;do
  awk -v mutant="$mutant" '
   mutant=="token" && /h->token != q->token/{sub(/h->token != q->token/, "false");changed++}
   mutant=="identity" && /uke_rb_word\(data \+ 4\) != q->instance/{sub(/uke_rb_word\(data \+ 4\) != q->instance/, "false");changed++}
   mutant=="inner-status" && /status = uke_rb_word\(data \+ 16\);/{sub(/uke_rb_word\(data \+ 16\)/, "0");changed++}
   mutant=="boolean" && /if \(status > 1\)/{sub(/status > 1/, "false");changed++}
   mutant=="basic-ack" && /if \(!status\)/{sub(/!status/, "false");changed++}
   mutant=="padding" && /\(bytes == 28 && uke_rb_word\(data \+ 24\)\)/{sub(/bytes == 28 && uke_rb_word\(data \+ 24\)/, "false");changed++}
   mutant=="reserved-byte" && /\(h->reserved & 0xff00U\)/{sub(/h->reserved & 0xff00U/, "h->reserved");changed++}
   {print} END {if(changed!=1)exit 1}
  ' "$work/original.h" > "$work/uke-fs19xx-readback.h"
  "$cc" "${flags[@]}" -I "$work" "$owner/tests/audio-fs19xx-readback.c" -o "$work/mutant"
  set +e
  (ulimit -c 0; "$work/mutant") > "$work/mutant.log" 2>&1
  result=$?
  set -e
  [[ $result == 134 ]]
  printf 'Detected readback assertion mutant: %s/%s.\n' "$cc" "$mutant"
 done
fi
printf 'Actual FS19xx readback parser/transport passed: %s/sanitize%s. No kernel ABI or physical limiting qualification.\n' "$cc" "$sanitize"
