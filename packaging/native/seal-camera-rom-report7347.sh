#!/usr/bin/bash
# Refresh exactly the reported header entry after verifying its whole inverse.
set -Eeuo pipefail
[[ $# == 2 ]]
kernel=$(realpath "$1");result=$(realpath "$2")
ledger=$kernel/camera-owner734-result/source.sha256
target=drivers/clk/qcom/provider/camcc-sm7675-crm-native.h
[[ -f $ledger && ! -L $ledger && ! -e $result/parent-source.sha256 ]]
cmp "$kernel/$target" "$result/inverse/$target" >/dev/null && exit 1
old=$(sha256sum "$result/inverse/$target" | cut -d' ' -f1)
new=$(sha256sum "$kernel/$target" | cut -d' ' -f1)
[[ $old == edfe80e91f9d0b7bf6c45662552f9d67db0519f387fed85d02a828a911b24294 ]]
cp "$ledger" "$result/parent-source.sha256"
awk -v path="$target" -v old="$old" -v new="$new" '
 $2==path{if($1!=old)exit 1;printf "%s  %s\n",new,path;n++;next}{print}END{if(n!=1)exit 1}
' "$ledger" > "$result/current-source.sha256"
sed "s|^$new  $target\$|$old  $target|" "$result/current-source.sha256" | cmp - "$ledger"
install -m644 "$result/current-source.sha256" "$ledger"
(cd "$kernel";sha256sum -c --strict --quiet "$ledger" "$result/source.sha256")
