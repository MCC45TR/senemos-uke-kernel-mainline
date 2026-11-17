#!/usr/bin/bash
# Preserve the old source-only view when the passive adapter changes in full8.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
helper=$kernel/camera-full7346/camera-full5-legacy-view734.sh
printf '%s  %s\n' 11f20c91484e61d5b79a310a6abde10970263ec8a94d51ff54d27d535ac233a7 "$helper" | sha256sum -c --strict --quiet - >&2
path=drivers/clk/qcom/provider/camcc-sm7675-crm-passive.h
before=$kernel/camera-parent734-result/inverse/$path
manifest=$kernel/camera-full7348/camera-parent734/src/camera/native-parent734/pre.sha256
old=$(awk -v path="$path" '$2==path{print $1;n++}END{if(n!=1)exit 1}' "$manifest")
[[ $old =~ ^[0-9a-f]{64}$ && -f $before && ! -L $before ]]
printf '%s  %s\n' "$old" "$before" | sha256sum -c --strict --quiet - >&2
(cd "$kernel";sha256sum -c --strict --quiet camera-parent734-result/source.sha256 >&2)
view=$(bash "$helper" "$kernel")
[[ $view == "$kernel/native-generated/camera-full7346/parent-view."* && -d $view && ! -L $view ]]
target=$view/$path
if [[ -L $target ]];then
 [[ $(readlink -f "$target") == "$kernel/$path" ]]
 # Unlink only this owned cache symlink; never write through to production.
 unlink "$target"
 install -m644 "$before" "$target"
else
 [[ -f $target ]]
fi
printf '%s  %s\n' "$old" "$target" | sha256sum -c --strict --quiet - >&2
(cd "$kernel";sha256sum -c --strict --quiet camera-parent734-result/source.sha256 >&2)
printf '%s\n' "$view"
