#!/usr/bin/bash
# Authenticated text projection for retained full17 checks. Never replaces objects.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
profile=$kernel/native-profile
contract=$profile/manifests/ssc-proximity-abi-20261110.json
work=$kernel/native-generated/ssc-proximity-abi733
driver=drivers/iio/common/uke-ssc/uke-ssc-iio.c
abi=Documentation/ABI/testing/sysfs-driver-uke-ssc-proximity-input
[[ -s $work/applied.sha256 && -s $work/before.c ]]
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
printf '%s  %s\n' "$(jq -er '.source_units[0].after_sha256' "$contract")" "$kernel/$driver" | sha256sum -c --strict --quiet -
printf '%s  %s\n' 699acd3d4cb972e037613b8bf9328d5ebaa5480df35a4436ee57f5864fd84863 "$kernel/$abi" | sha256sum -c --strict --quiet -
inverse=$(mktemp -d)
trap 'find "$inverse" -depth -delete' EXIT
for file in "$driver" "$abi";do install -Dm644 "$kernel/$file" "$inverse/$file";done
git -C "$inverse" init -q
git -C "$inverse" apply -R --check --whitespace=error "$profile/src/sensors/0018-ssc-proximity-input-abi.patch"
git -C "$inverse" apply -R --whitespace=error "$profile/src/sensors/0018-ssc-proximity-input-abi.patch"
cmp "$work/before.c" "$inverse/$driver"
[[ ! -e $inverse/$abi ]]
printf '%s  %s\n' "$(jq -er '.source_units[0].before_sha256' "$contract")" "$inverse/$driver" | sha256sum -c --strict --quiet -
view=$(mktemp -d "$kernel/native-generated/proximity-abi-parent-view.XXXXXX")
project(){
 local relative=$1 source target entry name child path descend
 source=$kernel/$relative
 target=$view/$relative
 mkdir -p "$target"
 for entry in "$source"/* "$source"/.[!.]* "$source"/..?*;do
  [[ -e $entry || -L $entry ]] || continue
  name=$(basename "$entry");[[ $name != .git ]] || continue
  child=$relative/$name;child=${child#/}
  [[ $child != "$abi" ]] || continue
  if [[ $child == "$driver" ]];then install -m644 "$inverse/$driver" "$view/$driver";continue;fi
  descend=false
  for path in "$driver" "$abi";do [[ $path != "$child/"* ]] || descend=true;done
  if $descend;then project "$child";else ln -s "$entry" "$view/$child";fi
 done
}
project ''
cmp "$inverse/$driver" "$view/$driver"
[[ ! -e $view/$abi ]]
git -C "$view" init -q
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
printf '%s\n' "$view"
