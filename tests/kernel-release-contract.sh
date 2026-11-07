#!/usr/bin/env bash
# Metadata-only tests. No compiler, hardware, network or installed package changes.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
source "$root/scripts/kernel-release.sh"
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
kernel_release_json "$root/manifests/cumulative-release.json" > /dev/null
plan=$work/fixture.json
jq '.upstream.version="7.3.3"|.full_release=1|
 .upstream.source_url="https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.3.tar.xz"|
 .upstream.signature_url="https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.3.tar.sign"' "$root/manifests/cumulative-release.json" > "$plan"
kernel_release_json "$plan" > "$work/current.json"
jq -e '.kernel_release=="7.3.3-1-unstable" and .audio_driver=="uke7_3_3-1u" and .firmware_alias=="uke7.3.3-1u"' "$work/current.json" >/dev/null
jq '.full_release=34' "$plan" > "$work/plan.json"
kernel_release_json "$work/plan.json" | jq -e '.kernel_release=="7.3.3-34-unstable" and .localversion=="-34-unstable" and .firmware_alias=="uke7.3.3-34u"' >/dev/null
for value in 0 -1 1.5 '"01"' '"1; touch unexpected"';do
 jq --argjson release "$value" '.full_release=$release' "$plan" > "$work/bad.json"
 if kernel_release_json "$work/bad.json" > /dev/null 2>&1;then exit 1;fi
done
for version in 7.3.3-rc1 7.03.3 7.3.3/foreign;do
 jq --arg version "$version" '.upstream.version=$version' "$plan" > "$work/bad.json"
 if kernel_release_json "$work/bad.json" > /dev/null 2>&1;then exit 1;fi
done
package=senemos-uke-linux-kernel-mainline-unstable
printf '{"items":[]}\n' > "$work/history.json"
[[ $(kernel_next_release "$work/history.json" 7.3.3 "$package") == 1 ]]
for count in 1 2 33;do
 jq -n --arg package "$package" --argjson count "$count" '{items:[range(1;($count+1))|{state:"succeeded",source_package:{name:$package,version:("7.3.3-"+tostring),url:"https://example.invalid/source.rpm"}}]}' > "$work/history.json"
 [[ $(kernel_next_release "$work/history.json" 7.3.3 "$package") == $((count+1)) ]]
done
jq '.items|=map(select(.source_package.version!="7.3.3-2"))' "$work/history.json" > "$work/gap.json"
if kernel_next_release "$work/gap.json" 7.3.3 "$package" > /dev/null 2>&1;then exit 1;fi
if kernel_next_release "$work/history.json" 7.3.2 "$package" > /dev/null 2>&1;then exit 1;fi
[[ $(kernel_next_release "$work/history.json" 7.3.4 "$package") == 1 ]]
jq '.items[0].source_package.version="unrecognized"' "$work/history.json" > "$work/bad-history.json"
if kernel_next_release "$work/bad-history.json" 7.3.3 "$package" > /dev/null 2>&1;then exit 1;fi
printf 'Release plan: canonical tuples,1/2/3/34 increments, new-version reset, gap/downgrade/malformed refusal passed.\n'
