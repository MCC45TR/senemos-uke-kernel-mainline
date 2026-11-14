#!/usr/bin/env bash
# Read every page; truncated metadata must never allocate a release number.
set -Eeuo pipefail
package=${1:?Package}
[[ $package == senemos-uke-linux-kernel-mainline-unstable || $package == uke-kernel-migration-check ]]
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
printf '{"items":[]}\n' > "$work/all.json"
for project in uke-linux uke-linux-test uke-linux-unstable;do
 offset=0
 while ((offset<10000));do
  curl -q -fLsS --max-time 45 --get --data-urlencode ownername=mcc45tr --data-urlencode "projectname=$project" --data-urlencode "packagename=$package" --data-urlencode limit=100 --data-urlencode "offset=$offset" https://copr.fedorainfracloud.org/api_3/build/list > "$work/page.json"
  jq -e '(.items|type)=="array"' "$work/page.json" >/dev/null
  jq -s '{items:([.[].items[]]|unique_by(.id))}' "$work/all.json" "$work/page.json" > "$work/next.json"
  mv "$work/next.json" "$work/all.json"
  (( $(jq -er '.items|length' "$work/page.json") == 100 )) || break
  offset=$((offset+100))
 done
 ((offset<10000)) || { printf 'Build history exceeded its admitted bound\n' >&2;exit 1; }
done
cat "$work/all.json"
