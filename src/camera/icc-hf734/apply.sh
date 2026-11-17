#!/usr/bin/bash
# Exact two-file layer, with complete byte inverses.
set -Eeuo pipefail
[[ $# == 3 ]]
kernel=$(realpath "$1");owner=$(realpath "$2");result=$(realpath -m "$3")
layer=$owner/src/camera/icc-hf734
[[ ! -e $result && ! -L $result ]]
(cd "$kernel";sha256sum -c --strict --quiet "$layer/pre.sha256")
mkdir "$result"
for file in icc-rpmh.c cliffs-display-icc.h;do
 install -Dm644 "$kernel/drivers/interconnect/qcom/$file" "$result/before/drivers/interconnect/qcom/$file"
done
patch --batch --fuzz=0 -d "$kernel" -p1 < "$layer/icc.patch"
(cd "$kernel";sha256sum -c --strict --quiet "$layer/post.sha256")
for file in icc-rpmh.c cliffs-display-icc.h;do
 install -Dm644 "$kernel/drivers/interconnect/qcom/$file" "$result/inverse/drivers/interconnect/qcom/$file"
done
patch --batch --fuzz=0 --reverse -d "$result/inverse" -p1 < "$layer/icc.patch"
(cd "$result/inverse";sha256sum -c --strict --quiet "$layer/pre.sha256")
diff -r "$result/before" "$result/inverse"
cp "$layer/post.sha256" "$result/source.sha256"
