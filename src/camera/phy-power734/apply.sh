#!/usr/bin/bash
# Exact source overlay; no graph, firmware, sensor or hardware activation.
set -Eeuo pipefail
[[ $# == 3 ]]
kernel=$(realpath "$1");owner=$(realpath "$2");result=$(realpath -m "$3")
layer=$owner/src/camera/phy-power734
[[ ! -e $result && ! -L $result ]]
(cd "$kernel";sha256sum -c --strict --quiet "$layer/pre.sha256")
[[ ! -e $kernel/drivers/media/platform/qcom/camss/camss-csiphy-sm7675-power.h ]]
[[ ! -e $kernel/include/linux/soc/qcom/sm7675-camcc.h ]]
install -d "$result/before" "$result/inverse"
while read -r digest file;do
 [[ $digest =~ ^[a-f0-9]{64}$ && $file =~ ^drivers/[a-zA-Z0-9_./+-]+$ && ! -L $kernel/$file ]]
 install -Dm644 "$kernel/$file" "$result/before/$file"
done < "$layer/pre.sha256"
patch --batch --fuzz=0 -p1 -d "$kernel" < "$layer/power.patch"
install -Dm644 "$layer/camss-csiphy-sm7675-power.h" "$kernel/drivers/media/platform/qcom/camss/camss-csiphy-sm7675-power.h"
install -Dm644 "$layer/sm7675-camcc.h" "$kernel/include/linux/soc/qcom/sm7675-camcc.h"
(cd "$kernel";sha256sum -c --strict --quiet "$layer/post.sha256")
while read -r digest file;do
 install -Dm644 "$kernel/$file" "$result/inverse/$file"
done < "$layer/pre.sha256"
patch --batch --fuzz=0 --reverse -p1 -d "$result/inverse" < "$layer/power.patch"
while read -r digest file;do cmp "$result/before/$file" "$result/inverse/$file";done < "$layer/pre.sha256"
cp "$layer/post.sha256" "$result/source.sha256"
