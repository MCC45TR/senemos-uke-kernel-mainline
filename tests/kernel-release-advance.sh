#!/usr/bin/bash
# Pure source/JSON fixture: no compiler, network, package or device operations.
set -Eeuo pipefail
owner=$(realpath "${1:-$(dirname -- "$0")/..}")
version=$(jq -er .upstream.version "$owner/manifests/cumulative-release.json")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/fixture/scripts" "$work/fixture/manifests"
cp "$owner/scripts/kernel-release.sh" "$owner/scripts/advance-kernel-release.sh" "$work/fixture/scripts/"
printf '[]\n' > "$work/fixture/manifests/unrelated-array.json"
jq -n --arg version "$version" '{items:([range(1;7)|{state:"succeeded",source_package:{name:"senemos-uke-linux-kernel-mainline-unstable",version:($version+"-"+tostring)}}]+[{state:"failed",source_package:{name:"senemos-uke-linux-kernel-mainline-unstable",version:($version+"-7"),url:"https://example.invalid/failed.src.rpm"}}]+[range(1;41)|{state:(if .==40 then "failed" else "succeeded" end),source_package:{name:"uke-kernel-migration-check",version:($version+"-"+tostring),url:"https://example.invalid/check.src.rpm"}}])}' > "$work/history.json"
reset_fixture(){
 jq '.full_release=6|.source_check_release=39' "$owner/manifests/cumulative-release.json" > "$work/fixture/manifests/cumulative-release.json"
 first=$(sha256sum "$work/fixture/manifests/cumulative-release.json"); first=${first%% *}
 jq -n --arg hash "$first" '{keep:["all","features"],source_assets:[{path:"manifests/cumulative-release.json",sha256:$hash}]}' > "$work/fixture/manifests/one.json"
 second=$(sha256sum "$work/fixture/manifests/one.json"); second=${second%% *}
 jq -n --arg hash "$second" '{keep:true,source_assets:[{path:"manifests/one.json",sha256:$hash}]}' > "$work/fixture/manifests/two.json"
}
capture(){ (cd "$work/fixture";sha256sum manifests/*.json); }
advance(){ bash "$work/fixture/scripts/advance-kernel-release.sh" "$1" "$work/fixture/manifests/cumulative-release.json"; }
reset_fixture
advance "$work/history.json" > "$work/result.json"
jq -e '.full_release==7 and .source_check_release==41 and .changed_manifests==3 and (.hardware_operation|not)' "$work/result.json" >/dev/null
[[ $(jq -r .source_assets[0].sha256 "$work/fixture/manifests/one.json") == "$(sha256sum "$work/fixture/manifests/cumulative-release.json" | cut -d ' ' -f1)" ]]
[[ $(jq -r .source_assets[0].sha256 "$work/fixture/manifests/two.json") == "$(sha256sum "$work/fixture/manifests/one.json" | cut -d ' ' -f1)" ]]
jq -e '.keep==["all","features"]' "$work/fixture/manifests/one.json" >/dev/null
capture > "$work/before"
advance "$work/history.json" > "$work/result.json"
jq -e '.changed_manifests==0' "$work/result.json" >/dev/null
capture > "$work/after"
cmp "$work/before" "$work/after"
reset_fixture
jq '.source_assets[0].sha256="unreviewed"' "$work/fixture/manifests/one.json" > "$work/tampered.json"
mv "$work/tampered.json" "$work/fixture/manifests/one.json"
capture > "$work/before"
if advance "$work/history.json" > "$work/refusal.log" 2>&1; then exit 1; fi
capture > "$work/after"
cmp "$work/before" "$work/after"
reset_fixture
jq --arg missing "$version-3" '.items|=map(select(.source_package.version!=$missing))' "$work/history.json" > "$work/gap.json"
capture > "$work/before"
if advance "$work/gap.json" > "$work/refusal.log" 2>&1; then exit 1; fi
capture > "$work/after"
cmp "$work/before" "$work/after"
reset_fixture
printf '[\n' > "$work/fixture/manifests/invalid.json"
capture > "$work/before"
if advance "$work/history.json" > "$work/refusal.log" 2>&1; then exit 1; fi
capture > "$work/after"
cmp "$work/before" "$work/after"
rm "$work/fixture/manifests/invalid.json"
printf 'Automatic release plan: failed full stays7, proof41, nested seals, unchanged features, idempotence and refusal-before-write passed.\n'
