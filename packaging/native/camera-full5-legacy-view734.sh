#!/usr/bin/bash
# Exact source-only full5 view; all linked objects and images remain production.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
layer=$kernel/camera-full7346/camera-owner734
result=$kernel/camera-owner734-result
work=$kernel/native-generated/camera-full7346
[[ -f $kernel/Makefile && -d $result/inverse ]]
(cd "$kernel";sha256sum -c --strict --quiet "$result/source.sha256" >&2)
(cd "$result/inverse";sha256sum -c --strict --quiet "$layer/src/camera/provider/crm-native734-pre.sha256" >&2)
declare -A before
while read -r digest path;do
 [[ $digest =~ ^[a-f0-9]{64}$ && $path =~ ^drivers/clk/qcom/(camcc-sm7675[.]c|provider/camcc-sm7675-(crm-(ccf|transport)|handoff|registration)[.]h)$ && ! -v before[$path] ]]
 before[$path]=$digest
done < "$layer/src/camera/provider/crm-native734-pre.sha256"
[[ ${#before[@]} == 5 ]]
for name in rom owner startup floor native;do
 before[drivers/clk/qcom/provider/camcc-sm7675-crm-$name.h]=absent
done
mkdir -p "$work"
if [[ -f $work/view.path ]];then
 view=$(cat "$work/view.path")
 [[ $view == "$work"/parent-view.* && -d $view && ! -L $view ]]
else
 view=$(mktemp -d "$work/parent-view.XXXXXX")
 project(){
  local relative=$1 source target entry name child path descend
  source=$kernel/$relative;target=$view/$relative
  mkdir -p "$target"
  for entry in "$source"/* "$source"/.[!.]* "$source"/..?*;do
   [[ -e $entry || -L $entry ]] || continue
   name=$(basename "$entry");[[ $name != .git ]] || continue
   child=$relative/$name;child=${child#/}
   if [[ -v before[$child] ]];then
    [[ ${before[$child]} != absent ]] || continue
    install -m644 "$result/inverse/$child" "$view/$child"
    continue
   fi
   descend=false
   for path in "${!before[@]}";do [[ $path != "$child/"* ]] || descend=true;done
   if $descend;then project "$child";else ln -s "$entry" "$view/$child";fi
  done
 }
 project ''
 git -C "$view" init -q
 printf '%s\n' "$view" > "$work/view.path"
fi
for path in "${!before[@]}";do
 if [[ ${before[$path]} == absent ]];then [[ ! -e $view/$path && ! -L $view/$path ]];
 else printf '%s  %s\n' "${before[$path]}" "$view/$path" | sha256sum -c --strict --quiet - >&2;fi
done
(cd "$kernel";sha256sum -c --strict --quiet "$result/source.sha256" >&2)
printf '%s\n' "$view"
