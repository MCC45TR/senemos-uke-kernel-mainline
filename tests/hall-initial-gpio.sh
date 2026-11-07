#!/usr/bin/env bash
# Native fixture compilation belongs in COPR, never on the tablet.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cc=${CC:-gcc}
cxx=${CXX:-g++}
sanitize=${SANITIZE:-0}
[[ $sanitize == 0 || $sanitize == 1 ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
flags=(-O1 -g -Wall -Wextra -Werror -UNDEBUG -fno-omit-frame-pointer)
[[ $sanitize == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
driver=$kernel/drivers/input/misc/qcom-smp2p-switch.c
make_callbacks(){ awk '/^#include <linux\//{next}/^static int smp2p_switch_probe\(/{exit}{print}' "$1" > "$work/callbacks.h"; }
make_callbacks "$driver"
cp "$root/tests/hall-initial-gpio-provider.h" "$work/"
# Every legacy assertion is retained; only the provider and explicit renamed
# main return are added to its test-only wrapper.
sed '/^#include "callbacks.h"$/i #include "hall-initial-gpio-provider.h"' "$root/tests/hall-startup.c" | sed '$i\    return 0;' > "$work/legacy-hall.c"
for gpio in 1 0;do
 "$cc" -std=gnu11 "${flags[@]}" -DCONFIG_GPIOLIB="$gpio" -I"$work" "$root/tests/hall-initial-gpio.c" -o "$work/callbacks"
 ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/callbacks"
done
if [[ $sanitize == 0 ]];then
 for mutation in raw-level no-put ignore-direction no-debounce gpio-on-irq;do
  awk -v m="$mutation" '
   m=="raw-level"&&/state = gpiod_get_value_cansleep\(gpio\);/{sub(/gpiod_get_value_cansleep/,"gpiod_get_raw_value_cansleep");n++}
   m=="no-put"&&/^\tgpiod_put\(gpio\);$/{sub(/gpiod_put\(gpio\)/,"(void)gpio");n++}
   m=="ignore-direction"&&/^\tif \(ret != 1\) /{sub(/ret != 1/,"false");n++}
   m=="no-debounce"&&/ret = state == next \? state : -EAGAIN;/{sub(/state == next \? state : -EAGAIN/,"state");n++}
   m=="gpio-on-irq"&&/state = irq \? smp2p_switch_read\(sw\) : smp2p_switch_read_initial\(sw\);/{sub(/irq \? smp2p_switch_read\(sw\) : /,"");n++}
   {print}END{if(n!=1)exit 1}
  ' "$driver" > "$work/mutant.c"
  make_callbacks "$work/mutant.c"
  "$cc" -std=gnu11 "${flags[@]}" -DCONFIG_GPIOLIB=1 -I"$work" "$root/tests/hall-initial-gpio.c" -o "$work/mutant"
  set +e
  (ulimit -c 0; "$work/mutant") > "$work/mutant.log" 2>&1
  status=$?
  set -e
  [[ $status == 134 ]]
  grep -Eq 'Assertion .* failed' "$work/mutant.log"
  printf 'Actual Hall physical startup mutant refused:%s/%s.\n' "$cc" "$mutation"
 done
 make_callbacks "$driver"
fi
sed '$i\    return 0;' "$root/tests/hall-resource-contract.cpp" > "$work/legacy-hall-dt.cpp"
printf '#include <libfdt.h>\n#include <stdio.h>\n#include <string.h>\n#define UKE_INIT\n#include "uke-hall.h"\nint uke_hall_test(void *fdt) {return uke_hall(fdt);}\n' > "$work/entry.c"
for source in "$kernel"/scripts/dtc/libfdt/*.c "$work/entry.c";do
 "$cc" -std=gnu11 "${flags[@]}" -I"$kernel/scripts/dtc/libfdt" -I"$root/src/boot" -c "$source" -o "$work/$(basename "${source%.c}").o"
done
"$cxx" -std=c++20 "${flags[@]}" -I"$kernel/scripts/dtc/libfdt" -I"$work" "$root/tests/hall-initial-gpio-dt.cpp" "$work/"*.o -o "$work/dt"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/dt" "${2:-}"
printf 'Actual optional physical Hall callbacks and DT passed:%s/sanitize%s; stationary boot acceptance separate.\n' "$cc" "$sanitize"
