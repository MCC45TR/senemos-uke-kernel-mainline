/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Powered, read-only parent resolution before CAMCC provider publication.
 * Follows clk_rcg2_crmc_populate_freq(), lucid_evo_calc_pll{,_out}() and
 * clk_alpha_pll_postdiv_fabia_recalc_rate() in Xiaomi Uke
 * 5712080a4b0c0b1a879e6d145c601c649ddaddfd, drivers/clk/qcom/.
 * Copyright (c) 2022-2024, Qualcomm Innovation Center, Inc. All rights reserved.
 *
 * Include after handoff, CRM CCF and passive adapters. This does not request
 * an IRQ, attach clients, program clocks, release inherited votes or admit CRM.
 */
#ifndef UKE_CAMCC_SM7675_CRM_ROM_H
#define UKE_CAMCC_SM7675_CRM_ROM_H

struct cam_cc_crm_rom_context {
	struct clk_rcg2 *rcg;
	cam_cc_crm_lut_read_fn read;
	void *read_context;
};

/* CCF cores do not exist yet: use the validated catalog, not get_parent(). */
static int cam_cc_crm_rom_pll(struct clk_hw *hw, u32 l, u32 alpha, u64 *rate)
{
	struct cam_cc_clock *clock = cam_cc_clock_find(hw);
	struct clk_alpha_pll *pll;
	const struct clk_parent_data *parent;
	u32 value;
	u64 xo, result;
	int ret;

	if (!clock || !rate || clock->native != &clk_alpha_pll_lucid_evo_ops ||
	    clock->init.num_parents != 1 || !clock->init.parent_data ||
	    l > 0xffff || alpha > 0xffff)
		return -EINVAL;
	parent = clock->init.parent_data;
	/* Native catalog converts OEM fw_name to the exact DT clock index. */
	if (parent->hw || parent->fw_name || parent->index != DT_BI_TCXO ||
	    !cam_cc_native.parents[0])
		return -EINVAL;
	xo = clk_get_rate(cam_cc_native.parents[0]);
	if (xo != 19200000)
		return -EINVAL;
	pll = container_of(clock->clock, struct clk_alpha_pll, clkr);
	if (!pll->regs)
		return -EINVAL;
	if (!l) {
		/* OEM ignores ROM alpha when L=0 and observes the current parent. */
		ret = regmap_read(cam_cc_power.map,
			pll->offset + pll->regs[PLL_OFF_L_VAL], &value);
		if (ret)
			return ret;
		l = value & 0xffff;
		ret = regmap_read(cam_cc_power.map,
			pll->offset + pll->regs[PLL_OFF_ALPHA_VAL], &value);
		if (ret)
			return ret;
		alpha = value & 0xffff;
	}
	/* Retain the existing nominal supply ceiling; never admit HIGH_L1 here. */
	ret = cam_cc_crm_passive_pll_rate(xo, l, alpha, &result);
	if (ret)
		return ret;
	*rate = result;
	return 0;
}

static int cam_cc_crm_rom_local_parent(struct clk_hw *hw, u32 l, u32 alpha,
				     u64 *rate)
{
	struct cam_cc_clock *clock = cam_cc_clock_find(hw);
	struct clk_alpha_pll_postdiv *divider;
	u64 parent_rate;
	u32 value, i, divisor = 0, matches = 0;
	int ret;

	if (!clock || !rate)
		return -EINVAL;
	if (clock->native == &clk_alpha_pll_lucid_evo_ops)
		return cam_cc_crm_rom_pll(hw, l, alpha, rate);
	if (clock->native != &clk_alpha_pll_postdiv_lucid_ole_ops ||
	    clock->init.num_parents != 1 || !clock->init.parent_hws ||
	    !clock->init.parent_hws[0])
		return -EOPNOTSUPP;
	divider = container_of(clock->clock, struct clk_alpha_pll_postdiv, clkr);
	if (!divider->regs || divider->post_div_shift != 10 || divider->width != 4 ||
	    !divider->post_div_table || !divider->num_post_div)
		return -EINVAL;
	/* Exactly one PLL then one postdivider; malformed chains cannot recurse. */
	ret = cam_cc_crm_rom_pll((struct clk_hw *)clock->init.parent_hws[0],
				l, alpha, &parent_rate);
	if (ret)
		return ret;
	ret = regmap_read(cam_cc_power.map,
		divider->offset + divider->regs[PLL_OFF_USER_CTL], &value);
	if (ret)
		return ret;
	value = (value >> divider->post_div_shift) & (BIT(divider->width) - 1);
	for (i = 0; i < divider->num_post_div; i++) {
		if (divider->post_div_table[i].div &&
		    divider->post_div_table[i].val == value) {
			divisor = divider->post_div_table[i].div;
			matches++;
		}
	}
	if (matches != 1)
		return -EOPNOTSUPP;
	/* OEM fabia/CRM uses integer floor division, unlike generic clk-divider. */
	parent_rate /= divisor;
	if (!parent_rate)
		return -ERANGE;
	*rate = parent_rate;
	return 0;
}

