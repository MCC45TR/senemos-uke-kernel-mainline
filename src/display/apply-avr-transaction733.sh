#!/usr/bin/bash
# COPR only. Late cumulative layer after original display source qualification.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
profile=$kernel/native-profile
git -C "$kernel" apply --check --whitespace=error "$profile/src/display/0075-o82-avr-retime-rollback.patch"
git -C "$kernel" apply --whitespace=error "$profile/src/display/0075-o82-avr-retime-rollback.patch"
printf 'Dual-INTF AVR transaction applied; existing atomic quarantine, DSI timing, gain and DT unchanged.\n'
