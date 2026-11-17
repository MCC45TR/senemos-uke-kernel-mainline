#!/usr/bin/bash
# Exact single-file overlay, with its complete inverse retained.
set -Eeuo pipefail
[[ $# == 3 ]]
kernel=$(realpath "$1");owner=$(realpath "$2");result=$(realpath -m "$3")
layer=$owner/src/camera/csid-irq734
target=drivers/media/platform/qcom/camss/camss-csid-gen3.c
[[ ! -e $result && ! -L $result ]]
(cd "$kernel";sha256sum -c --strict --quiet "$layer/pre.sha256")
mkdir "$result"
install -Dm644 "$kernel/$target" "$result/before/$target"
patch --batch --fuzz=0 -d "$kernel" -p1 < "$layer/irq.patch"
(cd "$kernel";sha256sum -c --strict --quiet "$layer/post.sha256")
install -Dm644 "$kernel/$target" "$result/inverse/$target"
patch --batch --fuzz=0 --reverse -d "$result/inverse" -p1 < "$layer/irq.patch"
(cd "$result/inverse";sha256sum -c --strict --quiet "$layer/pre.sha256")
cmp "$result/before/$target" "$result/inverse/$target"
(cd "$kernel";sha256sum "$target") > "$result/source.sha256"
