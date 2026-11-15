#!/usr/bin/bash
# Text-only full-spec integration. Never builds, installs or changes the target.
set -Eeuo pipefail
[[ $# == 1 ]]
spec=$(realpath "${1:?Cumulative full spec}")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
[[ -f $spec && ! -L $spec ]]
[[ $(grep -Fxc 'Name: senemos-uke-linux-kernel-mainline-unstable' "$spec") == 1 ]]
[[ $(grep -Fxc '%global debug_package %{nil}' "$spec") == 1 ]]
! grep -Eq 'dual-light-(delivery|legacy)|apply-dual-light733' "$spec"
awk '
 $0=="%build" {phase="build";build++}
 $0=="%check" {
   phase="check";check++;print
   print "bash native-profile/packaging/native/check-dual-light-delivery733.sh \"$PWD\" %{_uke_out} linked"
   print "bash native-profile/packaging/native/check-dual-light-binding733.sh \"$PWD\" objects"
   next
 }
 $0=="bash native-profile/packaging/native/check-hall-initial733.sh \"$PWD\" %{_uke_out} prepared" {
   if(phase!="build")exit 1
   print
   print "bash native-profile/packaging/native/check-dual-light-binding733.sh \"$PWD\" prepared"
   print "bash native-profile/packaging/native/check-dual-light-events733.sh \"$PWD\" %{_uke_out} prepared"
   print "bash native-profile/packaging/native/check-ssc-stream-owners733.sh \"$PWD\" %{_uke_out} prepared"
   print "bash native-profile/packaging/native/check-dual-light-endpoint733.sh \"$PWD\" %{_uke_out} prepared"
   print "bash native-profile/packaging/native/check-dual-light-delivery733.sh \"$PWD\" %{_uke_out} prepared"
   prepared++;next
 }
 /^bash boot-recipe\/src\/boot\/build-payload.sh / {
   if(phase!="build"||prepared!=1)exit 1
   print "bash native-profile/src/sensors/apply-dual-light733.sh \"$PWD\""
   applied++;print;next
 }
 $0=="cmp native-profile/src/sensors/uke-ssc-iio.c drivers/iio/common/uke-ssc/uke-ssc-iio.c" {
   if(phase=="build"){retained++;print;next}
   if(phase!="check")exit 1
   print "dual_light_legacy=$(bash native-profile/packaging/native/dual-light-legacy-view733.sh \"$PWD\")"
   print "cmp native-profile/src/sensors/uke-ssc-iio.c \"$dual_light_legacy/drivers/iio/common/uke-ssc/uke-ssc-iio.c\""
   inverse++;next
 }
 {print}
 END{if(build!=1||check!=1||prepared!=1||applied!=1||retained!=2||inverse!=1)exit 1}
' "$spec" > "$work/full.spec"
# The compiler and legacy prepared checks must precede the real production
# source application; every linked check sees the actual new Image/modules.
awk '
 $0=="%build" {b=NR}
 /check-migration-cohort731.sh.* prepared$/ {p=NR;pc++}
 /check-dual-light-delivery733.sh.* prepared$/ {d=NR;dc++}
 /src\/sensors\/apply-dual-light733.sh/ {a=NR;ac++}
 /^bash boot-recipe\/src\/boot\/build-payload.sh / {i=NR;ic++}
 $0=="%check" {c=NR}
 /check-dual-light-delivery733.sh.* linked$/ {l=NR;lc++}
 /check-migration-cohort731.sh.* linked$/ {o=NR;oc++}
 /^dual_light_legacy=/ {v=NR;vc++}
 END{if(pc!=1||dc!=1||ac!=1||ic!=1||lc!=1||oc!=1||vc!=1||!(b<p&&p<d&&d<a&&a<i&&i<c&&c<l&&l<o&&o<v))exit 1}
' "$work/full.spec"
install -m644 "$work/full.spec" "$spec"
printf 'Cumulative full spec retains legacy prepared gates, applies native source before Image/modules and checks the actual postimage before linked legacy views.\n'
