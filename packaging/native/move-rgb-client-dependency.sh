#!/usr/bin/bash
# Correct the installed7342 recipe before the next cumulative release is folded.
# Source transformation only; does not reserve, rebuild or reuse a published NVR.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' d6cea797020d85b75be31051f0366b3e7c8cf25e2d85ad8dbf666945ad62efd9 "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
awk '
 $0=="%description"&&!header++{
  print "# UKE_RGB_CLIENT_DEPENDENCY_BEGIN"
  print "Requires: uke-control(rgb-charge-status-v1) >= 1"
  print "# UKE_RGB_CLIENT_DEPENDENCY_END"
 }
 $0=="# UKE_STABLE734_FULL_DEP_BEGIN"{if(core!=1)exit 1;skip=1;block++;next}
 $0=="# UKE_STABLE734_FULL_DEP_END"{if(!skip)exit 1;skip=0;next}
 skip{if($0!="Requires: uke-control(rgb-charge-status-v1) >= 1")exit 1;dep++;next}
 $0=="%package core"{core++}
 {print}
 END{if(block!=1||dep!=1||skip||core!=1||header<1)exit 1}
' "$before" > "$after"
awk '
 $0=="# UKE_RGB_CLIENT_DEPENDENCY_BEGIN"{skip=1;next}
 $0=="# UKE_RGB_CLIENT_DEPENDENCY_END"{skip=0;next}
 skip{next}
 {print}
 $0=="%package core"{
  print "# UKE_STABLE734_FULL_DEP_BEGIN"
  print "Requires: uke-control(rgb-charge-status-v1) >= 1"
  print "# UKE_STABLE734_FULL_DEP_END"
 }
' "$after" | cmp - "$before"
rpmspec --target aarch64 --define 'dist .fc46' -q --qf '%{NAME}\t[%{REQUIRENAME} %{REQUIREFLAGS:depflags} %{REQUIREVERSION};]\n' "$after" > "$work/after.requirements"
awk -F '\t' '$1=="senemos-uke-linux-kernel-mainline-unstable"{if(index($2,"uke-control(rgb-charge-status-v1) >= 1;")==0)exit 1;main++}
 $1=="senemos-uke-linux-kernel-mainline-unstable-core"{if(index($2,"uke-control(rgb-charge-status-v1)"))exit 1;core++}
 END{if(main!=1||core!=1)exit 1}' "$work/after.requirements"
printf 'Whole7342 recipe inverse preserved; the desktop kernel metapackage keeps its RGB client requirement and core no longer pulls it into rescue. A new release/build remains required.\n'
