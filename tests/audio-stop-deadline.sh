#!/usr/bin/env bash
# COPR-only actual callback execution. This is not full kernel admission.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Reconstructed exact7331 codec source}")
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
cc=${CC:-gcc};san=${SANITIZE:-0};ticks=${TICKS:-1000}
[[ $san == 0 || $san == 1 ]]
[[ $ticks == 100 || $ticks == 250 || $ticks == 1000 ]]
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -Wno-unused-parameter -fno-omit-frame-pointer "-DUKE_TEST_HZ=$ticks")
[[ ${FREEZABLE:-0} == 0 || ${FREEZABLE:-0} == 1 ]]
[[ ${FREEZABLE:-0} == 0 ]] || flags+=(-DUKE_TEST_FREEZABLE_QUEUE=1)
[[ $san == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
codec=$kernel/sound/soc/codecs/fs19xx.c
extract(){
 local file=$1 name=$2
 awk -v name="$name" '$0 ~ "^(static )?(int|void|bool) "name"\\(" {copy=1} copy{print} copy&&/^}/ {found++;exit} END{if(found!=1)exit 1}' "$file"
}
prepare(){
 local source=$1
 grep -E '^#define FS19XX_' "$source" > "$work/native-stop-definitions.inc"
 printf '#define APM_CMD_GRAPH_STOP 0x01001003\n' >> "$work/native-stop-definitions.inc"
 for function in fs19xx_read_stable fs19xx_chip_stop fs19xx_check_health fs19xx_unmute_output fs19xx_unmute_work fs19xx_power_on fs19xx_power_off;do extract "$source" "$function";done > "$work/native-stop-codec.inc"
 extract "$source" fs19xx_protection_event > "$work/native-stop-event.inc"
}
for function in fs19xx_gate q6apm_fs19xx_graph q6apm_fs19xx_stopping q6apm_fs19xx_stopped;do extract "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c" "$function";done > "$work/native-stop-runtime.inc"
cp "$owner/tests/fixtures/audio-stop7331-query.inc" "$work/native-idle-query.inc"
cp "$owner/tests/fixtures/audio-stop7331-graph.inc" "$work/native-stop-graph.inc"
cp "$kernel/sound/soc/codecs/uke-fs19xx-muted-stop.h" "$work/uke-fs19xx-muted-stop.h"
cp "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-safety.h" "$work/uke-fs19xx-safety.h"
compile(){ "$cc" "${flags[@]}" -I "$work" "$owner/tests/audio-stop-transition.c" -o "$work/check"; }
prepare "$codec"
compile
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/check"
printf 'Actual bounded muted STOP native: %s/sanitize%s/HZ%s.\n' "$cc" "$san" "$ticks"
refuse(){
 local result
 set +e
 timeout -k 1s 10s "$work/check" > "$work/refusal.log" 2>&1
 result=$?
 set -e
 [[ $result == 134 ]]
 grep -Eq 'Assertion|assertion' "$work/refusal.log"
}
if [[ $san == 0 && $ticks == 250 ]];then
 cp "$work/native-stop-codec.inc" "$work/good-codec.inc"
 cp "$work/uke-fs19xx-muted-stop.h" "$work/good-muted.h"
 cp "$work/native-stop-runtime.inc" "$work/good-runtime.inc"
 prepare "$kernel/codec-before-deadline.c"
 cp "$kernel/muted-before-deadline.h" "$work/uke-fs19xx-muted-stop.h"
 compile;refuse
 printf 'Exact original7331 worker refuses the complete five-second muted drain.\n'
 for mutant in unbounded-deadline premature-deadline lost-fault early-mode-one;do
  cp "$work/good-runtime.inc" "$work/native-stop-runtime.inc"
  cp "$work/good-codec.inc" "$work/native-stop-codec.inc"
  cp "$work/good-muted.h" "$work/uke-fs19xx-muted-stop.h"
  case $mutant in
   early-mode-one) cp "$owner/tests/fixtures/audio-stop7331-runtime.inc" "$work/native-stop-runtime.inc";;
   unbounded-deadline) sed -i 's/time_before(now, fs19xx->stop_deadline)/(time_before(now, fs19xx->stop_deadline) || true)/' "$work/native-stop-codec.inc";;
   premature-deadline) sed -i 's/msecs_to_jiffies(FS19XX_STOP_DRAIN_MS)/msecs_to_jiffies(2000)/g' "$work/uke-fs19xx-muted-stop.h";;
   lost-fault) sed -i 's/fs19xx->require_protection \&\& q6apm_fs19xx_configured()/fs19xx->require_protection/' "$work/native-stop-codec.inc";;
  esac
  compile;refuse
  printf 'Required muted STOP mutant refused: %s/%s.\n' "$cc" "$mutant"
 done
fi
