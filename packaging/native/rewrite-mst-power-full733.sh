#!/usr/bin/bash
# Pure text adapter: preserve the admitted full10 recipe and every existing gate.
set -Eeuo pipefail
[[ $# == 3 ]]
input=${1:?Admitted full10 spec}
output=${2:?New full spec}
tuple=$(bash "$(dirname -- "$0")/../../scripts/kernel-release.sh" json "${3:?Cumulative release plan}")
release=$(jq -er '.release|select(.>=11)' <<< "$tuple")
[[ $(jq -er .version <<< "$tuple") == 7.3.3 ]]
[[ -f $input && ! -L $input && ! -e $output && ! -L $output ]]
printf '%s  %s\n' 5a99594006a2719f5cfcfe409faa4fb44d662a964d08cb71a0ebffdcd304a1cf "$input" | sha256sum -c --strict --quiet -
awk -v release="$release" '
 $0=="%global senemos_build_release 10" {print "%global senemos_build_release " release;r++;next}
 $0=="bash boot-recipe/src/boot/build-payload.sh \"$PWD\" %{_uke_out} %{uke_boot_userspace}/base '\''%{krel}'\'' \"$jobs\"" {
  print "# UKE_MST_POWER_DELIVERY"
  print "bash native-profile/packaging/native/prepare-mst-power-delivery733.sh \"$PWD\" %{_uke_out} source"
  p++
 }
 $0=="bash native-profile/packaging/native/check-rproc-count733.sh \"$PWD\" %{_uke_out} linked" {
  print
  print "bash native-profile/packaging/native/prepare-mst-power-delivery733.sh \"$PWD\" %{_uke_out} linked"
  l++;next
 }
 $0=="%changelog" {
  print
  print "* Mon Nov 09 2026 Uke contributors - 7.3.3-" release
  print "- Deliver qualified per-stream MST depth and responsive saver CPU QoS."
  print "- Preserve SST, audio protection, cumulative checks and recovery interfaces."
  print ""
  c++;next
 }
 {print}
 END{if(r!=1||p!=1||l!=1||c!=1)exit 1}
' "$input" > "$output"
for phase in prep build check install;do
 [[ $(grep -Fxc "%$phase" "$output") == 1 ]]
done
[[ $(grep -Fc 'prepare-mst-power-delivery733.sh' "$output") == 2 ]]
