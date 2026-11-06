#!/usr/bin/env bash
# Source-only: preserve the historical CDSP snapshot gate and extend it exactly.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
spec=$(realpath -ms "${1:?Production kernel spec}")
history=$spec.before-governor-options.txt
for file in "$spec" "$history"; do
    path=$file
    while [[ $path != / ]]; do [[ ! -L $path ]]; path=${path%/*}; [[ -n $path ]] || path=/; done
done
[[ -f $spec && $(stat -c %h "$spec") == 1 ]]
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
derive()
{
    awk '
     /^for role in cdsp waydroid; do$/ {
       print "# UKE_GOVERNOR_REFERENCE_EXTENSION_731"
       print "for role in cdsp waydroid cdsp-before; do";loops++;next
     }
     /^  cp "native-profile\/configs\/nfc-\$role-reference.config" "\$ref\/.config"$/ {
       print "  if [[ $role == cdsp-before ]]; then"
       print "    cp native-profile/configs/governor-before-nfc-cdsp.config \"$ref/.config\""
       print "  else"; print; print "  fi";copies++;next
     }
     /^bash native-profile\/tests\/cdsp-pogo-config-contract.sh native-generated\/nfc-cdsp-reference\/.config$/ {
       print "bash native-profile/tests/cdsp-pogo-config-contract.sh native-generated/nfc-cdsp-before-reference/.config"
       print "bash native-profile/tests/governor-config-contract.sh native-generated/nfc-cdsp-before-reference/.config native-generated/nfc-cdsp-reference/.config"
       gates++;next
     }
     {print}
     END {if(loops!=1 || copies!=1 || gates!=2)exit 1}
    ' "$1"
}
if grep -Fq '# UKE_GOVERNOR_REFERENCE_EXTENSION_731' "$spec"; then
    [[ -f $history && ! -L $history && $(stat -c %h "$history") == 1 ]]
    derive "$history" > "$stage/expected"
    cmp "$stage/expected" "$spec"
    printf '%s\n' 'Governor spec extension already exact; no mutation'
    exit 0
fi
[[ ! -e $history && ! -L $history ]]
derive "$spec" > "$stage/next"
install -m644 "$spec" "$history"
install -m644 "$stage/next" "$spec"
printf '%s\n' 'Production spec: original CDSP snapshot checked independently; exact four-option delta checked in both build and final check'
