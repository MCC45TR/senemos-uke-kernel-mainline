#!/usr/bin/bash
# COPR only. No tablet compiler or hardware access.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
profile=$(cd -- "$(dirname -- "$0")/.." && pwd)
driver=${1:?Actual prepared postimage SSC driver}
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
cp "$profile/tests/ssc-stream-owners-host.h" "$work/host.h"
{
 printf '#include "host.h"\n#include "uke-ssc-protocol.h"\n'
 awk '/^#define SSC_SERVICE /{emit=1} /^struct ssc_qmi_request /{exit} emit{print}' "$driver"
 for name in ssc_current ssc_invalidate_locked ssc_read_scale ssc_stream_wanted ssc_stream_user_valid ssc_stream_get ssc_stream_put ssc_read_raw ssc_buffer_enable ssc_buffer_disable; do
  awk -v name="$name" '
   $0 ~ "^static .*([[:space:]]|[*])" name "\\(" && $0 !~ /;/ {emit=1;found=1}
   emit {print} emit && /^}/ {exit}
   END {if(!found)exit 1}
  ' "$driver"
 done
 cat "$profile/tests/ssc-stream-owners.c"
} > "$work/actual.c"
flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -Wno-unused-function -fno-omit-frame-pointer)
[[ $sanitize == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
"$cc" "${flags[@]}" -I"$work/include" -I"$work" -I"$profile/src/sensors" "$work/actual.c" -o "$work/test"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/test"
if [[ $sanitize == 0 ]]; then
 for mutant in restart-shared stop-shared duplicate-owner failed-lease no-buffer-snapshot; do
  awk -v m="$mutant" '
   m=="restart-shared" && /ret = active \? 0 : ssc_start\(s\);/ {sub(/active \? 0 :/,"((void)active, false) ? 0 :");n++}
   m=="stop-shared" && /return remaining \? 0 : ssc_stop\(s\);/ {sub(/remaining \? 0 :/,"((void)remaining, false) ? 0 :");n++}
   m=="duplicate-owner" && /if \(s->stream_users & user\)/ {sub(/if \(/,"if (false && ");n++}
   m=="failed-lease" && /^\t\ts->stream_users &= ~user;$/ {sub(/s->stream_users &= ~user;/,"s->stream_users |= user;");n++}
   m=="no-buffer-snapshot" && /s->ticks && s->registered && s->sample_sequence == sequence/ {sub(/s->ticks &&/,"false && s->ticks &&");n++}
   {print} END {if(n!=1)exit 1}
  ' "$work/actual.c" > "$work/mutant.c"
  "$cc" "${flags[@]}" -I"$work/include" -I"$work" -I"$profile/src/sensors" "$work/mutant.c" -o "$work/mutant"
  set +e
  (ulimit -c 0; "$work/mutant") > "$work/mutant.log" 2>&1
  status=$?
  set -e
  [[ $status == 134 ]]
  grep -Eq 'Assertion .* failed' "$work/mutant.log"
  printf 'Shared SSC stream behavioral mutant refused:%s/%s.\n' "$cc" "$mutant"
 done
fi
printf 'Actual shared SSC stream owner callbacks passed:%s/sanitize%s; endpoint and physical acceptance pending.\n' "$cc" "$sanitize"
