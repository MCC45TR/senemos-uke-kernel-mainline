#!/usr/bin/env bash
# Host-only checks of the exact native regulator admission expression.
set -Eeuo pipefail
file=${1:?Pass the prepared Uke regulator source}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
    cat <<'C'
#include <assert.h>
#include <errno.h>
#include <string.h>
static int admitted(const char *name) {
    struct { const char *resource_name; } storage = { name }, *aggr_vreg = &storage;
C
    awk '/if \(strcmp\(aggr_vreg->resource_name, "cx.lvl"\)/ {emit=1}
         emit {print} emit && /return -ENODEV;/ {exit}' "$file"
    cat <<'C'
    return 0;
}
int main(void) {
    assert(admitted("mmcx.lvl")==0 && admitted("ldob8")==0);
    assert(admitted("cx.lvl")==0 && admitted("mx.lvl")==0 && admitted("ldob2")==0 && admitted("ldob4")==0);
    assert(admitted("mmcx")==-ENODEV && admitted("mmcx.lvl.extra")==-ENODEV);
    assert(admitted("ldob9")==-ENODEV && admitted("ldob80")==-ENODEV && admitted("")==-ENODEV);
}
C
} > "$work/check.c"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror "$work/check.c" -o "$work/check"
"$work/check"
printf 'Native display: exact MMCX and L8B admission with unrelated resources rejected passed\n'
