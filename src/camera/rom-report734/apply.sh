#!/usr/bin/bash
# Apply only error-path reporting over the qualified native22 header.
set -Eeuo pipefail
[[ $# == 3 ]]
kernel=$(realpath "$1");owner=$(realpath "$2");result=$(realpath -m "$3")
layer=$owner/src/camera/rom-report734
target=drivers/clk/qcom/provider/camcc-sm7675-crm-native.h
[[ ! -e $result && ! -L $result ]]
(cd "$kernel";sha256sum -c --strict --quiet "$layer/pre.sha256")
[[ ! -e $kernel/drivers/clk/qcom/provider/rom-report.h ]]
mkdir "$result"
install -Dm644 "$kernel/$target" "$result/before/$target"
patch --batch --fuzz=0 -d "$kernel" -p1 < "$layer/report.patch"
(cd "$kernel";sha256sum -c --strict --quiet "$layer/post.sha256")
install -Dm644 "$kernel/$target" "$result/inverse/$target"
patch --batch --fuzz=0 --reverse -d "$result/inverse" -p1 < "$layer/report.patch"
(cd "$result/inverse";sha256sum -c --strict --quiet "$layer/pre.sha256")
cmp "$result/inverse/$target" "$result/before/$target"
install -m644 "$layer/rom-report.h" "$kernel/drivers/clk/qcom/provider/rom-report.h"
(cd "$kernel";sha256sum "$target" drivers/clk/qcom/provider/rom-report.h) > "$result/source.sha256"
