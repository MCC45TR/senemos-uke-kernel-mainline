/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Read-only CRM PLL/divider/branch adapters for the exact Uke clock catalog.
 * Layout and passive ownership follow MiCode Xiaomi_Kernel_OpenSource
 * 5712080a4b0c0b1a879e6d145c601c649ddaddfd, drivers/clk/qcom/
 * {camcc-cliffs.c,clk-alpha-pll.c,clk-branch.c}.
 * Copyright (c) 2023, Qualcomm Innovation Center, Inc. All rights reserved.
 * PLL arithmetic also derives from clk-alpha-pll.c:
 * Copyright (c) 2015-2021, The Linux Foundation. All rights reserved.
 *
 * Include after the native clocks and eight-client CRM CCF adapter. This
 * attachment does not own an IRQ, admit firmware mode or withdraw boot votes.
 * Its caller must complete those contracts before provider publication.
 */
#ifndef UKE_CAMCC_SM7675_CRM_PASSIVE_H
#define UKE_CAMCC_SM7675_CRM_PASSIVE_H

enum cam_cc_crm_passive_kind {
	CAM_CC_CRM_PLL,
	CAM_CC_CRM_DIVIDER,
	CAM_CC_CRM_BRANCH,
};

static const struct {
	struct clk_regmap *clock;
	enum cam_cc_crm_passive_kind kind;
	u32 offset;
} cam_cc_crm_passive[] = {
	{ &cam_cc_pll3.clkr, CAM_CC_CRM_PLL, 0x3000 },
	{ &cam_cc_pll3_out_even.clkr, CAM_CC_CRM_DIVIDER, 0x3000 },
	{ &cam_cc_pll4.clkr, CAM_CC_CRM_PLL, 0x4000 },
	{ &cam_cc_pll4_out_even.clkr, CAM_CC_CRM_DIVIDER, 0x4000 },
	{ &cam_cc_pll5.clkr, CAM_CC_CRM_PLL, 0x5000 },
	{ &cam_cc_pll5_out_even.clkr, CAM_CC_CRM_DIVIDER, 0x5000 },
	{ &cam_cc_pll6.clkr, CAM_CC_CRM_PLL, 0x6000 },
	{ &cam_cc_pll6_out_even.clkr, CAM_CC_CRM_DIVIDER, 0x6000 },
	{ &cam_cc_pll7.clkr, CAM_CC_CRM_PLL, 0x7000 },
	{ &cam_cc_pll7_out_even.clkr, CAM_CC_CRM_DIVIDER, 0x7000 },
	{ &cam_cc_camnoc_axi_nrt_clk.clkr, CAM_CC_CRM_BRANCH, 0x13284 },
	{ &cam_cc_camnoc_axi_rt_clk.clkr, CAM_CC_CRM_BRANCH, 0x13274 },
	{ &cam_cc_cpas_ife_0_clk.clkr, CAM_CC_CRM_BRANCH, 0x1103c },
	{ &cam_cc_cpas_ife_1_clk.clkr, CAM_CC_CRM_BRANCH, 0x1203c },
	{ &cam_cc_cpas_ife_2_clk.clkr, CAM_CC_CRM_BRANCH, 0x1208c },
	{ &cam_cc_cpas_sfe_0_clk.clkr, CAM_CC_CRM_BRANCH, 0x13090 },
	{ &cam_cc_cpas_sfe_1_clk.clkr, CAM_CC_CRM_BRANCH, 0x130e0 },
	{ &cam_cc_csid_clk.clkr, CAM_CC_CRM_BRANCH, 0x13250 },
	{ &cam_cc_csid_csiphy_rx_clk.clkr, CAM_CC_CRM_BRANCH, 0x15100 },
	{ &cam_cc_csiphy0_clk.clkr, CAM_CC_CRM_BRANCH, 0x150fc },
	{ &cam_cc_csiphy1_clk.clkr, CAM_CC_CRM_BRANCH, 0x15120 },
	{ &cam_cc_csiphy2_clk.clkr, CAM_CC_CRM_BRANCH, 0x15140 },
	{ &cam_cc_csiphy3_clk.clkr, CAM_CC_CRM_BRANCH, 0x15160 },
	{ &cam_cc_csiphy4_clk.clkr, CAM_CC_CRM_BRANCH, 0x15180 },
	{ &cam_cc_ife_0_clk.clkr, CAM_CC_CRM_BRANCH, 0x11030 },
	{ &cam_cc_ife_1_clk.clkr, CAM_CC_CRM_BRANCH, 0x12030 },
	{ &cam_cc_ife_2_clk.clkr, CAM_CC_CRM_BRANCH, 0x12080 },
	{ &cam_cc_ife_lite_cphy_rx_clk.clkr, CAM_CC_CRM_BRANCH, 0x1304c },
	{ &cam_cc_sfe_0_clk.clkr, CAM_CC_CRM_BRANCH, 0x13084 },
	{ &cam_cc_sfe_1_clk.clkr, CAM_CC_CRM_BRANCH, 0x130d4 },
};

