#!/usr/bin/bash
# Native COPR only. Exercises the actual route helper; no live audio command.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
mkdir -p "$work/sound"
printf '/* Controlled fixture declarations are provided by the test TU. */\n' > "$work/uke-fs19xx-runtime.h"
cp "$work/uke-fs19xx-runtime.h" "$work/sound/uke-fs19xx-guard.h"
for compiler in gcc clang; do
 for sanitize in 0 1; do
  flags=(-std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror)
  if [[ $sanitize == 1 ]];then flags+=(-O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer);fi
  "$compiler" "${flags[@]}" "$owner/tests/speaker-quad-route.c" -o "$work/check"
  "$work/check"
  "$compiler" "${flags[@]}" -I"$work" -pthread "$owner/tests/speaker-quad-lpass.c" -o "$work/lpass"
  "$work/lpass"
  printf 'Actual quad route passed:%s/sanitize%s; firmware and physical acceptance remain separate.\n' "$compiler" "$sanitize"
 done
done
