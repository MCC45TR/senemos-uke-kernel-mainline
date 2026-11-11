#!/usr/bin/bash
# COPR-only. Unpublished integration fixture; never compile on the tablet.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
profile=$(cd -- "$(dirname -- "$0")/.." && pwd)
driver=${1:?Actual endpoint postimage}
api=${2:?Pinned Linux include/linux/iio/types.h}
[[ $(git hash-object "$api") == d8944c9e5e906ae663c36934c82489847047a082 ]]
cc=${CC:-gcc}
sanitize=${SANITIZE:-0}
[[ $sanitize == 0 || $sanitize == 1 ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/include/linux"
cat > "$work/include/linux/types.h" <<'TYPES'
#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;
typedef uint16_t __le16;
typedef uint32_t __le32;
typedef uint64_t __le64;
TYPES
cp "$profile/tests/ssc-native-host.h" "$work/"
cp "$profile/tests/ssc-dual-light-endpoint-host.h" "$work/endpoint-host.h"
{
 printf '#include "endpoint-host.h"\n#include "uke-ssc-protocol.h"\n#include "uke-ssc-dual-light.h"\n'
 awk '/^#define SSC_SERVICE /{emit=1} /^struct ssc_qmi_request /{exit} emit{print}' "$driver"
 for name in ssc_current ssc_schedule_locked ssc_dual_reset_locked ssc_invalidate_locked ssc_close_client ssc_publish_locked \
  ssc_stream_wanted ssc_stream_user_valid ssc_stream_get ssc_stream_put ssc_buffer_disable ssc_dual_feed_locked \
  ssc_dual_reconcile ssc_dual_read_raw ssc_dual_buffer_enable ssc_dual_buffer_disable \
  ssc_dual_lid_locked ssc_dual_lid_event ssc_dual_lid_start ssc_dual_lid_match \
  ssc_dual_lid_connect ssc_dual_lid_disconnect ssc_suspend ssc_resume ssc_shutdown; do
  awk -v name="$name" '
   $0 ~ "^static .*([[:space:]]|[*])" name "\\(" && $0 !~ /;/ {emit=1;found=1}
   emit {print} emit && /^}/ {exit}
   END {if(!found)exit 1}
  ' "$driver"
 done
 cat "$profile/tests/ssc-dual-light-endpoint.c"
} > "$work/actual.c"
flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -Wno-unused-function -fno-omit-frame-pointer)
[[ $sanitize == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
"$cc" "${flags[@]}" -I"$work/include" -I"$work" -I"$profile/src/sensors" "$work/actual.c" -o "$work/check"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/check"
if [[ $sanitize == 0 ]]; then
 for mutant in always-both stale-front keep-old-result held-unregister queue-before-readers invented-open-state; do
  awk -v m="$mutant" '
   /^static void ssc_dual_reset_locked\(/ {reset=1}
   /^static void ssc_shutdown\(/ {shutdown=1}
   m=="always-both" && /required = d->lid_known && d->lid_closed \? 2U : 3U;/ {print "\trequired = 3U;";n++;next}
   m=="stale-front" && /if \(s->sample_sequence <= d->front_floor_sequence\)/ {print "\t\tif (false && (s->sample_sequence <= d->front_floor_sequence))";n++;next}
   m=="keep-old-result" && reset && /^\td->result_valid = false;$/ {print "\t(void)d->result_valid;";n++;next}
   m=="held-unregister" && shutdown && /^\tmutex_unlock\(&c->control\);$/ {print "\t/* Deliberately retain control across unregister. */";n++;next}
   m=="queue-before-readers" && shutdown && /^\tmutex_unlock\(&c->control\);$/ {print;print "\tdestroy_workqueue(c->workqueue);";n++;next}
   m=="queue-before-readers" && shutdown && /^\tdestroy_workqueue\(c->workqueue\);$/ {n++;next}
   m=="invented-open-state" && /ssc_dual_lid_locked\(c, closed \|\| c->dual.lid_known, closed\);/ {print "\t\tssc_dual_lid_locked(c, true, closed);";n++;next}
   {print}
   /^}/ {reset=0;shutdown=0}
   END {if(n!=((m=="always-both"||m=="queue-before-readers")?2:1))exit 1}
  ' "$work/actual.c" > "$work/mutant.c"
  "$cc" "${flags[@]}" -I"$work/include" -I"$work" -I"$profile/src/sensors" "$work/mutant.c" -o "$work/mutant"
  set +e
  (ulimit -c 0; "$work/mutant") > "$work/mutant.log" 2>&1
  status=$?
  set -e
  [[ $status == 134 ]]
  grep -Eq 'Assertion .* failed' "$work/mutant.log"
  printf 'Actual combined-light behavioral mutant refused:%s/%s.\n' "$cc" "$mutant"
 done
fi
printf 'Actual combined-light endpoint callbacks passed:%s/sanitize%s; controlled providers, not physical acceptance.\n' "$cc" "$sanitize"
