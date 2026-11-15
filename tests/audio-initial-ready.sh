#!/usr/bin/env bash
# COPR only. Actual helper and actual control/shutdown publication callbacks.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared complete16 kernel}")
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
cc=${CC:-gcc};san=${SANITIZE:-0}
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -fno-omit-frame-pointer)
[[ $san == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
actual=$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
awk '/^static int fs19xx_control_put\(/ || /^void q6apm_fs19xx_shutdown\(/ {copy=1} copy{print} copy&&/^}/ {copy=0;found++} END {if(found!=2)exit 1}' "$actual" > "$work/native-ready-publish.inc"
cp "$owner/src/audio/uke-fs19xx-initial-ready.h" "$work/uke-fs19xx-initial-ready.h"
compile(){ "$cc" "${flags[@]}" -I "$work" "$owner/tests/audio-initial-ready.c" -o "$work/check"; }
compile
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/check"
printf 'Actual initial-ready wait passed: %s/sanitize%s.\n' "$cc" "$san"
if [[ $san == 0 ]];then
 for mutation in missing-notify held-mutex rearmed-deadline;do
  cp "$owner/src/audio/uke-fs19xx-initial-ready.h" "$work/uke-fs19xx-initial-ready.h"
  awk '/^static int fs19xx_control_put\(/ || /^void q6apm_fs19xx_shutdown\(/ {copy=1} copy{print} copy&&/^}/ {copy=0;found++} END {if(found!=2)exit 1}' "$actual" > "$work/native-ready-publish.inc"
  case $mutation in
   missing-notify) sed '/wake_up_all(&fs->ready_wait);/d' "$work/native-ready-publish.inc" > "$work/changed";mv "$work/changed" "$work/native-ready-publish.inc";;
   rearmed-deadline) sed 's/if (!fs->ready_wait_started)/if (true)/' "$owner/src/audio/uke-fs19xx-initial-ready.h" > "$work/uke-fs19xx-initial-ready.h";;
   held-mutex) awk '/remaining = fs->ready_deadline - jiffies;/ {remove=1} remove&&/mutex_unlock/ {remove=0;next} {print}' "$owner/src/audio/uke-fs19xx-initial-ready.h" > "$work/uke-fs19xx-initial-ready.h";;
  esac
  compile
  set +e
  timeout -k 1s 10s "$work/check" > "$work/control.log" 2>&1
  result=$?
  set -e
  [[ $result == 134 ]] || { cat "$work/control.log" >&2;exit 1; }
  printf 'Actual initial-ready mutant refused: %s/%s/status134.\n' "$cc" "$mutation"
 done
fi
