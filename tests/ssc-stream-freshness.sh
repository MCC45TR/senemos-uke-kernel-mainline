#!/usr/bin/bash
# COPR only: actual postimage callbacks and controlled Linux/SSC boundaries.
set -Eeuo pipefail
[[ ! -e /etc/senemos/kernel-update.conf && $# == 2 ]]
driver=$(realpath "$1")
types=$(realpath "$2")
project=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cp "$types" "$work/actual-iio-types.h"
extract(){ awk -v name="$2" '$0~"^static .* "name"\\("{emit=1}emit{print}emit&&/^}/{found++;exit}END{if(found!=1)exit 1}' "$1"; }
awk '/^#define SSC_(SENSOR_COUNT|SAMPLE_MAX|SCAN_MAX|FRONT_LIGHT|REAR_LIGHT) /{print} /^enum ssc_kind /{print}' "$driver" > "$work/descriptions.inc"
for pattern in '^struct ssc_description [{]' '^static const struct ssc_description ssc_descriptions[[]';do
 awk -v pattern="$pattern" '$0~pattern{emit=1}emit{print}emit&&/^};/{found++;exit}END{if(found!=1)exit 1}' "$driver" >> "$work/descriptions.inc"
done
for name in ssc_sample_channels ssc_publish_locked ssc_buffer_enable ssc_buffer_disable;do
 extract "$driver" "$name" >> "$work/callbacks.inc"
done
cp "$work/callbacks.inc" "$work/candidate.inc"
ulimit -c 0
for cc in gcc clang;do
 for san in 0 1;do
  flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror)
  [[ $san == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$cc" "${flags[@]}" -I"$work" "$project/tests/ssc-stream-freshness.c" -o "$work/check"
  "$work/check"
 done
 # Reproduce the old unconditional cache replay using the actual enable body.
 sed 's/s->attributes.stream_type == 1 \&\& ssc_current(c)/true \&\& ssc_current(c)/' "$work/candidate.inc" > "$work/callbacks.inc"
 ! cmp -s "$work/callbacks.inc" "$work/candidate.inc"
 "$cc" -std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -I"$work" "$project/tests/ssc-stream-freshness.c" -o "$work/before"
 status=0
 "$work/before" > "$work/before.log" 2>&1 || status=$?
 [[ $status == 134 ]]
 grep -Fq 'Assertion' "$work/before.log"
 printf 'Original streaming cache replay refused:%s/assertion134\n' "$cc"
 cp "$work/candidate.inc" "$work/callbacks.inc"
done
