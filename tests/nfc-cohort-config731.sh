#!/usr/bin/env bash
# COPR: compare the full effective composition to an independently resolved input.
set -Eeuo pipefail
actual=${1:?Combined effective configuration}
reference=${2:?Independently resolved Android-network configuration}
grep -Fxq CONFIG_HID_NANOSIC_UKE=m "$actual"
if grep -Eq '^CONFIG_HID_NANOSIC_UKE=[ym]$' "$reference"; then exit 1; fi
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
for role in actual reference; do
 input=$actual
 [[ $role != reference ]] || input=$reference
 awk '
 /^CONFIG_[A-Z0-9_]+=/ || /^# CONFIG_[A-Z0-9_]+ is not set$/ {
  if($0!~/^(CONFIG_HID_NANOSIC_UKE=|# CONFIG_HID_NANOSIC_UKE is not set$)/) print
 }' "$input" | LC_ALL=C sort > "$stage/$role"
done
cmp "$stage/actual" "$stage/reference"
printf '%s\n' 'Complete combined Kconfig equals the independently resolved network input plus the pogo HID module.'
