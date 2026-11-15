#!/usr/bin/bash
# Actual callback test; compilation is allowed only on COPR.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
source=${1:?Prepared actual fastrpc.c or callback control}
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
[[ $(grep -c '^static int fastrpc_cb_probe(' "$source") == 1 ]]
awk '/^static int fastrpc_cb_probe\(/{p=1}p{print}p&&/^}/{exit}' "$source" > "$work/callback.h"
flags=(-std=gnu11 -O2 -g -Wall -Wextra -Werror -UNDEBUG)
[[ ${SANITIZE:-0} == 0 ]] || flags+=(-O1 -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
"${CC:-cc}" "${flags[@]}" -I "$work" "$owner/tests/fixtures/fastrpc-cb-dma.c" -o "$work/check"
"$work/check"
