#!/usr/bin/env bash
# Source-worker only; operate after exact retained preimage/patch/postimage checks.
set -Eeuo pipefail
tree=$(realpath "${1:?Prepared profile}")
kind=${2:?native_profile or boot_recipe}
[[ $kind == native_profile || $kind == boot_recipe ]]
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
version=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json" | jq -er .version)
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
while IFS= read -r file;do
 [[ $file != /* && $file != *..* && -f $tree/$file && ! -L $tree/$file ]]
 [[ $version != 7.3.3 ]] || continue
 awk -v version="$version" '
  function replace_literal(s,a,b, p,result) {
   result="";while((p=index(s,a))){result=result substr(s,1,p-1) b;s=substr(s,p+length(a))}return result s
  }
  BEGIN {n=split(version,parts,".");for(i=1;i<=n;i++)escaped=escaped (i>1?"\\.":"") parts[i]}
  {print replace_literal(replace_literal($0,"7.3.3",version),"7\\.3\\.3",escaped)}
 ' "$tree/$file" > "$work/next"
 bash -n "$work/next"
 install -m644 "$work/next" "$tree/$file"
done < <(jq -er --arg kind "$kind" '.version_helper_hashes[$kind]|keys[]' "$tree/manifests/stable733-cumulative-20261107.json")
# The manual read-only observer must follow the compiled ABI, not a stale prefix.
observer=$tree/src/power/uke-cpucp-observe.c
printf '%s  %s\n' 9421e566eb706788884011d465929bf550387f55000152675b46ad6a2465d907 "$observer" | sha256sum -c --strict -
awk '
 /^#include <linux\/utsname.h>$/ {print;print "#include <generated/utsrelease.h>";header++;next}
 /!str_has_prefix\(utsname\(\)->release, "7[.]3[.]1-"\)/ {
  sub(/!str_has_prefix\(utsname\(\)->release, "7[.]3[.]1-"\)/,"strcmp(utsname()->release, UTS_RELEASE)");guard++
 }
 {print} END{if(header!=1||guard!=1)exit 1}
 ' "$observer" > "$work/observer"
install -m644 "$work/observer" "$observer"
printf 'Cumulative source helpers follow %s; compiled observer uses exact UTS_RELEASE, board/protocol gates retained.\n' "$version"
