#!/usr/bin/env bash
# COPR only: real libfdt, synthetic board graph, no device access.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=${1:?Prepared cumulative kernel}
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cc=${CC:-gcc}
sanitize=${SANITIZE:-0}
[[ $sanitize == 0 || $sanitize == 1 ]]
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -fno-omit-frame-pointer)
[[ $sanitize == 0 ]] || flags+=(-fsanitize=address,undefined)
"$cc" "${flags[@]}" -I "$kernel/arch/arm64/kernel" "$owner/tests/audio-config-dt.c" -lfdt -o "$work/dt"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/dt"
printf 'Actual OOB DT passed: %s/sanitize%s.\n' "$cc" "$sanitize"
