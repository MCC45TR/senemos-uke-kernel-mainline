#!/usr/bin/env bash
# COPR only; never request PCM, hardware or private firmware.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative source}")
before=$(realpath "${2:?Authenticated original7332 PCM source}")
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
cc=${CC:-gcc};sanitize=${SANITIZE:-0}
[[ $sanitize == 0 || $sanitize == 1 ]]
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
extract(){
 awk -v name="$2" '$0~"^static (int|void) "name"\\("{copy=1}copy{print}copy&&/^}/{found++;exit}END{if(found!=1)exit 1}' "$1"
}
source=$kernel/sound/soc/qcom/qdsp6/q6apm-dai.c
for fn in q6apm_pcm_period_work q6apm_pcm_period_elapsed q6apm_pcm_period_quiesce;do extract "$source" "$fn";done > "$work/native-pcm-period-helpers.inc"
extract "$source" event_handler > "$work/native-pcm-period-event.inc"
cp "$work/native-pcm-period-helpers.inc" "$work/good-helpers"
cp "$work/native-pcm-period-event.inc" "$work/good-event"
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -Wno-unused-parameter -pthread -fno-omit-frame-pointer)
[[ $sanitize == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
compile(){ "$cc" "${flags[@]}" -I "$work" "$owner/tests/pcm-period-worker.c" -o "$work/check"; }
compile
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 timeout -k 1s 20s "$work/check"
printf 'Actual PCM period workqueue native:%s/sanitize%s.\n' "$cc" "$sanitize"
refuse(){
 local status
 set +e
 timeout -k 1s 10s "$work/check" > "$work/refusal.txt" 2>&1
 status=$?
 set -e
 [[ $status == 134 ]]
 grep -Eqi 'assertion|assert' "$work/refusal.txt"
}
if [[ $sanitize == 0 ]];then
 extract "$before" event_handler > "$work/native-pcm-period-event.inc"
 compile;refuse
 printf 'Exact original PCM callback blocks ordered RX behind the held stream mutex:%s.\n' "$cc"
 for mutant in inline-notify no-close-gate no-work-drain;do
  cp "$work/good-helpers" "$work/native-pcm-period-helpers.inc"
  cp "$work/good-event" "$work/native-pcm-period-event.inc"
  case $mutant in
   inline-notify) sed -i 's/q6apm_pcm_period_elapsed(prtd);/snd_pcm_period_elapsed(prtd->substream);/g' "$work/native-pcm-period-event.inc";;
   no-close-gate) sed -i 's/if (!prtd->pcm_period_closed)/if (true)/' "$work/native-pcm-period-helpers.inc";;
   no-work-drain) sed -i 's/cancel_work_sync(\&prtd->pcm_period_work);/(void)prtd;/' "$work/native-pcm-period-helpers.inc";;
  esac
  compile;refuse
  printf 'Required PCM period lifetime mutant refused:%s/%s.\n' "$cc" "$mutant"
 done
fi
