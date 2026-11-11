/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Read-only Cliffs CRMC frequency tables. Layout and HID semantics follow
 * clk_rcg2_crmc_populate_freq() in Xiaomi Uke
 * 5712080a4b0c0b1a879e6d145c601c649ddaddfd, drivers/clk/qcom/clk-rcg2.c.
 * Copyright (c) 2013, 2016-2018, 2020-2021, The Linux Foundation.
 * Copyright (c) 2022-2024, Qualcomm Innovation Center, Inc. All rights reserved.
 */
#ifndef UKE_CAMCC_SM7675_CRM_LUT_H
#define UKE_CAMCC_SM7675_CRM_LUT_H

#include <linux/errno.h>
#include <linux/types.h>
#include "camcc-sm7675-crm-core.h"

/* Three-bit PERF votes have CP0/off and seven usable nonzero levels. */
#define CAM_CC_CRM_LEVELS 7

struct cam_cc_crm_rate {
	u64 hz;
	u32 source;
};

struct cam_cc_crm_lut {
	struct cam_cc_crm_rate rates[CAM_CC_CRM_LEVELS];
	u32 count;
};

typedef int (*cam_cc_crm_lut_read_fn)(void *context, u32 offset, u32 *value);
/* Resolve the actual parent map and read-only PLL/postdivider, never program it. */
typedef int (*cam_cc_crm_lut_parent_fn)(void *context, u32 source, u32 l,
				       u32 alpha, u64 *hz);

static inline int cam_cc_crm_lut_offsets(u32 vcd, u32 level, u32 span,
				       u32 *cfg, u32 *pll)
{
	u32 cfg_offset, pll_offset;

	if (!cfg || !pll || (!cam_cc_crm_owned(CAM_CC_CRM_PERF, vcd) && vcd != 8) ||
	    !level || level > CAM_CC_CRM_LEVELS)
		return -EINVAL;
	cfg_offset = 0x110 + vcd * 0x200 + level * 4;
	pll_offset = 0x138 + vcd * 0x200 + level * 4;
	if ((span & 3) || span < 4 || span > 0x2000 || pll_offset > span - 4)
		return -ERANGE;
	*cfg = cfg_offset;
	*pll = pll_offset;
	return 0;
}

static inline int cam_cc_crm_lut_load(u32 vcd, u32 span,
		cam_cc_crm_lut_read_fn read, cam_cc_crm_lut_parent_fn parent,
		void *context, struct cam_cc_crm_lut *out)
{
	struct cam_cc_crm_lut table;
	u32 cfg_offset, pll_offset, cfg, pll, hid, source, level;
	u64 rate, previous = 0;
	int ret;

	if (!out || !read || !parent)
		return -EINVAL;
	table.count = 0;
	for (level = 0; level < CAM_CC_CRM_LEVELS; level++) {
		table.rates[level].hz = 0;
		table.rates[level].source = 0;
	}
	/* Validate the entire supported bank before the first callback. */
	ret = cam_cc_crm_lut_offsets(vcd, CAM_CC_CRM_LEVELS, span,
				     &cfg_offset, &pll_offset);
	if (ret)
		return ret;
	for (level = 1; level <= CAM_CC_CRM_LEVELS; level++) {
		ret = cam_cc_crm_lut_offsets(vcd, level, span, &cfg_offset, &pll_offset);
		if (ret)
			return ret;
		ret = read(context, cfg_offset, &cfg);
		if (ret)
			return ret < 0 ? ret : -EIO;
		ret = read(context, pll_offset, &pll);
		if (ret)
			return ret < 0 ? ret : -EIO;
		/* The reviewed CRM path uses integer HID division, not M/N mode. */
		if (cfg & 0x3000)
			return -EOPNOTSUPP;
		hid = cfg & 0x1f;
		source = (cfg >> 8) & 7;
		ret = parent(context, source, pll & 0xff, pll >> 16, &rate);
		if (ret)
			return ret < 0 ? ret : -EIO;
		if (!rate)
			return -EINVAL;
		if (hid) {
			if (rate > (~(u64)0) / 2)
				return -ERANGE;
			rate = rate * 2 / (hid + 1);
		}
		if (!rate)
			return -ERANGE;
		/* The first repeated/decreasing entry terminates the OEM table. */
		if (previous >= rate)
			break;
		table.rates[table.count].hz = rate;
		table.rates[table.count].source = source;
		table.count++;
		previous = rate;
	}
	if (!table.count)
		return -EINVAL;
	/* Never publish a partial table after an I/O, parent or format error. */
	*out = table;
	return 0;
}

static inline int cam_cc_crm_lut_pick(const struct cam_cc_crm_lut *table,
				    u64 requested, u32 *level, u64 *rounded)
{
	u32 i;
	u64 previous = 0;

	if (!table || !level || !rounded || !table->count ||
	    table->count > CAM_CC_CRM_LEVELS)
		return -EINVAL;
	for (i = 0; i < table->count; i++) {
		if (table->rates[i].hz <= previous)
			return -EINVAL;
		previous = table->rates[i].hz;
	}
	if (!requested) {
		*level = 0;
		*rounded = 0;
		return 0;
	}
	for (i = 0; i < table->count; i++) {
		if (requested > table->rates[i].hz)
			continue;
		*level = i + 1;
		*rounded = table->rates[i].hz;
		return 0;
	}
	return -ERANGE;
}

#endif /* UKE_CAMCC_SM7675_CRM_LUT_H */
