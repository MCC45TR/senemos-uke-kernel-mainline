#!/usr/bin/env bash
# Never replace published binaries; unpublished failed full jobs retain the NVR.
set -Eeuo pipefail
name=${1:?Pass the source package name}
candidate=${2:?Pass the proposed version-release without the Fedora suffix}
[[ $name =~ ^[a-zA-Z0-9+_.-]+$ && $candidate =~ ^[0-9]+([.][0-9]+)*-[1-9][0-9]*$ ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
for project in uke-linux uke-linux-test uke-linux-unstable; do
 offset=0
 while ((offset < 10000)); do
    curl --fail --silent --show-error --location --max-time 45 --get \
        --data-urlencode ownername=mcc45tr --data-urlencode "projectname=$project" \
        --data-urlencode "packagename=$name" --data-urlencode limit=100 --data-urlencode "offset=$offset" \
        https://copr.fedorainfracloud.org/api_3/build/list > "$work/builds.json"
    jq -e '(.items|type)=="array"' "$work/builds.json" > /dev/null
    if [[ $name == senemos-uke-linux-kernel-mainline-unstable ]];then
        jq -e --arg name "$name" 'all(.items[]|select(.source_package.name==$name); .state=="succeeded" or .state=="failed" or .state=="canceled" or .state=="skipped" or .state=="forked")' "$work/builds.json" > /dev/null || {
            echo 'A full kernel job is active; retain its actual handle' >&2; exit 1;
        }
        while IFS=$'\t' read -r id version;do
            [[ $id =~ ^[1-9][0-9]*$ && $version =~ ^[0-9]+([.][0-9]+)*-[0-9]+([.][a-zA-Z0-9]+)*$ ]]
            comparison=$(rpm --eval "%{lua:print(rpm.vercmp(\"$version\", \"$candidate\"))}")
            [[ $comparison =~ ^-?[0-9]+$ ]]
            ((comparison >= 0)) || continue
            curl -q -fsSL --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$id" > "$work/failed.json"
            jq -e '.state=="failed" or .state=="canceled" or .state=="skipped"' "$work/failed.json" >/dev/null
            jq -e '(.chroots|type)=="array" and (.chroots|length)>0' "$work/failed.json" >/dev/null
            while IFS= read -r chroot;do
                [[ $chroot =~ ^[a-zA-Z0-9_-]+$ ]]
                curl -q -fsSL --max-time 45 "https://copr.fedorainfracloud.org/api_3/build-chroot/$id/$chroot" > "$work/chroot.json"
                url=$(jq -er '.result_url' "$work/chroot.json")
                [[ $url == https://download.copr.fedorainfracloud.org/results/mcc45tr/*/ && $url != *'?'* && $url != *'#'* ]]
                curl -q -fsSL --max-time 45 "$url" > "$work/index.html"
                if awk 'BEGIN {RS="<a "} NR>1 {
                    link=$0;sub(/^.*href=/,"",link);sub(/>.*/,"",link);gsub(/[\042\047]/,"",link)
                    if(link ~ /[.]rpm$/ && link !~ /[.](src|nosrc)[.]rpm$/) binary++
                } END {exit !binary}' "$work/index.html";then
                    echo 'Failed build published a binary; its version cannot be reused' >&2;exit 1
                fi
            done < <(jq -er '.chroots[]' "$work/failed.json")
            printf 'Unpublished terminal full build%s retains version%s.\n' "$id" "$version"
        done < <(jq -r --arg name "$name" '.items[]|select(.source_package.name==$name and (.state=="failed" or .state=="canceled" or .state=="skipped") and (.source_package.url|type=="string" and length>0))|[.id,.source_package.version]|@tsv' "$work/builds.json")
    fi
    mapfile -t versions < <(jq -r --arg name "$name" \
        '.items[]|select(.source_package.name==$name and
          (if $name=="senemos-uke-linux-kernel-mainline-unstable" then .state=="succeeded" or .state=="forked"
           else .state=="succeeded" or (.source_package.url | type=="string" and length>0) end))|
          .source_package.version' "$work/builds.json")
    for published in "${versions[@]}"; do
        # Whitelist the complete value before passing it to rpm's Lua evaluator.
        [[ $published =~ ^[0-9]+([.][0-9]+)*-[0-9]+([.][a-zA-Z0-9]+)*$ ]] || {
            echo 'Unrecognized published kernel version; review before rebuilding' >&2; exit 1;
        }
        comparison=$(rpm --eval "%{lua:print(rpm.vercmp(\"$published\", \"$candidate\"))}")
        [[ $comparison =~ ^-?[0-9]+$ ]]
        if ((comparison >= 0)); then
            printf 'Refusing %s: %s published %s is equal or newer; use a fresh kernel release\n' "$candidate" "$project" "$published" >&2
            exit 1
        fi
    done
    count=$(jq -er '.items|length' "$work/builds.json")
    if ((count < 100)); then
        break
    fi
    offset=$((offset + 100))
 done
 ((offset < 10000)) || {
  echo 'Build history limit reached; review before rebuilding' >&2
  exit 1
 }
done
printf 'Fresh kernel release admitted across all COPR projects: %s\n' "$candidate"
