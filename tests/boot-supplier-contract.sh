#!/usr/bin/env bash
# Host-only test of the actual patched supply admission branch.
set -Eeuo pipefail
source_file=${1:?Pass the prepared qcom-rpmh-regulator-uke.c}
smmu_source=${2:?Pass the prepared arm-smmu-qcom.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
    cat <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstring>
#include <initializer_list>
struct rpmh_aggr_vreg { const char *resource_name; };
int admit(const char *name) {
    rpmh_aggr_vreg vreg{name};
    auto *aggr_vreg = &vreg;
CPP
    awk '/OEM Uke supplies required/ { emit=1 } emit && /aggr_vreg->addr =/ { exit } emit { print }' "$source_file"
    cat <<'CPP'
    return 0;
}
int main() {
    for (const char *name : {"cx.lvl", "mx.lvl", "lcx.lvl", "lmx.lvl", "mxc.lvl", "ldob2", "ldob4", "ldob7", "ldob17", "smpb1", "smpb2", "smpb3", "ldod1", "ldob5", "ldob12", "ldod3"})
        assert(admit(name) == 0);
    for (const char *name : {"", "ldob1", "smpb4", "ldod2", "smpb2-extra", "lcx.lvl-extra", "lmx.lvl-extra", "mxc.lvl-extra", "other"})
        assert(admit(name) == -ENODEV);
}
CPP
} > "$work/check.cpp"
grep -F 'strcmp(aggr_vreg->resource_name, "smpb2")' "$work/check.cpp" >/dev/null
g++ -std=c++20 -O2 -Wall -Wextra -Werror "$work/check.cpp" -o "$work/check"
"$work/check"
echo 'Boot supply admission: sixteen OEM resources accepted; unrelated resources rejected'
{
    cat <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstring>
#include <initializer_list>
struct device { const bool *of_node; };
struct arm_smmu_device { device *dev; };
bool of_device_is_compatible(const bool *node, const char *name) {
    return *node && !strcmp(name, "qcom,sm7675-boot-smmu");
}
int dev_err_probe(const device *, int error, const char *) { return error; }
int admit_sid(unsigned int sid, bool boot) {
    device device_state{&boot};
    auto *dev = &device_state;
    arm_smmu_device state{dev};
    auto *smmu = &state;
CPP
    awk '/if \(sid != 0x40/ { emit=1 } emit && /None of these streams/ { exit } emit { print }' "$smmu_source"
    cat <<'CPP'
    return 0;
}
int main() {
    for (unsigned int sid : {0x40, 0xb6}) {
        assert(admit_sid(sid, false) == 0);
        assert(admit_sid(sid, true) == 0);
    }
    for (unsigned int sid : {0x60, 0xa3, 0x423, 0x436, 0x11400}) {
        assert(admit_sid(sid, false) == -EOPNOTSUPP);
        assert(admit_sid(sid, true) == 0);
    }
    for (unsigned int sid : {0x1400, 0x1401, 0x21400, 0x11401, 0x1c00, 0x1c01, 0xa2, 0xa4, 0x422, 0x424, 0x435, 0x437, 0xffff}) {
        assert(admit_sid(sid, false) == -EOPNOTSUPP);
        assert(admit_sid(sid, true) == -EOPNOTSUPP);
    }
}
CPP
} > "$work/smmu.cpp"
grep -F 'sid == 0xa3' "$work/smmu.cpp" >/dev/null
g++ -std=c++20 -O2 -Wall -Wextra -Werror "$work/smmu.cpp" -o "$work/smmu"
"$work/smmu"
echo 'Boot SMMU admission: seven reviewed specs accepted; adjacent IDs, incorrect WLAN masks and reserved streams rejected'
