#!/usr/bin/bash
# Host/COPR only: replace the exact inherited provider after all parent checks.
set -Eeuo pipefail
[[ $# == 2 ]]
kernel=$(realpath "$1");result=$(realpath -m "$2")
here=$(cd -- "$(dirname -- "$0")/.." && pwd)
target=$kernel/drivers/clk/qcom/uke-dispcc-votes.c
[[ -f $target && ! -L $target && ! -e $result && ! -L $result ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
awk '
 /\/\* ABL still scans out: cache the inherited MDP config without parking it\. \*\//{comment++;next}
 $0=="\tuke_shared_ops = clk_rcg2_shared_no_init_park_ops;"{$0="\tuke_shared_ops = clk_rcg2_shared_ops;";changed++}
 {print}
 END{if(comment!=1||changed!=1)exit 1}
' "$here/uke-dispcc-votes.c" > "$work/parent.c"
cmp "$target" "$work/parent.c"
grep -Fq 'const struct clk_ops clk_rcg2_shared_no_init_park_ops = {' "$kernel/drivers/clk/qcom/clk-rcg2.c"
mkdir "$result"
cp "$target" "$result/parent-uke-dispcc-votes.c"
install -m644 "$here/uke-dispcc-votes.c" "$target"
(cd "$kernel";sha256sum drivers/clk/qcom/uke-dispcc-votes.c drivers/clk/qcom/clk-rcg2.c) > "$result/source.sha256"
