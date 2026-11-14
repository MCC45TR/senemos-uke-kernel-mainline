#!/usr/bin/bash
# Pure text checks on the exact published full10 recipe; no local compilation.
set -Eeuo pipefail
owner=$(realpath "${1:?Source}")
input=$(realpath "${2:?Published full10 spec}")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
adapter=$owner/packaging/native/rewrite-mst-power-full733.sh
plan=$owner/manifests/cumulative-release.json
release=$(jq -er .full_release "$plan")
bash "$adapter" "$input" "$work/full11.spec" "$plan"
awk -v release="$release" '
 $0=="%global senemos_build_release " release {print "%global senemos_build_release 10";next}
 /^# UKE_MST_POWER_DELIVERY$/ {next}
 /^bash native-profile\/packaging\/native\/prepare-mst-power-delivery733.sh / {next}
 $0=="* Mon Nov 09 2026 Uke contributors - 7.3.3-" release {drop=4}
 drop {drop--;next}
 {print}
' "$work/full11.spec" | cmp - "$input"
for mode in release source linked duplicate stable;do
 case $mode in
  release) sed 's/^%global senemos_build_release 10$/%global senemos_build_release 9/' "$input" > "$work/$mode";;
  source) sed '/^bash boot-recipe\/src\/boot\/build-payload.sh /d' "$input" > "$work/$mode";;
  linked) sed '/^bash native-profile\/packaging\/native\/check-rproc-count733.sh .* linked$/d' "$input" > "$work/$mode";;
  duplicate) cat "$input" "$input" > "$work/$mode";;
  stable) sed 's/^Name: senemos-uke-linux-kernel-mainline-unstable$/Name: senemos-uke-linux-kernel-mainline/' "$input" > "$work/$mode";;
 esac
 if bash "$adapter" "$work/$mode" "$work/refused-$mode" "$plan" > "$work/log-$mode" 2>&1;then exit 1;fi
 [[ ! -e $work/refused-$mode ]]
done
if bash "$adapter" "$work/full11.spec" "$work/repeated" "$plan" > "$work/repeated.log" 2>&1;then exit 1;fi
[[ ! -e $work/repeated ]]
jq --argjson release "$((release+1))" '.full_release=$release' "$plan" > "$work/next-plan.json"
bash "$adapter" "$input" "$work/next.spec" "$work/next-plan.json"
grep -Fx "%global senemos_build_release $((release+1))" "$work/next.spec"
printf 'Full11 text inverse, automatic next tuple and six pre-mutation refusals passed; every full10 phase/gate retained.\n'
