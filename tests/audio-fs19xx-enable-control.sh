#!/usr/bin/env bash
# COPR-only actual private-header callback tests; no ALSA/DSP/device access.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
cc=${CC:-gcc}
sanitize=${SANITIZE:-0}
[[ $sanitize == 0 || $sanitize == 1 ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -fno-omit-frame-pointer)
[[ $sanitize == 0 ]] || flags+=(-fsanitize=address,undefined)
cp "$owner/src/audio/uke-fs19xx-enable-control.h" "$work/uke-fs19xx-enable-control.h"
"$cc" "${flags[@]}" -I "$work" -I "$owner/src/audio" "$owner/tests/audio-fs19xx-enable-control.c" -o "$work/getter"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/getter"
if [[ $sanitize == 0 ]];then
 cp "$work/uke-fs19xx-enable-control.h" "$work/original.h"
 for mutant in privilege inactive generation after-running disabled-mask;do
  awk -v mutant="$mutant" '
   mutant=="privilege" && /!capable\(CAP_SYS_RAWIO\)/{sub(/!capable\(CAP_SYS_RAWIO\)/,"false");changed++}
   mutant=="inactive" && /fs->data.status != UKE_FS_RUNNING/{sub(/fs->data.status != UKE_FS_RUNNING/,"false");changed++}
   mutant=="generation" && /fs19xx_guard.generation == generation/{sub(/fs19xx_guard.generation == generation/,"((void)generation, true)");changed++}
   mutant=="after-running" && /running = uke_fs_guard_running.* && /{sub(/uke_fs_guard_running\(&fs19xx_guard\)/,"true");changed++}
   mutant=="disabled-mask" && /enabled \+ 1;/{sub(/enabled \+ 1/,"4");changed++}
   {print}END{if(changed!=1)exit 1}
  ' "$work/original.h" > "$work/uke-fs19xx-enable-control.h"
  "$cc" "${flags[@]}" -I "$work" -I "$owner/src/audio" "$owner/tests/audio-fs19xx-enable-control.c" -o "$work/mutant"
  set +e
  (ulimit -c 0; "$work/mutant") > "$work/mutant.log" 2>&1
  result=$?
  set -e
  [[ $result == 134 ]]
  printf 'Detected enable getter assertion mutant: %s/%s.\n' "$cc" "$mutant"
 done
fi
printf 'Actual FS19xx enable getter passed:%s/sanitize%s; no physical query.\n' "$cc" "$sanitize"
