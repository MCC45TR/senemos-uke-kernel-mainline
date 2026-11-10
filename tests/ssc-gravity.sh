#!/usr/bin/bash
# COPR only; actual protocol/driver callbacks, not a reimplemented decoder.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
profile=$kernel/native-profile
core=$kernel/drivers/iio/common/uke-ssc
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/include/linux"
cat > "$work/include/linux/types.h" <<'TYPES'
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
typedef uint8_t u8;typedef uint16_t u16;typedef uint32_t u32;typedef uint64_t u64;typedef int64_t s64;
TYPES
cp "$kernel/include/uapi/linux/iio/types.h" "$work/actual-iio-types.h"
extract(){ awk -v start="$2" '$0~start{emit=1}emit{print}emit&&/^}/{found++;exit}END{if(found!=1)exit 1}' "$1"; }
# The enum is one line; extract it alone to avoid duplicating the next struct.
awk '/^#define SSC_(SENSOR_COUNT|SAMPLE_MAX|FRONT_LIGHT|REAR_LIGHT) /{print;n++} /^enum ssc_kind /{print;n++}END{if(n!=5)exit 1}' "$core/uke-ssc-iio.c" > "$work/actual-gravity-descriptions.inc"
for start in '^struct ssc_description [{]' '^static const struct ssc_description ssc_descriptions\[';do extract "$core/uke-ssc-iio.c" "$start" >> "$work/actual-gravity-descriptions.inc";done
for name in ssc_sample_channels ssc_rate ssc_sample_values ssc_attributes_usable ssc_read_scale ssc_allocate_iio ssc_publish_locked;do
 extract "$core/uke-ssc-iio.c" "^static .* $name[(]" >> "$work/actual-gravity-callbacks.inc"
done
cp "$work/actual-gravity-callbacks.inc" "$work/good.inc"
ulimit -c 0
for cc in gcc clang;do
 for san in 0 1;do
  flags=(-std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror)
  [[ $san == 0 ]] || flags+=(-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$cc" "${flags[@]}" -I"$work/include" -I"$work" -I"$core" "$core/uke-ssc-protocol.c" "$profile/tests/ssc-gravity.c" -o "$work/check"
  "$work/check"
  printf 'Actual SSC gravity callbacks passed:%s/sanitize%s.\n' "$cc" "$san"
 done
 for bad in truncated virtual;do
  cp "$work/good.inc" "$work/actual-gravity-callbacks.inc"
  case $bad in
   truncated) sed -i 's/i < ssc_sample_channels(d)/i < (d->dimensions == 3 ? 3 : 1)/' "$work/actual-gravity-callbacks.inc";;
   virtual) sed -i 's/description->kind == SSC_GRAVITY)/description->kind != SSC_GRAVITY)/' "$work/actual-gravity-callbacks.inc";;
  esac
  ! cmp -s "$work/good.inc" "$work/actual-gravity-callbacks.inc"
  "$cc" -std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror -I"$work/include" -I"$work" -I"$core" "$core/uke-ssc-protocol.c" "$profile/tests/ssc-gravity.c" -o "$work/bad"
  status=0
  "$work/bad" > "$work/$cc-$bad.log" 2>&1 || status=$?
  [[ $status == 134 ]]
  grep -F 'Assertion' "$work/$cc-$bad.log"
  printf 'Gravity semantic regression refused:%s/%s/status134.\n' "$cc" "$bad"
 done
 cp "$work/good.inc" "$work/actual-gravity-callbacks.inc"
done
