#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
kernel=$(realpath "${1:?Pass prepared kernel source}")
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
{
    printf '#include <libfdt.h>\n#include <stdio.h>\n#define UKE_INIT\n'
    awk '/^static int UKE_INIT uke_delete_optional\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$root/src/boot/uke-abl.c"
    printf '#include "uke-pmic-adc.h"\nint uke_pmic_adc_test(void *fdt) { return uke_pmic_adc(fdt); }\n'
    printf '#include "uke-cpu-thermal.h"\nint uke_cpu_thermal_test(void *fdt) { return uke_cpu_thermal(fdt); }\n'
} > "$work/entry.c"
for source in "$kernel"/scripts/dtc/libfdt/*.c "$work/entry.c"; do
    "${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -I"$kernel/scripts/dtc/libfdt" -I"$root/src/boot" -c "$source" -o "$work/$(basename "${source%.c}").o"
done
"${CXX:-c++}" -std=c++20 -O2 -Wall -Wextra -Werror -UNDEBUG -I"$kernel/scripts/dtc/libfdt" "$root/tests/pmic-adc-contract.cpp" "$work/"*.o -o "$work/test"
"$work/test" "${2:-}"
