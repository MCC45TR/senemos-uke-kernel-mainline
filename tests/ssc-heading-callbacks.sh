#!/usr/bin/bash
# Actual new callbacks and existing shared-ownership code, fake providers only.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared heading source}")
profile=$kernel/native-profile
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/include/linux"
printf '#include <stdint.h>\ntypedef int64_t s64;typedef int32_t s32;typedef uint64_t u64;\n' > "$work/include/linux/types.h"
printf '#include <asm-generic/errno.h>\n' > "$work/include/linux/errno.h"
cp "$kernel/include/uapi/linux/iio/types.h" "$work/actual-iio-types.h"
for name in ssc_stream_wanted ssc_stream_user_valid ssc_stream_get ssc_stream_put;do
 awk -v name="$name" '$0~("^static .* "name"[(]"){emit=1}emit{print}emit&&/^}/{n++;exit}END{if(n!=1)exit 1}' "$kernel/drivers/iio/common/uke-ssc/uke-ssc-iio.c" >> "$work/actual-heading-streams.inc"
done
cp "$kernel/drivers/iio/common/uke-ssc/uke-ssc-heading-input.h" "$work/uke-ssc-heading-input.h"
cp "$work/uke-ssc-heading-input.h" "$work/good-heading.h"
cp "$work/actual-heading-streams.inc" "$work/good-streams.inc"
ulimit -c 0
for compiler in gcc clang;do
 for mode in 0 1;do
  flags=(-std=gnu11 -O2 -Wall -Wextra -Werror -UNDEBUG -Wno-unused-parameter)
  [[ $mode == 0 ]] || flags+=(-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" "${flags[@]}" -I"$work/include" -I"$work" -I"$kernel/drivers/iio/common/uke-ssc" "$profile/tests/ssc-heading-callbacks.c" -o "$work/check"
  "$work/check"
  printf 'Actual heading lifecycle callbacks passed:%s/sanitize%s; no hardware.\n' "$compiler" "$mode"
 done
 for bad in game_north final_owner;do
  if [[ $bad == game_north ]];then sed -i 's/if (strcmp(s->description->datatype, "rotv"))/if (!strcmp(s->description->datatype, "rotv"))/' "$work/uke-ssc-heading-input.h";else sed -i 's/return remaining ? 0 : ssc_stop(s);/return remaining ? ssc_stop(s) : ssc_stop(s);/' "$work/actual-heading-streams.inc";fi
  "$compiler" -std=gnu11 -O2 -Wall -Wextra -Werror -UNDEBUG -Wno-unused-parameter -I"$work/include" -I"$work" -I"$kernel/drivers/iio/common/uke-ssc" "$profile/tests/ssc-heading-callbacks.c" -o "$work/bad"
  result=0;"$work/bad" > "$work/bad.log" 2>&1 || result=$?
  [[ $result == 134 ]]
  grep -F Assertion "$work/bad.log"
  printf 'Heading lifecycle regression refused:%s/%s/status134.\n' "$compiler" "$bad"
  cp "$work/good-heading.h" "$work/uke-ssc-heading-input.h"
  cp "$work/good-streams.inc" "$work/actual-heading-streams.inc"
 done
done
