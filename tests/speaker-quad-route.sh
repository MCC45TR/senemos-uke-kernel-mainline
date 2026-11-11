#!/usr/bin/bash
# Native COPR only. Exercises the actual route helper; no live audio command.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
kernel=$(realpath "${1:-$owner/..}")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
mkdir -p "$work/sound"
awk '/^#define PCM_CHANNEL_(FL|FR|FC|LS|RS|LFE|LB|RB)[[:space:]]/ {print;n++} END{if(n!=8)exit 1}' \
 "$kernel/sound/soc/qcom/qdsp6/q6apm.h" > "$work/actual-q6apm-channel-ids.h"
awk '/^void audioreach_set_default_channel_mapping\(/ {emit=1} emit{print} emit&&/^}/{exit}' \
 "$kernel/sound/soc/qcom/qdsp6/audioreach.c" > "$work/actual-audioreach-map.inc"
test -s "$work/actual-audioreach-map.inc"
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
  "$compiler" "${flags[@]}" -I"$work" -pthread "$owner/tests/speaker-quad-card.c" -o "$work/card"
  "$work/card"
  "$compiler" "${flags[@]}" -I"$work" "$owner/tests/speaker-quad-wire.c" -o "$work/wire"
  "$work/wire"
  printf 'Actual quad route passed:%s/sanitize%s; firmware and physical acceptance remain separate.\n' "$compiler" "$sanitize"
 done
done
