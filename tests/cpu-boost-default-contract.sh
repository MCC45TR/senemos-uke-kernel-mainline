#!/usr/bin/env bash
# Compile the actual pre-registration guard; no device or MMIO access.
set -Eeuo pipefail
source_file=${1:?Pass prepared qcom-cpufreq-hw.c}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
test "$(grep -c 'Preserve the OEM permission' "$source_file")" -eq 1
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cstring>
#include <initializer_list>
static bool uke, sm7675;
static struct { bool boost_enabled; } cpufreq_qcom_hw_driver;
static bool of_machine_is_compatible(const char *name) {
    if (!strcmp(name, "xiaomi,uke")) return uke;
    assert(!strcmp(name, "qcom,sm7675"));
    return sm7675;
}
static void apply_default() {
CPP
sed -n '/Preserve the OEM permission/,/ret = cpufreq_register_driver/{ /ret = cpufreq_register_driver/d; p; }' "$source_file" >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
}
int main() {
    for (bool previous : {false, true})
        for (bool board : {false, true})
            for (bool soc : {false, true}) {
                uke = board; sm7675 = soc;
                cpufreq_qcom_hw_driver.boost_enabled = previous;
                apply_default();
                assert(cpufreq_qcom_hw_driver.boost_enabled == (previous || (board && soc)));
            }
}
CPP
"${CXX:-g++}" -std=c++20 -O2 -Wall -Wextra -Werror "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual boost default guard: exact Uke/SM7675 match and preserved foreign/default states passed; host only.\n'
