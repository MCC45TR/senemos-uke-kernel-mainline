#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR: execute actual driver callbacks with an unavailable/late remote pair.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
driver=$(realpath "${1:?Pass prepared qcom-smp2p-switch.c}")
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
awk '/^#include <linux\// {next} /^static int smp2p_switch_probe\(/ {exit} {print}' "$driver" > "$work/callbacks.h"
cp "$root/tests/hall-startup.c" "$work/check.c"
"${CC:-cc}" -std=gnu11 -O2 -g -Wall -Wextra -Werror -UNDEBUG ${HALL_TEST_FLAGS:-} \
    "$work/check.c" -o "$work/check"
"$work/check"
printf 'Hall startup: late closed/open without IRQ, unknown/conflict/errors, real wake, resume, timeout and cleanup PASS\n'
