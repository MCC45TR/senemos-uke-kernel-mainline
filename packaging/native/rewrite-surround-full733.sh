#!/usr/bin/bash
# Data-only adapter: retain the admitted full11 recipe and all its gates.
set -Eeuo pipefail
[[ $# == 3 ]]
input=$1
output=$2
tuple=$(bash "$(dirname -- "$0")/../../scripts/kernel-release.sh" json "$3")
release=$(jq -er '.release|select(.>=12)' <<< "$tuple")
[[ $(jq -er .version <<< "$tuple") == 7.3.3 && -f $input && ! -e $output ]]
printf '%s  %s\n' 3d667256af3ecb7b47103258a62fc4b1c3b806ef78dd0b05d91c73bef8b97011 "$input" | sha256sum -c --strict --quiet -
awk -v release="$release" '
 $0=="%global senemos_build_release 11" {print "%global senemos_build_release "release;r++;next}
 $0=="bash boot-recipe/src/boot/build-payload.sh \"$PWD\" %{_uke_out} %{uke_boot_userspace}/base '\''%{krel}'\'' \"$jobs\"" {
  print "bash native-profile/packaging/native/prepare-surround-full733.sh \"$PWD\" %{_uke_out} source";s++
 }
 $0=="bash native-profile/packaging/native/prepare-mst-power-delivery733.sh \"$PWD\" %{_uke_out} linked" {
  print;print "bash native-profile/packaging/native/prepare-surround-full733.sh \"$PWD\" %{_uke_out} linked";l++;next
 }
 $0=="bash native-profile/src/audio/desktop/install-policy.sh '\''%{buildroot}'\'' '\''%{krel}'\''" {
  print;print "bash native-profile/packaging/native/prepare-surround-full733.sh \"$PWD\" %{_uke_out} install '\''%{buildroot}'\''";i++;next
 }
 $0=="%changelog" {
  print;print "* Tue Nov 10 2026 Uke contributors - 7.3.3-"release
  print "- Render six/eight program channels to four protected internal speakers."
  print "- Freeze amplifier work across system sleep and retain the quad fallback."
  print "";c++;next
 }
 {print}
 END{if(r!=1||s!=1||l!=1||i!=1||c!=1)exit 1}
' "$input" > "$output"
for phase in prep build check install;do [[ $(grep -Fxc "%$phase" "$output") == 1 ]];done
[[ $(grep -Fc 'prepare-surround-full733.sh' "$output") == 3 ]]
