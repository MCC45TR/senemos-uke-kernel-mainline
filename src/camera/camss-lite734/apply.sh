#!/usr/bin/bash
# Exact one-file source change. No graph, MMIO, power or capture operation.
set -Eeuo pipefail
[[ $# == 3 ]]
kernel=$(realpath "$1");owner=$(realpath "$2");result=$(realpath -m "$3")
file=drivers/media/platform/qcom/camss/camss-vfe-gen3.c
[[ -f $kernel/$file && ! -L $kernel/$file && ! -e $result && ! -L $result ]]
(cd "$kernel";sha256sum -c --strict --quiet "$owner/src/camera/camss-lite734/pre.sha256")
install -d "$result/before/$(dirname "$file")" "$result/inverse/$(dirname "$file")"
cp "$kernel/$file" "$result/before/$file"
patch --batch --fuzz=0 -p1 -d "$kernel" < "$owner/src/camera/camss-lite734/lite-testbus.patch"
(cd "$kernel";sha256sum -c --strict --quiet "$owner/src/camera/camss-lite734/post.sha256")
cp "$kernel/$file" "$result/inverse/$file"
patch --batch --fuzz=0 --reverse -p1 -d "$result/inverse" < "$owner/src/camera/camss-lite734/lite-testbus.patch"
cmp "$result/before/$file" "$result/inverse/$file"
(cd "$kernel";sha256sum "$file") > "$result/source.sha256"
