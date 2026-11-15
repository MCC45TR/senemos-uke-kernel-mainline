#!/usr/bin/bash
# Source planning only. The coordinator must hold the shared delivery lock.
set -Eeuo pipefail
[[ $# == 2 ]]
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
history=$(realpath "${1:?Complete current COPR history}")
plan=$(realpath "${2:?Cumulative release plan}")
[[ ${plan%/*} == "$owner/manifests" ]]
relative=manifests/${plan##*/}
version=$(bash "$owner/scripts/kernel-release.sh" json "$plan" | jq -er .version)
full=$(bash "$owner/scripts/kernel-release.sh" next "$history" "$version" senemos-uke-linux-kernel-mainline-unstable)
check=$(bash "$owner/scripts/kernel-release.sh" next "$history" "$version" uke-kernel-migration-check)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$work/manifests"
cp "$owner"/manifests/*.json "$work/manifests/"
before=$(sha256sum "$plan"); before=${before%% *}
jq --argjson full "$full" --argjson check "$check" '.full_release=$full|.source_check_release=$check' "$plan" > "$work/$relative"
after=$(sha256sum "$work/$relative"); after=${after%% *}
if [[ $before == "$after" ]]; then
 jq -n --argjson full "$full" --argjson check "$check" '{full_release:$full,source_check_release:$check,changed_manifests:0,hardware_operation:false}'
 exit 0
fi
jq -n --arg path "$relative" --arg before "$before" --arg after "$after" '{($path):{before:$before,after:$after,known:[$before,$after]}}' > "$work/changes.json"
stable=false
for ((pass=0;pass<64;pass++)); do
 edited=false
 for file in "$work"/manifests/*.json; do
  if jq -e --slurpfile changes "$work/changes.json" '
   if type!="object" or .source_assets==null then false
   elif (.source_assets|type)!="array" then error("Invalid source_assets type")
   else any(.source_assets[]; $changes[0][.path]!=null) end' "$file" >/dev/null; then
   :
  else
   status=$?
   [[ $status == 1 ]] || exit "$status"
   continue
  fi
  jq --slurpfile changes "$work/changes.json" '
   .source_assets|=map(. as $row|$changes[0][.path] as $change|
    if $change==null then .
    elif ($change.known|index($row.sha256))==null then error("Unreviewed dependency hash")
    else .sha256=$change.after end)' "$file" > "$work/updated.json"
  cmp -s "$file" "$work/updated.json" && continue
  name=manifests/${file##*/}
  previous=$(sha256sum "$file"); previous=${previous%% *}
  next=$(sha256sum "$work/updated.json"); next=${next%% *}
  jq --arg path "$name" --arg previous "$previous" --arg next "$next" '
   .[$path] as $old|.[$path]={before:($old.before//$previous),after:$next,
    known:((($old.known//[])+[$previous,$next])|unique)}' "$work/changes.json" > "$work/next.json"
  mv "$work/next.json" "$work/changes.json"
  mv "$work/updated.json" "$file"
  edited=true
 done
 if [[ $edited == false ]]; then stable=true; break; fi
done
[[ $stable == true ]] || { printf 'Manifest dependency cycle; no source files changed\n' >&2; exit 1; }
# Only the plan and its reviewed hash dependents change; never refresh an
# unrelated source hash or use this operation as admission for modified code.
while IFS= read -r name; do
 [[ $name == manifests/*.json && $name != *..* ]]
 install -m644 "$work/$name" "$owner/$name"
done < <(jq -r 'keys[]' "$work/changes.json")
jq -n --argjson full "$full" --argjson check "$check" --slurpfile changes "$work/changes.json" '{full_release:$full,source_check_release:$check,changed_manifests:($changes[0]|length),hardware_operation:false}'
