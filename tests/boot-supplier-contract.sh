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
    awk '/OEM Uke supplies/ { emit=1 } emit && /aggr_vreg->addr =/ { exit } emit { print }' "$source_file"
    cat <<'CPP'
    return 0;
}
int main() {
    for (const char *name : {"cx.lvl", "mx.lvl", "lcx.lvl", "lmx.lvl", "mxc.lvl", "ldob2", "ldob4", "ldob7", "ldob17", "smpb1", "smpb2", "smpb3", "smpe3", "ldod1", "ldob5", "ldob12", "ldod3"})
        assert(admit(name) == 0);
    for (const char *name : {"", "ldob1", "smpb4", "smpe2", "smpe4", "smpe3-extra", "ldod2", "smpb2-extra", "lcx.lvl-extra", "lmx.lvl-extra", "mxc.lvl-extra", "other"})
        assert(admit(name) == -ENODEV);
}
CPP
} > "$work/check.cpp"
grep -F 'strcmp(aggr_vreg->resource_name, "smpb2")' "$work/check.cpp" >/dev/null
g++ -std=c++20 -O2 -Wall -Wextra -Werror "$work/check.cpp" -o "$work/check"
"$work/check"
echo 'Boot supply admission: seventeen OEM resources accepted; unrelated resources rejected'
{
    cat <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstring>
#include <initializer_list>
struct device_node { bool boot; bool sensor; const char *full_path; };
struct iommu_fwspec { unsigned int num_ids; unsigned int ids[2]; };
struct device { const device_node *of_node; iommu_fwspec *spec; };
struct arm_smmu_device { device *dev; };
bool of_device_is_compatible(const device_node *node, const char *name) {
    return (!strcmp(name, "qcom,sm7675-boot-smmu") && node->boot) ||
           (!strcmp(name, "qcom,fastrpc-compute-cb") && node->sensor);
}
struct iommu_fwspec *dev_iommu_fwspec_get(device *dev) { return dev->spec; }
static device_node *lookup_node;
device_node *of_find_node_by_path(const char *path) {
    return lookup_node && !strcmp(lookup_node->full_path,path) ? lookup_node : nullptr;
}
void of_node_put(device_node *) {}
int dev_err_probe(const device *, int error, const char *) { return error; }
CPP
    awk '/^static bool qcom_uke_sensor_cb/ { emit=1 } emit && /^static int qcom_uke_smmu_(cfg_probe|alloc_context_bank)/ { exit } emit { print }' "$smmu_source"
    cat <<'CPP'
int admit_sid(unsigned int sid, bool boot, const char *path="", unsigned int first=0,
              unsigned int second=0, bool sensor=false, unsigned int count=0) {
    static device_node node;
    node = {boot, sensor, path};
    lookup_node = &node;
    iommu_fwspec spec{count, {first, second}};
    device device_state{&node, &spec};
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
    for (const char *path : {
        "/soc/remoteproc-adsp@03000000/glink-edge/qcom,msm_fastrpc_rpmsg/compute-cb@3",
        "/soc/remoteproc-adsp@03000000/glink-edge/qcom,msm_fastrpc_rpmsg/compute-cb@5"}) {
        const unsigned int id = path[strlen(path)-1] - '0';
        const unsigned int first = 0x801000+id, second = 0x201040+id;
        for (unsigned int sid : {first, second}) {
            assert(admit_sid(sid,true,path,first,second,true,2) == 0);
            assert(admit_sid(sid,false,path,first,second,true,2) == -EOPNOTSUPP);
            assert(admit_sid(sid,true,path,first,second,false,2) == -EOPNOTSUPP);
            assert(admit_sid(sid,true,path,first,second,true,1) == -EOPNOTSUPP);
            assert(admit_sid(sid,true,path,first,second+1,true,2) == -EOPNOTSUPP);
            assert(admit_sid(sid,true,"/foreign/compute-cb",first,second,true,2) == -EOPNOTSUPP);
            assert(admit_sid(sid,true) == -EOPNOTSUPP);
        }
    }
}
CPP
} > "$work/smmu.cpp"
grep -F 'sid == 0xa3' "$work/smmu.cpp" >/dev/null
g++ -std=c++20 -O2 -Wall -Wextra -Werror "$work/smmu.cpp" -o "$work/smmu"
"$work/smmu"
echo 'Boot SMMU admission: base specs and two exact FastRPC groups accepted; foreign paths, masks and missing group identity rejected'
