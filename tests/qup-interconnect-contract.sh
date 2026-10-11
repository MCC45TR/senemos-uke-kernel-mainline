#!/usr/bin/env bash
# Compile the actual kernel C graph and verify both QUP routes on the host.
set -Eeuo pipefail
source_file=${1:?Pass the prepared qnoc-cliffs-usb.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
    cat <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
struct regmap_config { unsigned int reg_bits, reg_stride, val_bits; };
struct qcom_icc_qosbox {
    unsigned int num_ports, port_offsets[2], prio, urg_fwd, prio_fwd_disable;
};
struct qcom_icc_node {
    const char *name;
    unsigned int channels, buswidth, num_links;
    const struct qcom_icc_qosbox *qosbox;
    struct qcom_icc_node *link_nodes[64];
};
struct qcom_icc_bcm {
    const char *name;
    bool keepalive;
    unsigned int vote_scale, enable_mask, num_nodes;
    struct qcom_icc_node *nodes[64];
};
struct qcom_icc_desc {
    const struct regmap_config *config;
    struct qcom_icc_node * const *nodes;
    size_t num_nodes;
    struct qcom_icc_bcm * const *bcms;
    size_t num_bcms;
    bool qos_required, qos_requires_clocks;
};
C
    awk '/^#define MASTER_APPSS_PROC/ { emit=1 } /^static const struct of_device_id/ { emit=0 } emit { print }' "$source_file"
    cat <<'C'
static const struct qcom_icc_desc *providers[] = {
    &cliffs_aggre1_noc, &cliffs_aggre2_noc, &cliffs_clk_virt,
    &cliffs_cnoc_cfg, &cliffs_cnoc_main, &cliffs_gem_noc,
    &cliffs_mc_virt, &cliffs_system_noc,
};
static bool registered(const struct qcom_icc_node *node) {
    for (size_t p = 0; p < ARRAY_SIZE(providers); ++p)
        for (size_t i = 0; i < providers[p]->num_nodes; ++i)
            if (providers[p]->nodes[i] == node) return true;
    return false;
}
static bool reaches(const struct qcom_icc_node *from, const struct qcom_icc_node *to, int depth) {
    assert(from && registered(from) && depth < 16);
    if (from == to) return true;
    for (unsigned int i = 0; i < from->num_links; ++i)
        if (reaches(from->link_nodes[i], to, depth + 1)) return true;
    return false;
}
int main(void) {
    for (size_t p = 0; p < ARRAY_SIZE(providers); ++p) {
        const struct qcom_icc_desc *provider = providers[p];
        for (size_t i = 0; i < provider->num_nodes; ++i) {
            const struct qcom_icc_node *node = provider->nodes[i];
            if (!node) continue;
            assert(node->channels && node->buswidth && node->num_links <= 64);
            for (unsigned int j = 0; j < node->num_links; ++j)
                assert(node->link_nodes[j] && registered(node->link_nodes[j]));
        }
        for (size_t i = 0; i < provider->num_bcms; ++i)
            for (unsigned int j = 0; j < provider->bcms[i]->num_nodes; ++j)
                assert(registered(provider->bcms[i]->nodes[j]));
    }
    assert(reaches(&qup0_core_master, &qup0_core_slave, 0));
    assert(reaches(&qup1_core_master, &qup1_core_slave, 0));
    assert(reaches(&chm_apps, &qhs_qup0, 0));
    assert(reaches(&chm_apps, &qhs_qup1, 0));
    assert(reaches(&qhm_qup0, &ebi, 0));
    assert(reaches(&qhm_qup1, &ebi, 0));
    assert(reaches(&xm_usb3_0, &ebi, 0));
    assert(reaches(&xm_ufs_mem, &ebi, 0));
    assert(!reaches(&qup1_core_master, &qhs_qup0, 0));
    assert(cliffs_aggre2_noc.qos_required && cliffs_aggre2_noc.qos_requires_clocks);
    assert(qhm_qup1_qos.port_offsets[0] == 0x13000 && qhm_qup1_qos.prio == 2);
    assert(bcm_qup1.keepalive && bcm_qup1.vote_scale == 1);
}
C
} > "$work/check.c"
cc -std=gnu11 -O2 -Wall -Wextra -Werror "$work/check.c" -o "$work/check"
"$work/check"
printf 'Registered QUP0/QUP1 core, configuration and memory paths; USB/UFS regression: passed\n'
