#!/usr/bin/bash
# COPR only: extract actual production callbacks; never compile on the tablet.
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
awk '/^#define SSC_(SENSOR_COUNT|SAMPLE_MAX|SCAN_MAX|FRONT_LIGHT|REAR_LIGHT) /{print;n++} /^enum ssc_kind /{print;n++}END{if(n!=6)exit 1}' "$core/uke-ssc-iio.c" > "$work/actual-quaternion-descriptions.inc"
for start in '^struct ssc_description [{]' '^static const struct ssc_description ssc_descriptions[[]';do extract "$core/uke-ssc-iio.c" "$start" >> "$work/actual-quaternion-descriptions.inc";done
for name in ssc_sample_channels ssc_rate ssc_sample_values ssc_attributes_usable ssc_read_scale ssc_read_sample ssc_read_raw ssc_read_raw_multi ssc_allocate_iio ssc_publish_locked;do extract "$core/uke-ssc-iio.c" "^static .* $name[(]" >> "$work/actual-quaternion-callbacks.inc";done
for name in iio_storage_bytes_for_si iio_storage_bytes_for_timestamp iio_compute_scan_bytes;do extract "$kernel/drivers/iio/industrialio-buffer.c" "^static int $name[(]" >> "$work/actual-iio-layout.inc";done
cp "$work/actual-quaternion-callbacks.inc" "$work/good.inc"
ulimit -c 0
for cc in gcc clang;do
 for san in 0 1;do
  flags=(-std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror)
  [[ $san == 0 ]] || flags+=(-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$cc" "${flags[@]}" -I"$work/include" -I"$work" -I"$core" "$core/uke-ssc-protocol.c" "$profile/tests/ssc-quaternion-buffer.c" -o "$work/check"
  "$work/check"
  printf 'Actual SSC quaternion callbacks passed:%s/sanitize%s.\n' "$cc" "$san"
 done
 for bad in repeat scalar_format vector_length undersized_scan;do
  cp "$work/good.inc" "$work/actual-quaternion-callbacks.inc"
  case $bad in
   repeat) sed -i 's/scan_type.repeat = 4/scan_type.repeat = 1/' "$work/actual-quaternion-callbacks.inc";;
   scalar_format) sed -i 's/return IIO_VAL_INT_64/return IIO_VAL_INT/' "$work/actual-quaternion-callbacks.inc";;
   vector_length) sed -i 's/\*val_len = 4/\*val_len = 1/' "$work/actual-quaternion-callbacks.inc";;
   undersized_scan) sed -i 's/s64 scan\[SSC_SCAN_MAX\]/s64 scan[SSC_SAMPLE_MAX + 1]/' "$work/actual-quaternion-callbacks.inc";;
  esac
  ! cmp -s "$work/good.inc" "$work/actual-quaternion-callbacks.inc"
  "$cc" -std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror -I"$work/include" -I"$work" -I"$core" "$core/uke-ssc-protocol.c" "$profile/tests/ssc-quaternion-buffer.c" -o "$work/bad"
  status=0;"$work/bad" > "$work/$cc-$bad.log" 2>&1 || status=$?
  [[ $status == 134 ]]
  grep -F Assertion "$work/$cc-$bad.log"
  printf 'Quaternion semantic regression refused:%s/%s/status134.\n' "$cc" "$bad"
 done
 cp "$work/good.inc" "$work/actual-quaternion-callbacks.inc"
done
