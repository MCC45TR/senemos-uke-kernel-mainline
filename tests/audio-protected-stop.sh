#!/usr/bin/env bash
# COPR only. Execute actual cumulative runtime/codec/STOP with independent peers.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared complete17 kernel}")
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
cc=${CC:-gcc};san=${SANITIZE:-0}
[[ $san == 0 || $san == 1 ]]
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -Wno-unused-parameter -fno-omit-frame-pointer)
[[ $san == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
codec=$kernel/sound/soc/codecs/fs19xx.c
runtime=$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
extract(){
 local file=$1 function=$2
 awk -v name="$function" '$0 ~ "^(static )?(int|void|bool) "name"\\(" {copy=1} copy{print} copy&&/^}/ {found++;exit} END{if(found!=1)exit 1}' "$file"
}
grep -E '^#define FS19XX_(REG_|DACCTRL_|PWRCTRL_|SYSCTRL_|STATUS_|TSCTRL_|VOL_|LOCK_POLL_|HEALTH_POLL_)' "$codec" > "$work/native-stop-definitions.inc"
grep -E '^#define APM_CMD_GRAPH_STOP[[:space:]]' "$kernel/sound/soc/qcom/qdsp6/audioreach.h" >> "$work/native-stop-definitions.inc"
for function in fs19xx_read_stable fs19xx_chip_stop fs19xx_check_health fs19xx_unmute_output fs19xx_unmute_work fs19xx_power_off;do extract "$codec" "$function";done > "$work/native-stop-codec.inc"
extract "$codec" fs19xx_protection_event > "$work/native-stop-event.inc"
for function in fs19xx_gate q6apm_fs19xx_graph q6apm_fs19xx_stopping q6apm_fs19xx_stopped;do extract "$runtime" "$function";done > "$work/native-stop-runtime.inc"
extract "$kernel/sound/soc/qcom/qdsp6/q6apm.c" q6apm_graph_stop > "$work/native-stop-graph.inc"
cp "$owner/src/audio/uke-fs19xx-muted-stop.h" "$work/uke-fs19xx-muted-stop.h"
cp "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-safety.h" "$work/uke-fs19xx-safety.h"
compile(){ "$cc" "${flags[@]}" -I "$work" "$owner/tests/audio-protected-stop.c" -o "$work/check"; }
compile
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/check"
printf 'Actual muted protected STOP passed: %s/sanitize%s.\n' "$cc" "$san"
assert_control(){
 local result
 set +e
 timeout -k 1s 10s "$work/check" > "$work/control.log" 2>&1
 result=$?
 set -e
 [[ $result == 134 ]] || { cat "$work/control.log" >&2;exit 1; }
 grep -Eq 'Assertion|assertion' "$work/control.log"
}
if [[ $san == 0 ]];then
 cp "$work/native-stop-graph.inc" "$work/graph-good.inc"
 cp "$work/native-stop-runtime.inc" "$work/runtime-good.inc"
 cp "$work/native-stop-codec.inc" "$work/codec-good.inc"
 cp "$kernel/native-generated/graph-stop-before-protected-stop.c" "$work/native-stop-graph.inc"
 compile;assert_control
 printf 'Original pre-STOP amplifier shutdown reproduces VI drain refusal: %s/status134.\n' "$cc"
 for mutant in no-mute-notify premature-poweroff ignored-readback unbounded-drain;do
  cp "$work/graph-good.inc" "$work/native-stop-graph.inc"
  cp "$work/runtime-good.inc" "$work/native-stop-runtime.inc"
  cp "$work/codec-good.inc" "$work/native-stop-codec.inc"
  cp "$owner/src/audio/uke-fs19xx-muted-stop.h" "$work/uke-fs19xx-muted-stop.h"
  case $mutant in
   no-mute-notify) sed 's/ret = notifier_to_errno(blocking_notifier_call_chain(\&fs19xx_listeners, mode, NULL));/if (mode != 1) ret = notifier_to_errno(blocking_notifier_call_chain(\&fs19xx_listeners, mode, NULL));/' "$work/runtime-good.inc" > "$work/native-stop-runtime.inc";;
   premature-poweroff) sed '/mute_ret = q6apm_fs19xx_stopping(graph);/a\	q6apm_fs19xx_stopped(graph, false);' "$work/graph-good.inc" > "$work/native-stop-graph.inc";;
   ignored-readback) sed 's/if (!(value \& FS19XX_DACCTRL_MUTE_BIT))/if (false)/' "$owner/src/audio/uke-fs19xx-muted-stop.h" > "$work/uke-fs19xx-muted-stop.h";;
   unbounded-drain) sed 's/++fs19xx->pll_polls < FS19XX_LOCK_POLL_COUNT/true/g' "$work/codec-good.inc" > "$work/native-stop-codec.inc";;
  esac
  compile;assert_control
  printf 'Actual muted protected STOP mutant refused: %s/%s/status134.\n' "$cc" "$mutant"
 done
fi
