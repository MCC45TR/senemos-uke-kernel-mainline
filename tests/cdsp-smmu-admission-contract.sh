#!/usr/bin/env bash
# Actual admission helper, synthetic OF identities and encoded stream IDs.
set -Eeuo pipefail
source_file=${1:?Pass prepared arm-smmu-qcom.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cstdint>
#include <cstring>
#include <cstdio>
struct device_node { bool native=true; };
struct iommu_fwspec { unsigned num_ids=1;uint32_t ids[2]={}; };
struct device { device_node *of_node; iommu_fwspec *spec; };
static device_node root,user,adsp3,adsp5,foreign;
static iommu_fwspec *dev_iommu_fwspec_get(device *d) { return d->spec; }
static bool of_device_is_compatible(device_node *n,const char *s) { assert(!strcmp(s,"qcom,fastrpc-compute-cb"));return n->native; }
static device_node *of_find_node_by_path(const char *p) {
    if(strstr(p,"remoteproc-cdsp"))return strstr(p,"@1")?&root:&user;
    return strstr(p,"@3")?&adsp3:&adsp5;
}
static void of_node_put(device_node *) {}
CPP
awk '/^static bool qcom_uke_sensor_cb\(/ {p=1} p{print} p&&/^}/{exit}' "$source_file" >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
int main() {
    iommu_fwspec spec;device d{&root,&spec};spec.ids[0]=0xc01;assert(qcom_uke_sensor_cb(&d));
    d.of_node=&user;spec.ids[0]=0xc02;assert(qcom_uke_sensor_cb(&d));
    d.of_node=&foreign;assert(!qcom_uke_sensor_cb(&d));
    d.of_node=&root;assert(!qcom_uke_sensor_cb(&d));
    spec.ids[0]=0xc01|0x200000;assert(!qcom_uke_sensor_cb(&d));
    for(unsigned i=0;i<0x1000;i++) { spec.ids[0]=i;assert(qcom_uke_sensor_cb(&d)==(i==0xc01)); }
    spec.num_ids=2;spec.ids[0]=0x801003;spec.ids[1]=0x201043;d.of_node=&adsp3;assert(qcom_uke_sensor_cb(&d));
    spec.ids[0]=0x801005;spec.ids[1]=0x201045;d.of_node=&adsp5;assert(qcom_uke_sensor_cb(&d));
    d.spec=nullptr;assert(!qcom_uke_sensor_cb(&d));d.spec=&spec;d.of_node=nullptr;assert(!qcom_uke_sensor_cb(&d));
    puts("PASS: actual CDSP SID/OF-identity admission and retained ADSP contexts; COPR only");
}
CPP
"${CXX:-c++}" -std=gnu++20 -O1 -Wall -Wextra -Werror \
    -fsanitize=address,undefined -fno-omit-frame-pointer "$work/check.cpp" -o "$work/check"
"$work/check"
