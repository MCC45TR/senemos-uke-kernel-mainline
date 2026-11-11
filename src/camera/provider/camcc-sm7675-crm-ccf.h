/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * CCF adapter for the eight OEM AP SWDRV0 RCG clients. No native RCG write or
 * PLL parent-rate propagation is permitted on this path. The permanent owner
 * must admit all 38 managed objects, ROM tables, inherited votes, IRQ and PM
 * before attaching these callbacks or publishing the provider.
 */
#ifndef UKE_CAMCC_SM7675_CRM_CCF_H
#define UKE_CAMCC_SM7675_CRM_CCF_H

static const struct {
	struct clk_rcg2 *rcg;
	u32 kind;
	u32 resource;
} cam_cc_crm_rcgs[] = {
	{ &cam_cc_ife_0_clk_src, CAM_CC_CRM_PERF, 0 },
	{ &cam_cc_ife_1_clk_src, CAM_CC_CRM_PERF, 1 },
	{ &cam_cc_ife_2_clk_src, CAM_CC_CRM_PERF, 2 },
	{ &cam_cc_sfe_0_clk_src, CAM_CC_CRM_PERF, 3 },
	{ &cam_cc_sfe_1_clk_src, CAM_CC_CRM_PERF, 4 },
	{ &cam_cc_csid_clk_src, CAM_CC_CRM_PERF, 6 },
	{ &cam_cc_cphy_rx_clk_src, CAM_CC_CRM_PERF, 7 },
	{ &cam_cc_camnoc_axi_rt_clk_src, CAM_CC_CRM_BW, 0 },
};

static int cam_cc_crm_ccf_parent_index(struct clk_hw *hw, u64 rate)
{
	struct cam_cc_clock *clock = cam_cc_clock_find(hw);
	struct clk_rcg2 *rcg = to_clk_rcg2(hw);
	u32 level, i, source;
	u64 rounded;
	int ret;

	if (!clock || !clock->crm)
		return -ENODEV;
	ret = cam_cc_crm_lut_pick(clock->crm->table, rate, &level, &rounded);
	if (ret || rounded != rate)
		return ret ?: -ERANGE;
	/* CP0 is firmware's XO parking point; a nonzero request uses its ROM source. */
	source = level ? clock->crm->table->rates[level - 1].source : 0;
	for (i = 0; i < clock->init.num_parents; i++)
		if (rcg->parent_map[i].cfg == source)
			return i;
	return -EINVAL;
}

static unsigned long cam_cc_crm_ccf_recalc(struct clk_hw *hw, unsigned long parent)
{
	struct cam_cc_clock *clock = cam_cc_clock_find(hw);

	return clock && clock->crm ? clock->crm->desired : 0;
}

static u8 cam_cc_crm_ccf_get_parent(struct clk_hw *hw)
{
	struct cam_cc_clock *clock = cam_cc_clock_find(hw);
	int index;

	if (!clock || !clock->crm)
		return 0;
	index = cam_cc_crm_ccf_parent_index(hw, clock->crm->desired);
	return index < 0 ? 0 : index;
}

static int cam_cc_crm_ccf_set_parent(struct clk_hw *hw, u8 index)
{
	struct cam_cc_clock *clock = cam_cc_clock_find(hw);
	int expected, ret = cam_cc_clock_access(clock);

	if (ret)
		return ret;
	if (!clock->crm || !clock->crm->staged)
		return cam_cc_clock_fail(-EUCLEAN, 0);
	expected = cam_cc_crm_ccf_parent_index(hw, clock->crm->new_rate);
	return expected >= 0 && expected == index ? 0 :
		cam_cc_clock_fail(expected < 0 ? expected : -EINVAL, 0);
}

static int cam_cc_crm_ccf_determine(struct clk_hw *hw, struct clk_rate_request *req)
{
	struct cam_cc_clock *clock = cam_cc_clock_find(hw);
	u64 rounded;
	u32 level, value;
	int index, ret;

	if (!clock || !clock->crm || !req)
		return -EINVAL;
	if (READ_ONCE(cam_cc_power.fault) || clock->crm->fault)
		return -EIO;
	ret = cam_cc_crm_lut_pick(clock->crm->table, req->rate, &level, &rounded);
	if (ret)
		return ret;
	if (rounded < req->min_rate || rounded > req->max_rate)
		return -ERANGE;
	ret = cam_cc_crm_clock_value(clock->crm, rounded, &value);
	if (ret)
		return ret;
	index = cam_cc_crm_ccf_parent_index(hw, rounded);
	if (index < 0)
		return index;
	req->best_parent_hw = clk_hw_get_parent_by_index(hw, index);
	if (!req->best_parent_hw)
		return -ENODEV;
	/* Firmware controls the parent frequency. This is a topology hint only. */
	req->best_parent_rate = clk_hw_get_rate(req->best_parent_hw);
	req->rate = rounded;
	return 0;
}

static int __maybe_unused cam_cc_crm_ccf_attach(struct cam_cc_crm_clock clients[8])
{
	struct cam_cc_clock *clock;
	u32 i, value, level, parent;
	bool mapped;
	int ret;

	if (!clients || !cam_cc_clocks_ready || cam_cc_power.publication_started)
		return -EINVAL;
	ret = cam_cc_power_access(&cam_cc_power, 0);
	if (ret)
		return ret;
	/* Validate the complete client set before replacing any catalog callbacks. */
	for (i = 0; i < ARRAY_SIZE(cam_cc_crm_rcgs); i++) {
		clock = cam_cc_clock_find(&cam_cc_crm_rcgs[i].rcg->clkr.hw);
		if (!clock || clock->native != &clk_rcg2_shared_ops || clock->crm ||
		    clock->prepared || clock->voted || clients[i].prepared ||
		    clients[i].staged || clients[i].fault ||
		    clients[i].kind != cam_cc_crm_rcgs[i].kind ||
		    clients[i].resource != cam_cc_crm_rcgs[i].resource || !clients[i].desired)
			return -EINVAL;
		ret = cam_cc_crm_clock_value(&clients[i], clients[i].desired, &value);
		if (ret)
			return ret;
		if (!cam_cc_crm_rcgs[i].rcg->parent_map || !clock->init.num_parents)
			return -EINVAL;
		for (level = 0; level < clients[i].table->count; level++) {
			mapped = false;
			for (parent = 0; parent < clock->init.num_parents; parent++)
				if (cam_cc_crm_rcgs[i].rcg->parent_map[parent].cfg ==
				    clients[i].table->rates[level].source)
					mapped = true;
			if (!mapped)
				return -EINVAL;
		}
	}
	for (i = 0; i < ARRAY_SIZE(cam_cc_crm_rcgs); i++) {
		clock = cam_cc_clock_find(&cam_cc_crm_rcgs[i].rcg->clkr.hw);
		clock->crm = &clients[i];
		clock->ops.enable = NULL;
		clock->ops.disable = NULL;
		clock->ops.is_enabled = NULL;
		clock->ops.init = NULL;
		clock->ops.set_rate_and_parent = NULL;
		clock->ops.set_parent = cam_cc_crm_ccf_set_parent;
		clock->ops.get_parent = cam_cc_crm_ccf_get_parent;
		clock->ops.recalc_rate = cam_cc_crm_ccf_recalc;
		clock->ops.determine_rate = cam_cc_crm_ccf_determine;
		clock->disable_check = NULL;
		clock->init.flags &= ~CLK_SET_RATE_PARENT;
	}
	return 0;
}

#endif /* UKE_CAMCC_SM7675_CRM_CCF_H */
