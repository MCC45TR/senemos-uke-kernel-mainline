#!/usr/bin/env bash
# COPR only; production transport callbacks, synthetic non-private payloads.
set -Eeuo pipefail
ulimit -c 0
kernel=$(realpath "${1:?Prepared kernel source}")
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
[[ ! -e /sys/firmware/devicetree/base/model ]]
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
extract(){ awk -v name="$1" '$0 ~ "^(static )?(int|void) "name"\\("{p=1}p{print}p&&/^}/{exit}' "$2"; }
apr=$kernel/drivers/soc/qcom/apr.c
audio=$kernel/sound/soc/qcom/qdsp6/audioreach.c
awk '/^struct gpr_hdr \{/{p=1}p{print}p&&/^} __packed;/{exit}' "$kernel/include/linux/soc/qcom/apr.h" > "$work/actual-gpr-header.h"
extract __qcom_glink_send "$kernel/drivers/rpmsg/qcom_glink_native.c" > "$work/actual-glink-send.h"
for name in pkt_router_send_svc_pkt gpr_send_pkt gpr_send_port_pkt gpr_send_pkt_wait gpr_quiesce_service;do
 extract "$name" "$apr" > "$work/$name.h";test -s "$work/$name.h"
 cat "$work/$name.h" >> "$work/actual-apr-send.h"
done
extract audioreach_send_cmd_sync "$audio" > "$work/actual-audioreach-sync.h"
for name in actual-gpr-header actual-glink-send actual-audioreach-sync;do test -s "$work/$name.h";done
compiler=${CC:-gcc}
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -Wno-unused-parameter)
[[ ${SANITIZE:-0} != 1 ]] || flags+=(-fsanitize=address,undefined -fno-omit-frame-pointer)
"$compiler" "${flags[@]}" -I "$work" "$owner/tests/audio-static-intent.c" -o "$work/check"
"$work/check"
if [[ ${SANITIZE:-0} == 0 ]];then
 cp "$work/actual-audioreach-sync.h" "$work/fixed-sync.h"
 extract audioreach_send_cmd_sync "$owner/tests/fixtures/audio-static-intent-original.h" > "$work/actual-audioreach-sync.h"
 "$compiler" "${flags[@]}" -I "$work" "$owner/tests/audio-static-intent.c" -o "$work/original"
 set +e
 "$work/original" > "$work/original.log" 2>&1
 result=$?
 set -e
 [[ $result == 134 ]]
 grep -Fx '5416-byte static configuration failed: -16' "$work/original.log"
 cp "$work/fixed-sync.h" "$work/actual-audioreach-sync.h"
 printf 'Original AudioReach static5416-byte EBUSY reproduced with actual GLINK: %s/status134.\n' "$compiler"
 cp "$work/actual-apr-send.h" "$work/fixed-apr.h"
 for mutant in lifetime-lock quiesce-check;do
  awk -v mutant="$mutant" '
   /^int gpr_send_pkt_wait\(/{inside=1}
   inside && mutant=="lifetime-lock" && /mutex_(lock|unlock)\(&pr->callback_lock\)/{changed++;next}
   inside && mutant=="quiesce-check" {if(sub(/ && READ_ONCE\(svc->callback\)/,""))changed++}
   {print}
   inside && /^}/{inside=0}
   END{if(changed!=(mutant=="lifetime-lock"?2:1))exit 1}
  ' "$work/fixed-apr.h" > "$work/actual-apr-send.h"
  "$compiler" "${flags[@]}" -I "$work" "$owner/tests/audio-static-intent.c" -o "$work/mutant"
  set +e
  "$work/mutant" > "$work/$mutant.log" 2>&1
  result=$?
  set -e
  [[ $result == 134 ]]
  printf 'Actual static GPR assertion mutant detected: %s/%s/status134.\n' "$compiler" "$mutant"
 done
 cp "$work/fixed-apr.h" "$work/actual-apr-send.h"
fi
printf 'Static GPR intent: actual callbacks, lifecycle/refusal/timeout/byte-preservation and nonblocking controls passed: %s/sanitize%s.\n' "$compiler" "${SANITIZE:-0}"