static struct {
	u64 rate;
	u32 divider;
	bool enabled;
} cam_cc_crm_passive_cache[ARRAY_SIZE(cam_cc_crm_passive)];

static bool cam_cc_crm_passive_attached;

/* Exact 16-bit alpha arithmetic, including the OEM upward kHz rounding. */
static int cam_cc_crm_passive_pll_rate(u64 xo, u32 l, u32 alpha, u64 *rate)
{
	u64 value;

	if (!rate || xo != 19200000 || !l || l > 0xffff || alpha > 0xffff)
		return -EINVAL;
	value = xo * l + ((xo * alpha) >> 16);
	/* The catalog's highest admitted supply corner ends at 2 GHz. */
	value = ((value + 999) / 1000) * 1000;
	if (value < 249600000 || value > 2000000000)
		return -ERANGE;
	*rate = value;
	return 0;
}

static int cam_cc_crm_passive_index(struct clk_hw *hw)
{
	u32 i;

	for (i = 0; i < ARRAY_SIZE(cam_cc_crm_passive); i++)
		if (&cam_cc_crm_passive[i].clock->hw == hw)
			return i;
	return -ENOENT;
}

/* Read only while the permanent owner holds rails, interface and runtime PM. */
static int cam_cc_crm_passive_snapshot(u32 i)
{
	struct clk_alpha_pll *pll;
	struct clk_alpha_pll_postdiv *divider;
	struct clk_branch *branch;
	u32 l, alpha, value, d, n;
	u64 rate;
	int ret;

	if (i >= ARRAY_SIZE(cam_cc_crm_passive))
		return -EINVAL;
	ret = cam_cc_power_access(&cam_cc_power, 0);
	if (ret)
		return ret;
	switch (cam_cc_crm_passive[i].kind) {
	case CAM_CC_CRM_PLL:
		pll = container_of(cam_cc_crm_passive[i].clock, struct clk_alpha_pll, clkr);
		ret = regmap_read(cam_cc_power.map, pll->offset + pll->regs[PLL_OFF_L_VAL], &l);
		if (ret)
			return ret;
		ret = regmap_read(cam_cc_power.map, pll->offset + pll->regs[PLL_OFF_ALPHA_VAL], &alpha);
		if (ret)
			return ret;
		ret = cam_cc_crm_passive_pll_rate(19200000, l & 0xffff, alpha & 0xffff, &rate);
		if (ret)
			return ret;
		ret = regmap_read(cam_cc_power.map, pll->offset, &value);
		if (ret)
			return ret;
		WRITE_ONCE(cam_cc_crm_passive_cache[i].rate, rate);
		WRITE_ONCE(cam_cc_crm_passive_cache[i].enabled, !!(value & BIT(0)));
		return 0;
	case CAM_CC_CRM_DIVIDER:
		divider = container_of(cam_cc_crm_passive[i].clock, struct clk_alpha_pll_postdiv, clkr);
		ret = regmap_read(cam_cc_power.map,
			divider->offset + divider->regs[PLL_OFF_USER_CTL], &value);
		if (ret)
			return ret;
		value = (value >> divider->post_div_shift) & (BIT(divider->width) - 1);
		/* Reject unknown encodings rather than silently assuming division by1. */
		for (d = 0; d < divider->num_post_div; d++) {
			n = divider->post_div_table[d].div;
			if (n && divider->post_div_table[d].val == value) {
				WRITE_ONCE(cam_cc_crm_passive_cache[i].divider, n);
				return 0;
			}
		}
		return -EOPNOTSUPP;
	case CAM_CC_CRM_BRANCH:
		branch = container_of(cam_cc_crm_passive[i].clock, struct clk_branch, clkr);
		ret = regmap_read(cam_cc_power.map, branch->clkr.enable_reg, &value);
		if (ret)
			return ret;
		WRITE_ONCE(cam_cc_crm_passive_cache[i].enabled, branch->clkr.enable_is_inverted ?
			!(value & branch->clkr.enable_mask) : !!(value & branch->clkr.enable_mask));
		return 0;
	}
	return -EINVAL;
}

static int cam_cc_crm_passive_refresh(u32 i)
{
	int ret;

	/* An access flag alone can race a last-owner put and runtime suspend.
	 * Pin an existing user atomically; never resume an idle controller here.
	 */
	ret = pm_runtime_get_if_in_use(cam_cc_power.dev);
	if (ret < 0)
		return cam_cc_clock_fail(ret, 0);
	if (!ret)
		return 0;
	ret = cam_cc_crm_passive_snapshot(i);
	if (ret)
		/* An uncertain powered read retains this reference in quarantine. */
		return cam_cc_clock_fail(ret, 0);
	pm_runtime_put_noidle(cam_cc_power.dev);
	return 0;
}

