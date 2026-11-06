#!/usr/bin/env bash
# COPR only: compile actual source with independent transport/DMA providers.
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
backend=$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.c
memory=$kernel/drivers/soc/qcom/uke-audio-config-memory.c
core=$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-oob.h
sed '/^#include /d' "$backend" > "$work/native-backend.inc"
awk '
 /^static DEFINE_MUTEX\(uke_config_lock\)/{globals=1}
 globals && /^static bool uke_config_iommus/{globals=0}
 globals{print}
 /^int uke_audio_config_acquire\(/ || /^void uke_audio_config_release\(/{function_body=1}
 function_body{print}
 function_body && /^}/{function_body=0;count++}
 END{if(count!=2)exit 1}
' "$memory" > "$work/native-memory.inc"
for fixture in audio-fs19xx-oob-backend audio-config-memory;do
 "$cc" "${flags[@]}" -I "$work" -I "${core%/*}" "$owner/tests/$fixture.c" -o "$work/$fixture"
 ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/$fixture"
done
printf 'Actual OOB backend and permanent memory lease passed: %s/sanitize%s.\n' "$cc" "$sanitize"
if [[ $sanitize == 0 ]];then
 cp "$work/native-backend.inc" "$work/original-backend.inc"
 for mutant in token send-ambiguity retain-client read-barrier;do
  awk -v mutant="$mutant" '
   mutant=="token" && /header->token != client->token/{sub(/header->token != client->token/,"false");changed++}
   mutant=="send-ambiguity" && /reply.sent = true;/{sub("true","false");changed++}
   mutant=="retain-client" && /if \(client->retained\)/{sub(/client->retained/,"false");changed++}
   mutant=="read-barrier" && /^\t\tdma_rmb\(\);/{print "\t\t(void)0;";changed++;next}
   {print} END {if(changed!=1)exit 1}
  ' "$work/original-backend.inc" > "$work/native-backend.inc"
  "$cc" "${flags[@]}" -I "$work" -I "${core%/*}" "$owner/tests/audio-fs19xx-oob-backend.c" -o "$work/mutant"
  set +e
  (ulimit -c 0; "$work/mutant") > "$work/$mutant.log" 2>&1
  result=$?
  set -e
  [[ $result == 134 ]]
  printf 'Actual backend assertion mutant detected: %s/%s.\n' "$cc" "$mutant"
 done
fi
