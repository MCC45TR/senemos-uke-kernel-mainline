#!/usr/bin/env bash
# COPR only. Execute the actual production entry with controlled overlay phases.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
before=$(realpath "${2:?Exact pre-fix ABL source}")
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
cc=${CC:-gcc};san=${SANITIZE:-0}
[[ $san == 0 || $san == 1 ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -fno-omit-frame-pointer)
[[ $san == 0 ]] || flags+=(-fsanitize=address,undefined)
dtc -q -@ -I dts -O dtb "$owner/tests/audio-oob-entry-overlay.dts" -o "$work/native.dtbo"
extract() {
 local file=$1 out=$2
 awk '/^void \*__init uke_abl_prepare_fdt\(/{p=1}p{print}p&&/^}/{exit}' "$file" > "$out/entry.h"
 test "$(grep -Fc 'void *__init uke_abl_prepare_fdt' "$out/entry.h")" == 1
 local early=0
 if grep -Fq 'uke_audio_config_graph(output)' "$file";then early=1;fi
 "$cc" "${flags[@]}" -DEARLY_CONFIG="$early" -I "$out" -I "$kernel/arch/arm64/kernel" \
  "$owner/tests/audio-oob-entry.c" -lfdt -o "$out/entry"
}
mkdir "$work/fixed"
extract "$kernel/arch/arm64/kernel/uke-abl.c" "$work/fixed"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/fixed/entry" "$work/native.dtbo"
printf 'Actual late OOB entry passed: %s/sanitize%s.\n' "$cc" "$san"
if [[ $san == 0 ]];then
 mkdir "$work/original"
 extract "$before" "$work/original"
 set +e
 "$work/original/entry" "$work/native.dtbo" > "$work/original.log" 2>&1
 original_result=$?
 set -e
 [[ $original_result == 134 ]]
 grep -Fq "n>=0" "$work/original.log"
 printf 'Original early OOB placement reproduces missing supplier: %s/status134.\n' "$cc"
 mkdir "$work/no-capacity"
 awk '
  /ret = uke_abl_native_select/ {native=1}
  native && $0=="\t\t\tret = fdt_open_into(uke_fdt, uke_fdt, sizeof(uke_fdt));" {removed++;next}
  {print} END {if(removed!=1)exit 1}
 ' "$kernel/arch/arm64/kernel/uke-abl.c" > "$work/no-capacity/source.c"
 extract "$work/no-capacity/source.c" "$work/no-capacity"
 set +e
 "$work/no-capacity/entry" "$work/native.dtbo" > "$work/no-capacity.log" 2>&1
 capacity_result=$?
 set -e
 [[ $capacity_result == 134 ]]
 grep -Fq '!setjmp(refusal)' "$work/no-capacity.log"
 printf 'Actual entry capacity mutant detected: %s/status134.\n' "$cc"
fi
