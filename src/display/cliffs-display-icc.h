/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (c) 2023-2024, Qualcomm Innovation Center, Inc. All rights reserved.
 * Primary-display HLOS routes adapted from Xiaomi cliffs.c to Linux 7.2.10.
 * OEM commit: 5712080a4b0c0b1a879e6d145c601c649ddaddfd.
 * Included in the isolated native-display qnoc-cliffs-usb.c.
 * Reuses the existing LLCC/DDR and configuration nodes, not parallel providers.
 * No display-voter aliases or camera/DP paths are admitted here.
 */
#define MASTER_MDP 21
#define MASTER_MNOC_HF_MEM_NOC 23
#define SLAVE_DISPLAY_CFG 524
#define SLAVE_MNOC_HF_MEM_NOC 559

static struct qcom_icc_node qns_mem_noc_hf;
static struct qcom_icc_node qnm_mnoc_hf;

static const struct qcom_icc_qosbox qnm_mdp_qos = {
	.num_ports = 2,
	.port_offsets = { 0xad000, 0xae000 },
	.prio = 0,
	.urg_fwd = 1,
	.prio_fwd_disable = 0,
};

static struct qcom_icc_node qnm_mdp = {
	.name = "qnm_mdp",
	.channels = 2,
	.buswidth = 32,
	.qosbox = &qnm_mdp_qos,
	.num_links = 1,
	.link_nodes = { &qns_mem_noc_hf },
};

static struct qcom_icc_node qns_mem_noc_hf = {
	.name = "qns_mem_noc_hf",
	.channels = 2,
	.buswidth = 32,
	.num_links = 1,
	.link_nodes = { &qnm_mnoc_hf },
};

static const struct qcom_icc_qosbox qnm_mnoc_hf_qos = {
	.num_ports = 2,
	.port_offsets = { 0x33000, 0x73000 },
	.prio = 0,
	.urg_fwd = 1,
	.prio_fwd_disable = 0,
};

static struct qcom_icc_node qnm_mnoc_hf = {
	.name = "qnm_mnoc_hf",
	.channels = 2,
	.buswidth = 32,
	.qosbox = &qnm_mnoc_hf_qos,
	.num_links = 2,
	.link_nodes = { &qns_gem_noc_cnoc, &qns_llcc },
};

static struct qcom_icc_node qhs_display_cfg = {
	.name = "qhs_display_cfg",
	.channels = 1,
	.buswidth = 4,
	.num_links = 0,
};

/* OEM keepalive_early has no v6.12 field. Do not silently replace it with
 * permanent keepalive: early splash bandwidth needs a separate handoff policy.
 */
static struct qcom_icc_bcm bcm_mm0 = {
	.name = "MM0",
	.num_nodes = 1,
	.nodes = { &qns_mem_noc_hf },
};

static struct qcom_icc_node * const mmss_noc_nodes[] = {
	[MASTER_MDP] = &qnm_mdp,
	[SLAVE_MNOC_HF_MEM_NOC] = &qns_mem_noc_hf,
};

static struct qcom_icc_bcm * const mmss_noc_bcms[] = {
	&bcm_mm0,
};

static const struct qcom_icc_desc cliffs_mmss_noc = {
	.config = &cliffs_icc_regmap_config,
	.nodes = mmss_noc_nodes,
	.num_nodes = ARRAY_SIZE(mmss_noc_nodes),
	.bcms = mmss_noc_bcms,
	.num_bcms = ARRAY_SIZE(mmss_noc_bcms),
	.qos_required = true,
};

/* Integration must add qnm_mnoc_hf to gem_noc_nodes and bcm_sh1;
 * add qhs_display_cfg to cnoc_cfg_nodes, qsm_cfg.links and bcm_cn1;
 * and register cliffs_mmss_noc on the existing stock mmss_noc provider.
 * These declarations alone intentionally do not register another provider.
 */
