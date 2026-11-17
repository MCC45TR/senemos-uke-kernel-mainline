#!/usr/bin/bash
# COPR only: tiny test tree contains board predicates, never live unit data.
set -Eeuo pipefail
[[ $# == 3 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");owner=$(realpath "$2");result=$(realpath -m "$3")
[[ ! -e $result && ! -L $result ]]
mkdir "$result"
dtc -q -I dts -O dtb -o "$result/front-profile.dtb" "$owner/tests/fixtures/front-observed734.dts"
[[ $(stat -c %s "$result/front-profile.dtb") -lt 32768 ]]
for compiler in gcc clang;do
 for mode in plain sanitized;do
  flags=()
  [[ $mode != sanitized ]] || flags=('-fsanitize=address,undefined' -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" -std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror "${flags[@]}" \
   -I "$kernel/arch/arm64/kernel" "$owner/tests/fixtures/front-observed734-check.c" -lfdt -o "$result/check"
  ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 timeout 15s "$result/check" "$result/front-profile.dtb" >> "$result/results.txt"
 done
done
[[ $(grep -c '^Observed front predicates:' "$result/results.txt") == 4 ]]
(cd "$owner";sha256sum tests/fixtures/front-observed734.dts) > "$result/profile.sha256"
jq -n '{compiler_modes:4,board_predicate_projection:true,phandles_remapped:true,contains_unit_data:false,contains_eeprom_contents:false,physical_device_accessed:false,physical_camera_accepted:false}' > "$result/qualification.json"
cat "$result/results.txt"
