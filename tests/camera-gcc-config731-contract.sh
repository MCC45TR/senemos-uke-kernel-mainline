#!/usr/bin/env bash
# COPR only: actual GCC probe, original failure, strict register/fault boundaries.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
source_file=${1:?Prepared gcc-cliffs.c}
before_file=${2:?Original prepared GCC without camera configuration gates}
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
compiler=${CXX:-clang++}
extra=()
[[ -z ${CAMERA_GCC_TEST_FLAGS:-} ]] || read -r -a extra <<< "$CAMERA_GCC_TEST_FLAGS"
cat > "$work/prefix.cpp" <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstdint>
#include <cstdio>
struct device {};
struct platform_device { device dev; };
struct regmap {};
static int gcc_cliffs_desc;
static bool gcc_cliffs_proxy_active;
static regmap map;
static int fault, writes, votes, registrations, actions;
static constexpr unsigned expected[] = {0x26004, 0x26028, 0x2602c, 0x32004, 0x32030};
static constexpr unsigned BIT(unsigned n) { return 1u << n; }
static regmap *error_pointer() { return reinterpret_cast<regmap *>(uintptr_t(1)); }
static bool IS_ERR(regmap *p) { return p == error_pointer(); }
static int PTR_ERR(regmap *) { return -ENODEV; }
static int clk_regulator_init(device *, int *) { return fault == 1 ? -EPROBE_DEFER : 0; }
static void gcc_cliffs_vdd_release(void *) {}
static int devm_add_action_or_reset(device *, void (*)(void *), void *) {
    ++actions; return fault == 2 ? -ENOMEM : 0;
}
static regmap *qcom_cc_map(platform_device *, int *) {
    return fault == 3 ? error_pointer() : &map;
}
static int regmap_update_bits(regmap *m, unsigned reg, unsigned mask, unsigned value) {
    assert(m == &map && mask == BIT(0) && value == BIT(0));
    assert(writes < 5 && reg == expected[writes]);
    ++writes;
    return fault == 3 + writes ? -EREMOTEIO : 0;
}
static int clk_vdd_proxy_vote(device *, int *) {
    assert(writes == 5); ++votes; return fault == 9 ? -EIO : 0;
}
static int qcom_cc_really_probe(device *, int *, regmap *) {
    assert(writes == 5 && votes == 1); ++registrations;
    return fault == 10 ? -ENOSPC : 0;
}
static void dev_err(device *, const char *) {}
CPP
cat > "$work/suffix.cpp" <<'CPP'
int main() {
    platform_device p;
    for (fault = 0; fault <= 10; ++fault) {
        writes = votes = registrations = actions = 0;
        gcc_cliffs_proxy_active = false;
        const int rc = gcc_cliffs_probe(&p);
        const int wanted = fault == 1 ? -EPROBE_DEFER : fault == 2 ? -ENOMEM :
            fault == 3 ? -ENODEV : fault >= 4 && fault <= 8 ? -EREMOTEIO :
            fault == 9 ? -EIO : fault == 10 ? -ENOSPC : 0;
        assert(rc == wanted);
        assert(actions == (fault == 1 ? 0 : 1));
        assert(writes == (fault >= 1 && fault <= 3 ? 0 :
                          fault >= 4 && fault <= 8 ? fault - 3 : 5));
        assert(votes == (fault >= 1 && fault <= 8 ? 0 : 1));
        assert(registrations == (fault >= 1 && fault <= 9 ? 0 : 1));
        assert(gcc_cliffs_proxy_active == bool(registrations));
    }
    puts("Actual Cliffs GCC probe: exact3 camera+2 retained video gates; all11 success/fault cases and prepublication stops passed");
}
CPP
emit_probe() {
    awk '/^static int gcc_cliffs_probe\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$1"
}
emit_probe "$source_file" > "$work/probe.cpp"
[[ $(grep -c '^static int gcc_cliffs_probe(' "$work/probe.cpp") == 1 ]]
# Linux-internal deferred-probe errno is absent from userspace errno headers.
flags=(-std=c++17 -Wall -Wextra -Werror -DEPROBE_DEFER=517 "${extra[@]}")
compile_probe() {
    cat "$work/prefix.cpp" "$1" "$work/suffix.cpp" > "$work/check.cpp"
    "$compiler" "${flags[@]}" "$work/check.cpp" -o "$work/check"
}
compile_probe "$work/probe.cpp"
"$work/check"
emit_probe "$before_file" > "$work/before.cpp"
compile_probe "$work/before.cpp"
ulimit -c 0
if ("$work/check" > "$work/before.log" 2>&1) 2>/dev/null; then
    printf 'Original missing camera gates incorrectly passed\n' >&2; exit 1
else
    rc=$?
fi
[[ $rc == 134 ]]
grep -q 'reg == expected\[writes\]' "$work/before.log"
printf 'Actual original GCC probe reproduces missing-camera-gate assertion134\n'
if [[ ${CAMERA_GCC_MUTATIONS:-0} == 1 ]]; then
    for mutation in wrong-camera-register wrong-mask missing-camera-write missing-video-write; do
        case $mutation in
            wrong-camera-register) sed 's/0x2602c/0x27004/' "$work/probe.cpp";;
            wrong-mask) sed 's/0x26028, BIT(0), BIT(0)/0x26028, BIT(1), BIT(1)/' "$work/probe.cpp";;
            missing-camera-write) sed '/ret = regmap_update_bits(regmap, 0x26028,/c\	ret = 0;' "$work/probe.cpp";;
            missing-video-write) sed '/ret = regmap_update_bits(regmap, 0x32030,/c\	ret = 0;' "$work/probe.cpp";;
        esac > "$work/mutant.cpp"
        compile_probe "$work/mutant.cpp"
        if ("$work/check" > "$work/mutant.log" 2>&1) 2>/dev/null; then
            printf 'GCC mutation survived: %s\n' "$mutation" >&2; exit 1
        else
            rc=$?
        fi
        [[ $rc == 134 ]]
    done
    printf 'All4 missing/wrong camera and retained-video mutations refused\n'
fi