static unsigned long cam_cc_crm_passive_recalc(struct clk_hw *hw, unsigned long parent)
{
	int i = cam_cc_crm_passive_index(hw), ret;

	if (i < 0 || !cam_cc_crm_passive_attached)
		return 0;
	/* While suspended, CCF retains the last checked observation. Never wake the
	 * controller from an observational callback or read its powered-off MMIO.
	 */
	if (READ_ONCE(cam_cc_power.fault))
		return 0;
	ret = cam_cc_crm_passive_refresh(i);
	if (ret)
		return 0;
	if (cam_cc_crm_passive[i].kind == CAM_CC_CRM_PLL)
		return READ_ONCE(cam_cc_crm_passive_cache[i].rate);
	if (cam_cc_crm_passive[i].kind == CAM_CC_CRM_DIVIDER)
		return parent / READ_ONCE(cam_cc_crm_passive_cache[i].divider);
	return parent;
}

static int cam_cc_crm_passive_enabled(struct clk_hw *hw)
{
	int i = cam_cc_crm_passive_index(hw), ret;

	if (i < 0 || !cam_cc_crm_passive_attached)
		return -ENODEV;
	if (READ_ONCE(cam_cc_power.fault))
		return -EIO;
	ret = cam_cc_crm_passive_refresh(i);
	return ret ? ret : READ_ONCE(cam_cc_crm_passive_cache[i].enabled);
}

static int cam_cc_crm_passive_preflight(void)
{
	struct cam_cc_clock *clock;
	struct clk_alpha_pll *pll;
	struct clk_alpha_pll_postdiv *divider;
	struct clk_branch *branch;
	u32 i, n;
	int ret;

	if (!cam_cc_clocks_ready || cam_cc_crm_passive_attached ||
	    cam_cc_power.publication_started)
		return -EINVAL;
	for (i = 0; i < ARRAY_SIZE(cam_cc_crm_passive); i++) {
		clock = cam_cc_clock_find(&cam_cc_crm_passive[i].clock->hw);
		if (!clock || clock->crm || clock->prepared || clock->voted || clock->crm_passive)
			return -EINVAL;
		for (n = 0; n < i; n++)
			if (cam_cc_crm_passive[n].clock == cam_cc_crm_passive[i].clock)
				return -EINVAL;
		switch (cam_cc_crm_passive[i].kind) {
		case CAM_CC_CRM_PLL:
			pll = container_of(clock->clock, struct clk_alpha_pll, clkr);
			if (clock->native != &clk_alpha_pll_lucid_evo_ops ||
			    pll->offset != cam_cc_crm_passive[i].offset || !pll->regs)
				return -EINVAL;
			break;
		case CAM_CC_CRM_DIVIDER:
			divider = container_of(clock->clock, struct clk_alpha_pll_postdiv, clkr);
			if (clock->native != &clk_alpha_pll_postdiv_lucid_ole_ops ||
			    divider->offset != cam_cc_crm_passive[i].offset || !divider->regs ||
			    divider->post_div_shift != 10 || divider->width != 4 ||
			    !divider->post_div_table || !divider->num_post_div)
				return -EINVAL;
			break;
		case CAM_CC_CRM_BRANCH:
			branch = container_of(clock->clock, struct clk_branch, clkr);
			if (clock->native != &clk_branch2_ops ||
			    branch->halt_reg != cam_cc_crm_passive[i].offset ||
			    branch->clkr.enable_reg != cam_cc_crm_passive[i].offset ||
			    branch->clkr.enable_mask != BIT(0) || branch->clkr.enable_is_inverted)
				return -EINVAL;
			break;
		}
	}
	/* Check the entire topology before reading any object. No catalog mutation
	 * occurs until every powered snapshot and all eight RCG preflights succeed.
	 */
	for (i = 0; i < ARRAY_SIZE(cam_cc_crm_passive); i++) {
		ret = cam_cc_crm_passive_snapshot(i);
		if (ret)
			return ret;
	}
	return 0;
}

static int __maybe_unused cam_cc_crm_managed_attach(struct cam_cc_crm_clock clients[8])
{
	struct cam_cc_clock *clock;
	u32 i;
	int ret = cam_cc_crm_passive_preflight();

	if (ret)
		return ret;
	ret = cam_cc_crm_ccf_attach(clients);
	if (ret)
		return ret;
	for (i = 0; i < ARRAY_SIZE(cam_cc_crm_passive); i++) {
		clock = cam_cc_clock_find(&cam_cc_crm_passive[i].clock->hw);
		clock->crm_passive = true;
		clock->ops = (struct clk_ops) { .recalc_rate = cam_cc_crm_passive_recalc };
		if (cam_cc_crm_passive[i].kind != CAM_CC_CRM_DIVIDER)
			clock->ops.is_enabled = cam_cc_crm_passive_enabled;
		/* A branch must still propagate its consumer's rate to the RCG voter.
		 * PLL and divider parents are firmware-owned, so never propagate there.
		 */
		if (cam_cc_crm_passive[i].kind != CAM_CC_CRM_BRANCH)
			clock->init.flags &= ~CLK_SET_RATE_PARENT;
		clock->init.flags |= CLK_GET_RATE_NOCACHE;
		clock->disable_check = NULL;
	}
	cam_cc_crm_passive_attached = true;
	return 0;
}

#endif /* UKE_CAMCC_SM7675_CRM_PASSIVE_H */
