#!/usr/bin/env bash
# Authenticate the new source before allowing an exact historical fixture view.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
actual=$kernel/drivers/input/misc/qcom-smp2p-switch.c
before=$kernel/native-generated/hall-before-physical-startup.c
profile=$kernel/native-profile
printf '%s  %s\n' \
 4c48d1fda32935c979e30bc8d2e99582ca216e5bf4635b8db072c8a21d09068d "$actual" \
 14a7922f690bf1615ffa925e14e7da612da4d2c0e6338710662f3de0856c7cb3 "$before" | sha256sum -c --strict --quiet -
jq -e '.hall_physical_initial_layer==1 and .hall_physical_initial_optional and .hall_physical_initial_active_low and .hall_physical_initial_input_only and .hall_physical_initial_remote_irq_unchanged and (.physical_acceptance|not)' "$profile/source-composition.json" >/dev/null
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
install -Dm644 "$actual" "$work/drivers/input/misc/qcom-smp2p-switch.c"
git -C "$work" apply --reverse --check --whitespace=error "$profile/src/input/0003-smp2p-switch-physical-startup.patch"
git -C "$work" apply --reverse --whitespace=error "$profile/src/input/0003-smp2p-switch-physical-startup.patch"
cmp "$before" "$work/drivers/input/misc/qcom-smp2p-switch.c"
printf '%s\n' "$before"
