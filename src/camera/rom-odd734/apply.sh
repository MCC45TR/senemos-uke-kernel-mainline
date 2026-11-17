#!/usr/bin/bash
# Admit only the two documented postdivider fields of the original catalog.
set -Eeuo pipefail
[[ $# == 3 ]]
kernel=$(realpath "$1");owner=$(realpath "$2");result=$(realpath -m "$3")
layer=$owner/src/camera/rom-odd734
target=drivers/clk/qcom/provider/camcc-sm7675-crm-rom.h
[[ ! -e $result && ! -L $result ]]
(cd "$kernel";sha256sum -c --strict --quiet "$layer/pre.sha256")
mkdir "$result"
install -Dm644 "$kernel/$target" "$result/before/$target"
patch --batch --fuzz=0 -d "$kernel" -p1 < "$layer/odd.patch"
(cd "$kernel";sha256sum -c --strict --quiet "$layer/post.sha256")
install -Dm644 "$kernel/$target" "$result/inverse/$target"
patch --batch --fuzz=0 --reverse -d "$result/inverse" -p1 < "$layer/odd.patch"
(cd "$result/inverse";sha256sum -c --strict --quiet "$layer/pre.sha256")
cmp "$result/before/$target" "$result/inverse/$target"
(cd "$kernel";sha256sum "$target") > "$result/source.sha256"
