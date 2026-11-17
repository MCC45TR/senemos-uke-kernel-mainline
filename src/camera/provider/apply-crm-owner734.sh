#!/usr/bin/bash
# COPR-only composition over the exact cumulative provider; retain its sleep PM.
set -Eeuo pipefail
[[ $# == 3 ]]
kernel=$(realpath "$1");owner=$(realpath "$2");result=$(realpath -m "$3")
target=$kernel/drivers/clk/qcom/camcc-sm7675.c
[[ -f $target && ! -L $target && ! -e $result && ! -L $result ]]
printf '%s  %s\n' a12590ce926d3a08a2b651cf49733633d0a0dc270c6f471e7a541f14864f89a7 "$target" | sha256sum -c --strict --quiet -
for name in rom owner startup floor native;do
 [[ ! -e $kernel/drivers/clk/qcom/provider/camcc-sm7675-crm-$name.h ]]
done
for name in core lut passive pm;do
 cmp "$owner/src/camera/provider/camcc-sm7675-crm-$name.h" "$kernel/drivers/clk/qcom/provider/camcc-sm7675-crm-$name.h"
done
mkdir "$result"
cp "$target" "$result/parent-camcc-sm7675.c"
(cd "$kernel";sha256sum drivers/clk/qcom/provider/{camcc-sm7675-crm-guard,camcc-sm7675-crmc-resource,camcc-sm7675-crm-pm,camcc-sm7675-sleep}.h) > "$result/retained.sha256"
(cd "$kernel";sha256sum -c --strict --quiet "$owner/src/camera/provider/crm-native734-pre.sha256")
mkdir "$result/inverse"
while read -r _ file;do
 install -Dm644 "$kernel/$file" "$result/inverse/$file"
done < "$owner/src/camera/provider/crm-native734-pre.sha256"
patch --batch --fuzz=0 -d "$kernel" -p1 < "$owner/src/camera/provider/crm-native734.patch"
(cd "$kernel";sha256sum -c --strict --quiet "$owner/src/camera/provider/crm-native734-post.sha256")
while read -r _ file;do
 install -Dm644 "$kernel/$file" "$result/inverse/$file"
done < "$owner/src/camera/provider/crm-native734-post.sha256"
patch --batch --fuzz=0 --reverse -d "$result/inverse" -p1 < "$owner/src/camera/provider/crm-native734.patch"
(cd "$result/inverse";sha256sum -c --strict --quiet "$owner/src/camera/provider/crm-native734-pre.sha256")
cmp "$result/inverse/drivers/clk/qcom/camcc-sm7675.c" "$result/parent-camcc-sm7675.c"
for name in rom owner startup floor native;do
 install -m644 "$owner/src/camera/provider/camcc-sm7675-crm-$name.h" "$kernel/drivers/clk/qcom/provider/"
done
(cd "$kernel";sha256sum -c --strict --quiet "$result/retained.sha256";sha256sum drivers/clk/qcom/camcc-sm7675.c drivers/clk/qcom/provider/{camcc-sm7675-crm-rom,camcc-sm7675-crm-owner,camcc-sm7675-crm-startup,camcc-sm7675-crm-floor,camcc-sm7675-crm-native,camcc-sm7675-crm-transport,camcc-sm7675-crm-ccf,camcc-sm7675-handoff,camcc-sm7675-registration}.h) > "$result/source.sha256"
