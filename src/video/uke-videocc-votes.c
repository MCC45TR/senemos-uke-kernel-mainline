// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (c) 2022-2024 Qualcomm Innovation Center, Inc.
 * Cliffs tables from MiCode 5712080a, videocc-pineapple.c.
 * Include in videocc-sm8550.c; use the existing regulator aggregator.
 */
#include "vdd-level.h"

static DEFINE_VDD_REGULATORS(uke_video_mm, VDD_HIGH + 1, 1, vdd_corner);
static DEFINE_VDD_REGULATORS(uke_video_mxc, VDD_HIGH + 1, 1, vdd_corner);
static struct clk_vdd_class *uke_video_regulators[] = {
	&uke_video_mm, &uke_video_mxc,
};
static unsigned long uke_video_pll_rates[VDD_NUM] = {
	[VDD_LOWER_D1] = 615000000, [VDD_LOW] = 1100000000,
	[VDD_LOW_L1] = 1600000000, [VDD_NOMINAL] = 2000000000,
};
static unsigned long uke_video_mvs0_rates[VDD_NUM] = {
	[VDD_LOWER_D1] = 576000000, [VDD_LOWER] = 720000000,
	[VDD_LOW] = 1014000000, [VDD_LOW_L1] = 1098000000,
	[VDD_NOMINAL] = 1332000000, [VDD_HIGH] = 1600000000,
};
static unsigned long uke_video_mvs1_rates[VDD_NUM] = {
	[VDD_LOWER_D1] = 840000000, [VDD_LOWER] = 1050000000,
	[VDD_LOW] = 1350000000, [VDD_LOW_L1] = 1500000000,
	[VDD_NOMINAL] = 1650000000,
};
static struct clk_ops uke_video_pll_ops, uke_video_rcg_ops;
static struct clk_init_data uke_video_inits[4];
static bool uke_video_proxy_active;

static int uke_video_pll_prepare(struct clk_hw *hw)
{
	int ret = clk_prepare_regmap(hw);

	if (ret)
		return ret;
	ret = clk_alpha_pll_lucid_evo_ops.prepare(hw);
	if (ret)
		clk_unprepare_regmap(hw);
	return ret;
}

static void uke_video_add_votes(struct clk_regmap *clock, unsigned long *rates,
				const struct clk_ops *ops, bool pll, unsigned int index)
{
	clock->vdd_data = (struct clk_vdd_class_data) {
		.num_rate_max = VDD_NUM, .rate_max = rates,
	};
	if (pll) {
		clock->vdd_data.vdd_class = &uke_video_mxc;
	} else {
		clock->vdd_data.vdd_classes = uke_video_regulators;
		clock->vdd_data.num_vdd_classes = ARRAY_SIZE(uke_video_regulators);
	}
	uke_video_inits[index] = *clock->hw.init;
	uke_video_inits[index].ops = ops;
	clock->hw.init = &uke_video_inits[index];
}

static void uke_video_voltage_release(void *data)
{
	if (uke_video_proxy_active) {
		if (clk_vdd_proxy_unvote(data, &video_cc_sm7675_desc))
			return;
		uke_video_proxy_active = false;
	}
	clk_regulator_deinit(&video_cc_sm7675_desc);
}

static int uke_video_voltage_init(struct device *dev)
{
	int ret;

	uke_video_mm.class_name = "vdd_mm";
	uke_video_mxc.class_name = "vdd_mxc";
	uke_video_mm.regulator_names[0] = "vdd_mm";
	uke_video_mxc.regulator_names[0] = "vdd_mxc";
	uke_video_pll_ops = clk_alpha_pll_lucid_evo_ops;
	uke_video_rcg_ops = clk_rcg2_shared_ops;
	uke_video_pll_ops.prepare = uke_video_pll_prepare;
	uke_video_rcg_ops.prepare = clk_prepare_regmap;
	uke_video_pll_ops.unprepare = clk_unprepare_regmap;
	uke_video_rcg_ops.unprepare = clk_unprepare_regmap;
	uke_video_pll_ops.pre_rate_change = clk_pre_change_regmap;
	uke_video_rcg_ops.pre_rate_change = clk_pre_change_regmap;
	uke_video_pll_ops.post_rate_change = clk_post_change_regmap;
	uke_video_rcg_ops.post_rate_change = clk_post_change_regmap;
	uke_video_add_votes(&video_cc_pll0.clkr, uke_video_pll_rates,
			    &uke_video_pll_ops, true, 0);
	uke_video_add_votes(&video_cc_pll1.clkr, uke_video_pll_rates,
			    &uke_video_pll_ops, true, 1);
	uke_video_add_votes(&video_cc_mvs0_clk_src.clkr, uke_video_mvs0_rates,
			    &uke_video_rcg_ops, false, 2);
	uke_video_add_votes(&video_cc_mvs1_clk_src.clkr, uke_video_mvs1_rates,
			    &uke_video_rcg_ops, false, 3);
	video_cc_sm7675_desc.clk_regulators = uke_video_regulators;
	video_cc_sm7675_desc.num_clk_regulators = ARRAY_SIZE(uke_video_regulators);
	ret = clk_regulator_init(dev, &video_cc_sm7675_desc);
	if (ret)
		return ret;
	ret = devm_add_action_or_reset(dev, uke_video_voltage_release, dev);
	if (ret)
		return ret;
	ret = clk_vdd_proxy_vote(dev, &video_cc_sm7675_desc);
	if (!ret)
		uke_video_proxy_active = true;
	return ret;
}

static void uke_video_sync_state(struct device *dev)
{
	if (!of_device_is_compatible(dev->of_node, "qcom,sm7675-videocc"))
		return;
	if (clk_sync_state(dev))
		return;
	if (uke_video_proxy_active && !clk_vdd_proxy_unvote(dev, &video_cc_sm7675_desc))
		uke_video_proxy_active = false;
}
