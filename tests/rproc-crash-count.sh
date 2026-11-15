#!/usr/bin/bash
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
awk '/^static ssize_t crash_count_show\(/ {emit=1;found++} emit{print} emit&&/^}$/ {emit=0} END{if(found!=1||emit)exit 1}' \
 "$kernel/drivers/remoteproc/remoteproc_sysfs.c" > "$work/rproc-crash-count-show.h"
for compiler in gcc clang; do
 for sanitizer in 0 1; do
  flags=(-std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror -Wno-unused-parameter)
  if [[ $sanitizer == 1 ]]; then flags+=(-O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer);fi
  "$compiler" "${flags[@]}" -I"$work" "$kernel/native-profile/tests/rproc-crash-count.c" -o "$work/check"
  "$work/check"
  printf 'Actual remoteproc count passed:%s/sanitize%s; no firmware/slot operation.\n' "$compiler" "$sanitizer"
 done
done
