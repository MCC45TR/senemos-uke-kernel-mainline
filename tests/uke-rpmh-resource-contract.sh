#!/usr/bin/env bash
# Host-only actual allowlist boundary; does not emulate voltage programming.
set -Eeuo pipefail
source_file=${1:?Pass prepared drivers/regulator/qcom-rpmh-regulator-uke.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
    cat <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstring>
#include <initializer_list>
using std::strcmp;
int admission(const char *name) {
    struct { const char *resource_name; } storage{name};
    auto *aggr_vreg=&storage;
CPP
    awk '/if \(strcmp\(aggr_vreg->resource_name, "cx.lvl"/ {emit=1} emit {print} emit && /return -ENODEV;/ {exit}' "$source_file"
    cat <<'CPP'
    return 0;
}
int main() {
    for(auto name : {"cx.lvl","mx.lvl","lcx.lvl","lmx.lvl","mxc.lvl","mmcx.lvl",
                     "ldob2","ldob3","ldob4","ldob7","ldob17","smpb2","smpb1",
                     "smpb3","smpe3","ldod1","ldob5","ldob12","ldob8","ldod3"})
        assert(admission(name)==0);
    for(auto name : {"","ldob","ldob1","ldob30","ldob3 ","LDOB3","ldoc2",
                     "lcx","ldob19","ldoc3","anything"}) assert(admission(name)==-ENODEV);
}
CPP
} > "$work/check.cpp"
"${CXX:-clang++}" -std=c++20 -O2 -Wall -Wextra -Werror "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual Uke RPMh admission accepts exact ldob3 and retains bounded positive/negative resource scope: passed\n'