static int cam_cc_crm_rom_parent(void *context, u32 source, u32 l,
				 u32 alpha, u64 *rate)
{
	struct cam_cc_crm_rom_context *rom = context;
	struct cam_cc_clock *clock;
	const struct clk_parent_data *parent = NULL;
	u32 i, matches = 0;
	u64 result;
	int ret;

	if (!rom || !rom->rcg || !rate || source > 7 || l > 0xff || alpha > 0xffff ||
	    !cam_cc_clocks_ready || cam_cc_power.publication_started)
		return -EINVAL;
	ret = cam_cc_power_access(&cam_cc_power, 0);
	if (ret)
		return ret;
	clock = cam_cc_clock_find(&rom->rcg->clkr.hw);
	if (!clock || !rom->rcg->parent_map || !clock->init.parent_data ||
	    !clock->init.num_parents || clock->crm || clock->prepared || clock->voted)
		return -EINVAL;
	for (i = 0; i < clock->init.num_parents; i++) {
		if (rom->rcg->parent_map[i].cfg == source) {
			parent = &clock->init.parent_data[i];
			matches++;
		}
	}
	if (matches != 1)
		return -EINVAL;
	if (parent->hw) {
		if (parent->fw_name)
			return -EINVAL;
		ret = cam_cc_crm_rom_local_parent((struct clk_hw *)parent->hw,
						l, alpha, &result);
		if (ret)
			return ret;
	} else {
		/* Only the exact external XO parking source belongs to these clients. */
		if (source || l || parent->fw_name || parent->index != DT_BI_TCXO ||
		    !cam_cc_native.parents[0])
			return -EINVAL;
		result = clk_get_rate(cam_cc_native.parents[0]);
		if (result != 19200000)
			return -EINVAL;
	}
	*rate = result;
	return 0;
}

static int cam_cc_crm_rom_read(void *context, u32 offset, u32 *value)
{
	struct cam_cc_crm_rom_context *rom = context;
	int ret = cam_cc_power_access(&cam_cc_power, 0);

	if (ret)
		return ret;
	return rom->read(rom->read_context, offset, value);
}

static int __maybe_unused cam_cc_crm_rom_load(u32 client,
		cam_cc_crm_lut_read_fn read, void *read_context,
		struct cam_cc_crm_lut *table)
{
	struct cam_cc_crm_rom_context rom;
	u32 vcd;

	if (client >= ARRAY_SIZE(cam_cc_crm_rcgs) || !read || !table)
		return -EINVAL;
	rom.rcg = cam_cc_crm_rcgs[client].rcg;
	rom.read = read;
	rom.read_context = read_context;
	/* OEM uses a separate VCD8 bank for its sole CAMNOC bandwidth voter. */
	vcd = cam_cc_crm_rcgs[client].kind == CAM_CC_CRM_BW ?
		8 : cam_cc_crm_rcgs[client].resource;
	return cam_cc_crm_lut_load(vcd, 0x2000, cam_cc_crm_rom_read,
				 cam_cc_crm_rom_parent, &rom, table);
}

#endif /* UKE_CAMCC_SM7675_CRM_ROM_H */
