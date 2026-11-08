#!/usr/bin/bash
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
awk '/^static void rproc_crash_handler_work\(/ {copy=1;found++} copy{print} copy&&/^}$/ {copy=0} END{if(found!=1||copy)exit 1}' \
 "$kernel/drivers/remoteproc/remoteproc_core.c" > "$work/rproc-crash-worker.h"
for compiler in gcc clang;do
 for sanitizer in 0 1;do
  flags=(-std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror)
  if [[ $sanitizer == 1 ]];then flags+=(-O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer);fi
  "$compiler" "${flags[@]}" -I"$work" "$kernel/native-profile/tests/rproc-crash-event.c" -o "$work/check"
  "$work/check"
  printf 'Actual remoteproc event passed:%s/sanitize%s; hardware failure/recovery remain separate.\n' "$compiler" "$sanitizer"
 done
done
