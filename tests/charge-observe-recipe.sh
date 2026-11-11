#!/usr/bin/bash
# Data-only recipe tests; no source download, native compilation or boot work.
set -Eeuo pipefail
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
parent=$(realpath "$1")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
manifest=$owner/manifests/charge-observe-delivery-20261111.json
jq '.full_release=23|.source_check_release=95' "$owner/manifests/cumulative-release.json" > "$work/plan.json"
bash "$owner/packaging/native/rewrite-charge-observe-full733.sh" "$parent" "$work/result.spec" "$manifest" "$work/plan.json"
grep -Fxq 'Provides: uke-kernel(charge-protection-observe-v2) = 1' "$work/result.spec"
[[ $(grep -Fc 'charge_observe_parent=$(bash native-profile/packaging/native/charge-observe-legacy-view733.sh "$PWD")' "$work/result.spec") == 2 ]]
[[ $(grep -Fc 'bash native-profile/packaging/native/prepare-charge-observe-full733.sh "$PWD"' "$work/result.spec") == 3 ]]
for mode in wrong-parent wrong-release wrong-proof duplicate-source;do
 cp "$parent" "$work/input.spec"
 cp "$work/plan.json" "$work/bad-plan.json"
 case $mode in
  wrong-parent) printf '\nUnreviewed source\n' >> "$work/input.spec";;
  wrong-release) jq '.full_release=24' "$work/plan.json" > "$work/bad-plan.json";;
  wrong-proof) jq '.source_check_release=96' "$work/plan.json" > "$work/bad-plan.json";;
  duplicate-source) cat "$parent" >> "$work/input.spec";;
 esac
 if bash "$owner/packaging/native/rewrite-charge-observe-full733.sh" "$work/input.spec" "$work/refused.spec" "$manifest" "$work/bad-plan.json" > "$work/$mode.log" 2>&1;then exit 1;fi
 [[ ! -e $work/refused.spec ]]
done
printf 'Protection observation recipe: positive full inverse and four parent/tuple/source refusals passed; data only.\n'
