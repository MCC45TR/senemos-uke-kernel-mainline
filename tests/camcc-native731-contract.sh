#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Execute only on COPR; import actual source bodies and framework helper contracts.
set -Eeuo pipefail
[[ $# == 1 ]] || exit 2
kernel=$(realpath -- "$1")
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
awk '/^struct cam_cc_clock \{/ {copy=1} copy {print;if($0=="};")exit}' \
    "$project/src/camera/provider/camcc-sm7675-clocks.h" > "$work/clock-state.h"
awk '/^static inline int dev_set_drv_sync_state\(/ {copy=1} copy {print;if($0=="}")exit}' \
    "$kernel/include/linux/device.h" > "$work/device-sync-function.c"
awk '/^static void genpd_set_stay_on\(/ {copy=1} copy {print;if($0=="}")exit}' \
    "$kernel/drivers/pmdomain/core.c" > "$work/genpd-stay-function.c"
printf '%s  %s\n' \
    105f627f098606f82fb739dfb5cb8a9076ef3214826eb1d261289a78a1156434 "$work/device-sync-function.c" \
    b367dc2f87a740bdd1b885e09c17bd65dd1985a3f0881a013395d6b513ed9dc8 "$work/genpd-stay-function.c" | sha256sum -c -
for part in handoff registration; do
    sed '/^#include /d' "$project/src/camera/provider/camcc-sm7675-$part.h" > "$work/native-$part.h"
done
awk '
 /^static ssize_t probe_(phase|error|gate_register|gate_readback)_show\(/ {copy=1;count++}
 copy {print;if($0=="}")copy=0}
 END {if(count!=4 || copy)exit 1}
' "$project/src/camera/camcc-sm7675.c" > "$work/native-probe-show.c"
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -Wno-unused-parameter
       -Wno-unused-function -Wno-sign-compare -I"$work")
read -r -a extra <<< "${CAMCC_NATIVE_TEST_FLAGS:-}"
"${CC:-clang}" "${flags[@]}" "${extra[@]}" \
    "$project/tests/fixtures/camcc-native-check.c" -o "$work/native"
ASAN_OPTIONS=detect_leaks=1:halt_on_error=1 "$work/native"
if [[ ${CAMCC_NATIVE_MUTATIONS:-0} == 1 ]]; then
    ulimit -c 0
    cp "$work/native-handoff.h" "$work/handoff.saved"
    cp "$work/native-registration.h" "$work/registration.saved"
    cp "$work/native-probe-show.c" "$work/show.saved"
    for mutation in frozen-phase stale-readback live-sysfs-read; do
        cp "$work/handoff.saved" "$work/native-handoff.h"
        cp "$work/registration.saved" "$work/native-registration.h"
        cp "$work/show.saved" "$work/native-probe-show.c"
        case $mutation in
            frozen-phase)
                sed 's/if (!cam_cc_native.probe.complete)/if (true)/' \
                    "$work/handoff.saved" > "$work/native-handoff.h" ;;
            stale-readback)
                sed '/cam_cc_native.probe.gate_read_valid = false;/d' \
                    "$work/registration.saved" > "$work/native-registration.h" ;;
            live-sysfs-read)
                awk '
                 /READ_ONCE\(cam_cc_native.probe.gate_readback\)/ {
                  print "\tu32 value;"
                  print "\tint ret = regmap_read(cam_cc_power.map, cam_cc_native.probe.gate_reg, &value);"
                  print "\treturn ret ? ret : sysfs_emit(buffer, \"%#x\\n\", value);"
                  next
                 } {print}
                ' "$work/show.saved" > "$work/native-probe-show.c" ;;
        esac
        "${CC:-clang}" "${flags[@]}" "$project/tests/fixtures/camcc-native-check.c" \
            -o "$work/mutation"
        if "$work/mutation" > "$work/mutation.log" 2>&1; then
            printf 'Required CAMCC mutation unexpectedly passed: %s\n' "$mutation" >&2
            exit 1
        fi
        grep -q 'Assertion.*failed' "$work/mutation.log"
        printf 'Required CAMCC mutation rejected: %s\n' "$mutation"
    done
fi
printf 'Actual native CAMCC registration/handoff functions passed boundary models; hardware remains unqualified\n'
