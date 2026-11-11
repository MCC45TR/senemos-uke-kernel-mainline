#!/usr/bin/env bash
# COPR only: exercise real I2C wake setup and real FM19511 probe/remove callbacks.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
kernel=$(realpath "${1:?Linux 7.3.1 source directory}")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
extract()
{
 awk -v pattern="$2" '
  $0 ~ pattern {copy=1; found++}
  copy {print}
  copy && /^}/ {copy=0}
  END {if(found!=1 || copy)exit 1}
 ' "$1" > "$3"
}
extract "$kernel/include/linux/pm_wakeup.h" '^static inline int device_init_wakeup[(]' "$work/init.inc"
extract "$kernel/drivers/base/power/wakeup.c" '^static int device_wakeup_attach[(]' "$work/attach.inc"
extract "$kernel/drivers/base/power/wakeup.c" '^int device_wakeup_enable[(]' "$work/enable.inc"
extract "$kernel/drivers/base/power/wakeirq.c" '^static int dev_pm_attach_wake_irq[(]' "$work/attach-irq.inc"
extract "$kernel/drivers/base/power/wakeirq.c" '^int dev_pm_set_wake_irq[(]' "$work/set-irq.inc"
awk '
 /^\tif \(client->flags & I2C_CLIENT_WAKE\) \{$/ {copy=1;found++}
 copy {
  print; line=$0; opens=gsub(/\{/,"",line); line=$0; closes=gsub(/}/,"",line)
  depth+=opens-closes; if(!depth)copy=0
 }
 END {if(found!=1 || copy)exit 1}
' "$kernel/drivers/i2c/i2c-core-base.c" > "$work/core.inc"
grep -Fq 'info->flags |= I2C_CLIENT_WAKE;' "$kernel/drivers/i2c/i2c-core-of.c"
grep -Fq 'of_property_read_bool(node, "wakeup-source")' "$kernel/drivers/i2c/i2c-core-of.c"
awk '/^struct fm19511 \{/ {copy=1} copy{print} copy && /^};/{copy=0;found++} END{if(found!=1)exit 1}' \
 "$root/src/nfc/fm19511-uke.c" > "$work/struct.inc"
for state in before after; do
 source=$root/src/nfc/fm19511-uke.c
 [[ $state != before ]] || source=$root/tests/fixtures/fm19511-before-wakeup-owner.c
 for name in free power_off probe remove; do
  extract "$source" "^static (int|void) fm19511_$name[(]" "$work/$name.inc"
 done
 ${CC:-cc} ${FM19511_WAKEUP_TEST_FLAGS:-} -std=gnu11 -O2 -Wall -Wextra -Werror \
  -Wno-unused-function -Wno-unused-parameter -DEXPECT_BEFORE="$([[ $state == before ]] && printf 1 || printf 0)" \
  -I "$work" "$root/tests/fixtures/fm19511-wakeup-owner-check.c" -o "$work/test-$state"
 "$work/test-$state"
done
