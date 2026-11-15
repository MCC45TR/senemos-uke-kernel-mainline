#!/usr/bin/bash
# Metadata only: failed full attempts never allocate the following release.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
plan=$root/manifests/stable734-20261115.json
package=senemos-uke-linux-kernel-mainline-unstable
history() {
 jq -n --arg package "$package" --argjson entries "$1" '{items:[$entries[]|{state:.[0],source_package:{name:$package,version:.[1]}}]}' > "$work/history.json"
}
next() { bash "$root/scripts/kernel-release.sh" next-planned-full "$work/history.json" "$plan"; }
reject() { if "$@" > "$work/rejected" 2>&1; then printf 'Invalid full release history accepted\n' >&2;exit 1;fi; }
history '[]';[[ $(next) == 2 ]]
history '[["failed","7.3.4-2"],["canceled","7.3.4-2"]]';[[ $(next) == 2 ]]
history '[["succeeded","7.3.4-2"]]';[[ $(next) == 3 ]]
history '[["succeeded","7.3.4-2"],["failed","7.3.4-3"]]';[[ $(next) == 3 ]]
history '[["succeeded","7.3.4-2"],["succeeded","7.3.4-3"]]';[[ $(next) == 4 ]]
history '[["succeeded","7.3.4-2"],["succeeded","7.3.4-4"]]';reject next
history '[["running","7.3.4-2"]]';reject next
history '[["succeeded","7.3.5-1"]]';reject next
history '[["succeeded","7.3.4-1"]]';reject next
history '[["succeeded","7.3.3-1"],["succeeded","7.3.3-2"],["failed","7.3.3-3"]]'
[[ $(bash "$root/scripts/kernel-release.sh" next "$work/history.json" 7.3.3 "$package") == 3 ]]
for first in 0 3 '"2"'; do
 jq --argjson first "$first" '.first_full_release=$first' "$plan" > "$work/bad-plan.json"
 reject bash "$root/scripts/kernel-release.sh" next-planned-full "$work/history.json" "$work/bad-plan.json"
done
printf 'Full release policy: explicit first2, failed/canceled retention, success-only advance, gap/active/downgrade refusal and old series default passed; no build or reservation.\n'
