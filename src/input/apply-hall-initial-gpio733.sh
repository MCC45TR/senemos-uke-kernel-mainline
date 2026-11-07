#!/usr/bin/env bash
# COPR only: apply the exact additive initial sampler after all prior layers.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$kernel/native-profile
driver=$kernel/drivers/input/misc/qcom-smp2p-switch.c
before=14a7922f690bf1615ffa925e14e7da612da4d2c0e6338710662f3de0856c7cb3
after=4c48d1fda32935c979e30bc8d2e99582ca216e5bf4635b8db072c8a21d09068d
[[ ! -e $kernel/native-generated/hall-before-physical-startup.c ]]
printf '%s  %s\n' "$before" "$driver" | sha256sum -c --strict --quiet -
install -m644 "$driver" "$kernel/native-generated/hall-before-physical-startup.c"
git -C "$kernel" apply --check --whitespace=error "$profile/src/input/0003-smp2p-switch-physical-startup.patch"
git -C "$kernel" apply --whitespace=error "$profile/src/input/0003-smp2p-switch-physical-startup.patch"
git -C "$kernel" apply --check --whitespace=error "$profile/src/input/0005-smp2p-switch-state-gpio-binding.patch"
git -C "$kernel" apply --whitespace=error "$profile/src/input/0005-smp2p-switch-state-gpio-binding.patch"
printf '%s  %s\n' "$after" "$driver" | sha256sum -c --strict --quiet -
cmp "$profile/src/boot/uke-hall.h" "$kernel/arch/arm64/kernel/uke-hall.h"
printf 'Exact Hall physical initial-level sampler and optional binding applied; remote IRQ/wake path retained.\n'
