#!/usr/bin/env bash
# COPR only: actual backend, actual kernel GPR wire declarations, independent peer.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared complete14 kernel}")
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
cc=${CC:-gcc};san=${SANITIZE:-0}
[[ $san == 0 || $san == 1 ]]
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -fno-omit-frame-pointer)
[[ $san == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
actual=$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.c
core=$kernel/sound/soc/qcom/qdsp6
awk '
 /^struct gpr_hdr \{/ {copy=1}
 /^struct gpr_resp_pkt \{/ {last=1}
 copy{print}
 copy&&last&&/^};$/ {done=1;exit}
 END {if(!done)exit 1}
' "$kernel/include/linux/soc/qcom/apr.h" > "$work/native-gpr-wire.inc"
sed '/^#include /d' "$actual" > "$work/native-backend.inc"
compile(){ "$cc" "${flags[@]}" -I "$work" -I "$core" "$owner/tests/audio-gpr-client-data.c" -o "$work/check"; }
assert_control(){ local result;if "$work/check" > "$work/control.log" 2>&1;then echo 'Required assertion absent' >&2;exit 1;else result=$?;fi;[[ $result == 134 ]];grep -Fq 'q6apm_fs19xx_oob_send' "$work/control.log"; }
compile
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/check"
printf 'Actual GPR client-data backend passed: %s/sanitize%s.\n' "$cc" "$san"
if [[ $san == 0 ]];then
 sed '/^#include /d' "$kernel/native-generated/backend-before-client-data.c" > "$work/native-backend.inc"
 compile;assert_control
 printf 'Original backend rejects documented GPR client data: %s/status134.\n' "$cc"
 for mutation in no-reserved only-one-client;do
  expression='s/(header->reserved \& 0xfff0U)/false/'
  [[ $mutation != only-one-client ]] || expression='s/0xfff0U/0xfffeU/'
  sed '/^#include /d' "$actual" | sed "$expression" > "$work/native-backend.inc"
  if cmp -s "$work/native-backend.inc" <(sed '/^#include /d' "$actual");then exit 1;fi
  compile;assert_control
  printf 'Actual GPR client-data mutant detected: %s/%s/status134.\n' "$cc" "$mutation"
 done
fi
