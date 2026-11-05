#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR: reject missed retries, fabricated state, wake on resync and lost cleanup.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Pass prepared kernel}")
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
driver=$kernel/drivers/input/misc/qcom-smp2p-switch.c
for mutation in no-retry guess-open wake-on-read no-cancel; do
    cp "$driver" "$work/$mutation.c"
    case $mutation in
        no-retry) sed -i 's/if (++sw->initial_retries < SMP2P_SWITCH_INITIAL_RETRIES)/if (++sw->initial_retries < 1)/' "$work/$mutation.c";;
        guess-open) sed -i 's/return -EAGAIN;/return 0;/' "$work/$mutation.c";;
        wake-on-read) sed -i 's/irq == sw->open_irq \&\& !state/(irq == sw->open_irq || irq == 0) \&\& !state/' "$work/$mutation.c";;
        no-cancel) sed -i '/^static void smp2p_switch_work_cleanup/,/^}/ s/cancel_delayed_work_sync(\&sw->initial_work);/(void)sw;/' "$work/$mutation.c";;
    esac
    ! cmp -s "$driver" "$work/$mutation.c"
    if bash "$root/tests/hall-startup-contract.sh" "$work/$mutation.c" > "$work/$mutation.log" 2>&1; then
        printf 'Mutation unexpectedly passed: %s\n' "$mutation" >&2; exit 1
    fi
    # A compile failure alone is not a behavioral negative control.
    grep -Eq 'Assertion .* failed' "$work/$mutation.log"
    printf 'Actual Hall callback assertion rejects %s PASS\n' "$mutation"
done
cp "$kernel/native-generated/hall-before-startup.c" "$work/before.c"
printf '%s  %s\n' f2f88aa474497b0162c053221df5a45818df0e2a5f830dc6632321754cf8f50e "$work/before.c" | sha256sum -c --strict -
# Production predecessor performs one probe-time read. Without an IRQ it has
# no work to read a later stationary pair; verify its source path is retained.
awk '/^static int smp2p_switch_probe\(/ {probe=1} probe && /smp2p_switch_irq\(0, sw\)/ {found++} END {exit found!=1}' "$work/before.c"
! grep -q 'queue_delayed_work\|initial_work' "$work/before.c"
printf 'Exact predecessor has one-shot startup and no delayed resync; hardware cause remains unproved\n'
