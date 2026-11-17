#!/usr/bin/bash
# Prepare only the native PLL parents before decoding firmware CRM ROM.
set -Eeuo pipefail
[[ $# == 3 ]]
kernel=$(realpath "$1");owner=$(realpath "$2");result=$(realpath -m "$3")
layer=$owner/src/camera/native-parent734
[[ ! -e $result && ! -L $result ]]
(cd "$kernel";sha256sum -c --strict --quiet "$layer/pre.sha256")
mkdir "$result"
while read -r digest path;do
 [[ $digest =~ ^[0-9a-f]{64}$ && $path == drivers/clk/qcom/provider/camcc-sm7675-*.h ]]
 install -Dm644 "$kernel/$path" "$result/before/$path"
done < "$layer/pre.sha256"
patch --batch --fuzz=0 -d "$kernel" -p1 < "$layer/parent.patch"
(cd "$kernel";sha256sum -c --strict --quiet "$layer/post.sha256")
while read -r digest path;do
 install -Dm644 "$kernel/$path" "$result/inverse/$path"
done < "$layer/post.sha256"
patch --batch --fuzz=0 --reverse -d "$result/inverse" -p1 < "$layer/parent.patch"
(cd "$result/inverse";sha256sum -c --strict --quiet "$layer/pre.sha256")
diff -ru "$result/before" "$result/inverse"
cp "$layer/post.sha256" "$result/source.sha256"
