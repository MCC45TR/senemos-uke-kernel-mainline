#!/usr/bin/env bash
# Actual kernel state decoder and exact OEM DT admission, host only.
set -Eeuo pipefail
kernel=$(realpath "${1:?Pass prepared kernel source}")
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cat > "$work/state.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <errno.h>
#define IRQCHIP_STATE_LINE_LEVEL 1
struct smp2p_switch {int open_irq, closed_irq;};
static bool open_level, closed_level;
static int read_error, error_irq;
static int irq_get_irqchip_state(int irq, int which, bool *state) {
    assert(which==IRQCHIP_STATE_LINE_LEVEL);
    if(irq==error_irq && read_error) return read_error;
    *state=irq==10 ? open_level : closed_level;
    return 0;
}
C
awk '/^static int smp2p_switch_read\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$kernel/drivers/input/misc/qcom-smp2p-switch.c" >> "$work/state.c"
cat >> "$work/state.c" <<'C'
int main(void) {
    struct smp2p_switch sw={10,11};
    assert(smp2p_switch_read(&sw)==-EAGAIN);
    open_level=true; assert(smp2p_switch_read(&sw)==0);
    closed_level=true; assert(smp2p_switch_read(&sw)==-EAGAIN);
    open_level=false; assert(smp2p_switch_read(&sw)==1);
    for(int irq=10;irq<=11;irq++) {
        error_irq=irq; read_error=-ENODEV; assert(smp2p_switch_read(&sw)==-ENODEV);
        read_error=-EIO; assert(smp2p_switch_read(&sw)==-EIO);
    }
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror "$work/state.c" -o "$work/state"
"$work/state"
printf '#include <libfdt.h>\n#include <stdio.h>\n#include <string.h>\n#define UKE_INIT\n#include "uke-hall.h"\nint uke_hall_test(void *fdt) {return uke_hall(fdt);}\n' > "$work/entry.c"
for source in "$kernel"/scripts/dtc/libfdt/*.c "$work/entry.c"; do
    "${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -I"$kernel/scripts/dtc/libfdt" -I"$root/src/boot" -c "$source" -o "$work/$(basename "${source%.c}").o"
done
"${CXX:-c++}" -std=c++20 -O2 -Wall -Wextra -Werror -UNDEBUG -I"$kernel/scripts/dtc/libfdt" "$root/tests/hall-resource-contract.cpp" "$work/"*.o -o "$work/dt"
"$work/dt" "${2:-}"
printf '%s\n' 'Hall: open/closed/unknown/conflict, provider errors and OEM resource checks passed'
