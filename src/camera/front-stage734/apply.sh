#!/usr/bin/bash
# Move the read-only front gate after the native interconnect tag conversion.
set -Eeuo pipefail
[[ $# == 3 ]]
kernel=$(realpath "$1");owner=$(realpath "$2");result=$(realpath -m "$3")
layer=$owner/src/camera/front-stage734
target=arch/arm64/kernel/uke-abl.c
[[ ! -e $result && ! -L $result ]]
(cd "$kernel";sha256sum -c --strict --quiet "$layer/pre.sha256")
mkdir -p "$result/before/arch/arm64/kernel" "$result/inverse/arch/arm64/kernel"
cp "$kernel/$target" "$result/before/$target"
patch --batch --fuzz=0 -d "$kernel" -p1 < "$layer/late-stage.patch"
(cd "$kernel";sha256sum -c --strict --quiet "$layer/post.sha256")
cp "$kernel/$target" "$result/inverse/$target"
patch --batch --fuzz=0 --reverse -d "$result/inverse" -p1 < "$layer/late-stage.patch"
(cd "$result/inverse";sha256sum -c --strict --quiet "$layer/pre.sha256")
cmp "$result/before/$target" "$result/inverse/$target"
(cd "$kernel";sha256sum "$target") > "$result/source.sha256"
