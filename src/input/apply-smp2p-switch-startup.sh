#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Apply only to the exact cumulative driver's selective-wake implementation.
set -Eeuo pipefail
kernel=$(realpath "${1:?Pass prepared kernel}")
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
driver=$kernel/drivers/input/misc/qcom-smp2p-switch.c
before=f2f88aa474497b0162c053221df5a45818df0e2a5f830dc6632321754cf8f50e
after=14a7922f690bf1615ffa925e14e7da612da4d2c0e6338710662f3de0856c7cb3
actual=$(sha256sum "$driver" | cut -d' ' -f1)
[[ $actual != "$after" ]] || exit 0
[[ $actual == "$before" ]] || { echo 'Unexpected SMP2P switch source; review cumulative changes' >&2; exit 1; }
git -C "$kernel" apply --check "$owner/patches/input/0002-smp2p-switch-initial-state.patch"
git -C "$kernel" apply "$owner/patches/input/0002-smp2p-switch-initial-state.patch"
printf '%s  %s\n' "$after" "$driver" | sha256sum --check --strict -
