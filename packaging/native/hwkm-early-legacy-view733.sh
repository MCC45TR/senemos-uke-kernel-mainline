#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Exact source-only full26 view. No object, module or Image is copied/replaced.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
work=$kernel/native-generated/hwkm-early733
manifest=$kernel/crm-passive/manifests/camera-crm-passive-20261114.json
[[ -f $work/source-complete ]]
(cd "$kernel"; sha256sum -c --strict --quiet "$work/after.sha256" >&2)
declare -A before
while IFS=$'\t' read -r path digest; do
 [[ $path =~ ^drivers/clk/qcom/[a-zA-Z0-9_.,/-]+[.](c|h)$ && $path != *..* ]]
 before[$path]=$digest
done < <(jq -er '.runtime_units[]|[.path,.before_sha256]|@tsv' "$manifest")
if [[ -f $work/view.path ]]; then
 view=$(cat "$work/view.path")
 [[ $view == "$work"/parent-view.* && -d $view ]]
else
 view=$(mktemp -d "$work/parent-view.XXXXXX")
 project() {
  local relative=$1 source target entry name child path descend
  source=$kernel/$relative; target=$view/$relative
  mkdir -p "$target"
  for entry in "$source"/* "$source"/.[!.]* "$source"/..?*; do
   [[ -e $entry || -L $entry ]] || continue
   name=$(basename "$entry"); [[ $name != .git ]] || continue
   child=$relative/$name; child=${child#/}
   if [[ -v before[$child] ]]; then
    [[ ${before[$child]} != absent ]] || continue
    install -m644 "$work/before/$child" "$view/$child"
    continue
   fi
   descend=false
   for path in "${!before[@]}"; do [[ $path != "$child/"* ]] || descend=true; done
   if $descend; then project "$child"; else ln -s "$entry" "$view/$child"; fi
  done
 }
 project ''
 git -C "$view" init -q
 printf '%s\n' "$view" > "$work/view.path"
fi
for path in "${!before[@]}"; do
 if [[ ${before[$path]} == absent ]]; then [[ ! -e $view/$path && ! -L $view/$path ]];
 else printf '%s  %s\n' "${before[$path]}" "$view/$path" | sha256sum -c --strict --quiet - >&2; fi
done
(cd "$kernel"; sha256sum -c --strict --quiet "$work/after.sha256" >&2)
printf '%s\n' "$view"
