#!/usr/bin/bash
# Native COPR only. Controlled boundaries exercise the actual driver callbacks.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
profile=$(cd -- "$(dirname -- "$0")/.." && pwd)
driver=${1:?Prepared cumulative SSC postimage}
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
{
 printf '#include "ssc-proximity-input-host.h"\n#include "uke-ssc-protocol.h"\n#include "uke-ssc-dual-light.h"\n'
 awk '/^#define SSC_SERVICE /{emit=1} /^struct ssc_qmi_request /{exit} emit{print}' "$driver"
 for name in ssc_current ssc_schedule_locked ssc_dual_reset_locked ssc_invalidate_locked \
  ssc_stream_wanted ssc_stream_user_valid ssc_stream_get ssc_stream_put; do
  awk -v name="$name" '
   $0 ~ "^static .*([[:space:]]|[*])" name "\\(" && $0 !~ /;/ {emit=1;found=1}
   emit {print} emit && /^}/ {exit}
   END {if(!found)exit 1}
  ' "$driver"
 done
 cat "$profile/src/sensors/uke-ssc-proximity-input.h"
 awk '
  /^static void ssc_publish_locked\(/ {emit=1;found=1}
  emit {print} emit && /^}/ {exit}
  END {if(!found)exit 1}
 ' "$driver"
 cat "$profile/tests/ssc-proximity-input.c"
} > "$work/actual.c"
flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -Wno-unused-function -fno-omit-frame-pointer)
[[ $sanitize == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
"$cc" "${flags[@]}" -I"$work/include" -I"$profile/tests" -I"$profile/src/sensors" "$work/actual.c" -o "$work/check"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/check"
if [[ $sanitize == 0 ]]; then
 for mutant in initial-bitmap final-owner held-register; do
  awk -v m="$mutant" '
   m=="initial-bitmap" && /cached = ssc_proximity_sample_locked\(s\);/ {print "\tcached = true;";n++;next}
   m=="final-owner" && /return remaining \? 0 : ssc_stop\(s\);/ {print "\t(void)remaining; return ssc_stop(s);";n++;next}
   m=="held-register" && /ret = input_register_device\(input\);/ {print "\tmutex_lock(&c->control);";n++}
   {print}
   END {if(n!=1)exit 1}
  ' "$work/actual.c" > "$work/mutant.c"
  "$cc" "${flags[@]}" -I"$work/include" -I"$profile/tests" -I"$profile/src/sensors" "$work/mutant.c" -o "$work/mutant"
  set +e
  (ulimit -c 0; "$work/mutant") > "$work/mutant.log" 2>&1
  status=$?
  set -e
  [[ $status == 134 ]]
  grep -Eq 'Assertion .* failed' "$work/mutant.log"
  printf 'Actual proximity behavioral mutant refused:%s/%s.\n' "$cc" "$mutant"
 done
fi
printf 'Actual proximity input callbacks passed:%s/sanitize%s; transport/input providers are controlled.\n' "$cc" "$sanitize"
