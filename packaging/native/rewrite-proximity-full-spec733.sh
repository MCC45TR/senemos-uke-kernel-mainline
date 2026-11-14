#!/usr/bin/bash
# Pure text adapter. Preserve every existing full-kernel phase and payload.
set -Eeuo pipefail
[[ $# == 1 ]]
spec=$(realpath "${1:?Cumulative full spec}")
[[ $(grep -Fxc 'Name: senemos-uke-linux-kernel-mainline-unstable' "$spec") == 1 ]]
if grep -Eq 'UKE_PROXIMITY_CRASH_HISTORY_DELIVERY|^Requires: uke-control\(critical-crash-count-v1\)' "$spec"; then exit 1; fi
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
awk '
 $0=="%build" {build++;inbuild=1}
 $0=="%check" {check++;inbuild=0;incheck=1}
 $0=="%install" {install++;incheck=0}
 $0=="Requires: uke-control(critical-rollback-v1) >= 1" {
  print;print "Requires: uke-control(critical-crash-count-v1) >= 1";dependency++;next
 }
 /^bash native-profile\/packaging\/native\/check-speaker-quad733.sh .* source$/ {
  if(!inbuild || apply++)exit 1
  print
  print "# UKE_PROXIMITY_CRASH_HISTORY_DELIVERY"
  print "bash native-profile/src/sensors/apply-proximity-input733.sh \"$PWD\""
  print "bash native-profile/src/health/apply-rproc-count733.sh \"$PWD\""
  next
 }
 /^bash boot-recipe\/src\/boot\/build-payload.sh / {
  if(!inbuild || apply!=1 || image++)exit 1
 }
 /^bash native-profile\/packaging\/native\/check-speaker-quad733.sh .* linked$/ {
  if(!incheck || image!=1 || linked++)exit 1
  print
  print "bash native-profile/packaging/native/check-proximity-input733.sh \"$PWD\" %{_uke_out} linked"
  print "bash native-profile/packaging/native/check-rproc-count733.sh \"$PWD\" %{_uke_out} linked"
  next
 }
 {print}
 END{if(build!=1||check!=1||install!=1||dependency!=1||apply!=1||image!=1||linked!=1)exit 1}
' "$spec" > "$work/spec"
install -m644 "$work/spec" "$spec"
