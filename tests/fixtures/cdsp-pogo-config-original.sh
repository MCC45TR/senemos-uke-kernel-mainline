#!/usr/bin/env bash
# Read-only comparison against the verified 7200 effective configuration.
set -Eeuo pipefail
config=${1:?Pass the compiled kernel configuration}
[[ $(grep -Fxc 'CONFIG_HID_NANOSIC_UKE=m' "$config") == 1 ]]
digest=$(awk '
 /^CONFIG_[A-Z0-9_]+=/ || /^# CONFIG_[A-Z0-9_]+ is not set$/ {
   if($0!="CONFIG_HID_NANOSIC_UKE=m") print
 }
' "$config" | LC_ALL=C sort | sha256sum)
[[ ${digest%% *} == bf504cd2936ea848a8ffdadd556ba3ef27341f0358a67df417078e8127e84aee ]]
printf '%s\n' 'CDSP/pogo configuration: the new HID module is enabled; every other Kconfig setting matches verified 7200.'
