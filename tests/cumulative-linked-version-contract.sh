#!/usr/bin/env bash
# Execute the actual five linked-version guards, without native compilation.
set -Eeuo pipefail
profile=$(realpath "${1:?Prepared cumulative profile}")
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/profile/scripts" "$work/profile/manifests"
cp "$profile/scripts/kernel-release.sh" "$work/profile/scripts/"
cp "$profile/manifests/cumulative-release.json" "$work/profile/manifests/"
cases=0
while IFS= read -r file;do
 [[ $file != /* && $file != *..* && -f $profile/$file ]]
 mkdir -p "$work/profile/$(dirname -- "$file")"
 awk '
  /^[[:space:]]*release_owner=\$\(cd / {emit=1}
  emit {print;n++}
  emit&&n==3 {exit}
  END{if(n!=3)exit 1}' "$profile/$file" > "$work/guard"
 grep -Eq '^[[:space:]]*\[\[ \$release == "\$expected_release" \]\]$' "$work/guard"
 { printf '%s\n' 'set -Eeuo pipefail' 'release=${1:?Kernel release}';cat "$work/guard"; } > "$work/profile/$file"
 current=$(bash "$profile/scripts/kernel-release.sh" json "$profile/manifests/cumulative-release.json" | jq -er .kernel_release)
 bash "$work/profile/$file" "$current";cases=$((cases+1))
 for bad in 7.3.1-12217-unstable "${current%-unstable}" "$current-extra" 7.3.3-01-unstable 7.3.3-0-unstable;do
  if bash "$work/profile/$file" "$bad" > /dev/null 2>&1;then exit 1;fi
  cases=$((cases+1))
 done
 jq '.full_release=34' "$profile/manifests/cumulative-release.json" > "$work/profile/manifests/cumulative-release.json"
 version=$(jq -er .upstream.version "$profile/manifests/cumulative-release.json")
 bash "$work/profile/$file" "$version-34-unstable";cases=$((cases+1))
 cp "$profile/manifests/cumulative-release.json" "$work/profile/manifests/"
 bash -n "$profile/$file"
done < <(jq -er '.linked_helper_hashes|keys[]' "$profile/manifests/stable733-cumulative-20261107.json")
[[ $cases == 35 ]]
grep -F 'LOCALVERSION="-${release#*-}"' "$profile/tests/msm-kms-alternate-build.sh"
printf 'Actual linked version guards: five helpers,35 current/future/refusal cases and complete KMS LOCALVERSION passed; no hardware operation.\n'
