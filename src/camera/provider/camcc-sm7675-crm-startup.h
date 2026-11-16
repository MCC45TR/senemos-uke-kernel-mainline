/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Read-only AP SWDRV0 startup snapshot. Does not adopt or withdraw a vote.
 * Register and BCM word layout follows Xiaomi Uke drivers/soc/qcom/crm.c
 * at5712080a4b0c0b1a879e6d145c601c649ddaddfd and include/soc/qcom/tcs.h.
 * Protocol attribution is retained in camcc-sm7675-crm-core.h.
 */
#ifndef UKE_CAMCC_SM7675_CRM_STARTUP_H
#define UKE_CAMCC_SM7675_CRM_STARTUP_H

#include "camcc-sm7675-crm-lut.h"

struct cam_cc_crm_startup {
	u32 words[8][CAM_CC_CRM_STATES];
	u64 rates[8][CAM_CC_CRM_STATES];
};

static inline int cam_cc_crm_startup_rate(const struct cam_cc_crm_lut *table,
					u32 kind, u32 raw, u64 *rate)
{
	u64 rounded;
	u32 value, level;
	int ret;

	if (!rate)
		return -EINVAL;
	ret = cam_cc_crm_lut_pick(table, 0, &level, &rounded);
	if (ret)
		return ret;
	if (kind == CAM_CC_CRM_PERF) {
		if (raw & ~7U)
			return -EOPNOTSUPP;
		if (raw > table->count)
			return -ERANGE;
		*rate = raw ? table->rates[raw - 1].hz : 0;
		return 0;
	}
	if (kind != CAM_CC_CRM_BW || (raw & ~(0xe0000000U | 0x3fffU)))
		return -EOPNOTSUPP;
	/* OEM CAMNOC uses IB MHz/AB0. Known command flags may persist in readback. */
	value = raw & 0x3fff;
	if (!value) {
		*rate = 0;
		return 0;
	}
	if (!(raw & (1U << 29)))
		return -EUCLEAN;
	ret = cam_cc_crm_lut_pick(table, (u64)value * 1000000, &level, &rounded);
	if (ret)
		return ret;
	if (rounded / 1000000 != value)
		return -ERANGE;
	*rate = rounded;
	return 0;
}

/* The permanent caller must serialize AP0 ownership and hold controller power.
 * Two equal observations detect change, not atomic firmware ownership transfer.
 * Only the reviewed seven PERF voters and one BW voter are addressed.
 */
static inline int cam_cc_crm_startup_read(const struct cam_cc_crm_caps *caps,
		const struct cam_cc_crm_lut tables[8], u32 span,
		cam_cc_crm_lut_read_fn read, void *context,
		struct cam_cc_crm_startup *out)
{
	static const u32 resources[8] = { 0, 1, 2, 3, 4, 6, 7, 0 };
	struct cam_cc_crm_startup result = {};
	u32 offsets[8][CAM_CC_CRM_STATES], status_offsets[8];
	u32 client, state, pass, kind, raw;
	u64 rate;
	int ret;

	if (!tables || !read || !out)
		return -EINVAL;
	/* Validate the complete target set and tables before the first callback. */
	for (client = 0; client < 8; client++) {
		kind = client == 7 ? CAM_CC_CRM_BW : CAM_CC_CRM_PERF;
		ret = cam_cc_crm_lut_pick(&tables[client], 0, &raw, &rate);
		if (ret)
			return ret;
		ret = cam_cc_crm_offset(caps, kind, resources[client],
			CAM_CC_CRM_IRQ_STATUS, CAM_CC_CRM_ACTIVE, span,
			&status_offsets[client]);
		if (ret)
			return ret;
		for (state = 0; state < CAM_CC_CRM_STATES; state++) {
			ret = cam_cc_crm_offset(caps, kind, resources[client],
				CAM_CC_CRM_VOTE, state, span, &offsets[client][state]);
			if (ret)
				return ret;
		}
	}
	for (pass = 0; pass < 2; pass++) {
		for (client = 0; client < 8; client++) {
			kind = client == 7 ? CAM_CC_CRM_BW : CAM_CC_CRM_PERF;
			ret = read(context, status_offsets[client], &raw);
			if (ret)
				return ret < 0 ? ret : -EIO;
			if (raw)
				return -EUCLEAN;
			for (state = 0; state < CAM_CC_CRM_STATES; state++) {
				ret = read(context, offsets[client][state], &raw);
				if (ret)
					return ret < 0 ? ret : -EIO;
				if (pass && raw != result.words[client][state])
					return -EAGAIN;
				ret = cam_cc_crm_startup_rate(&tables[client], kind, raw, &rate);
				if (ret)
					return ret;
				result.words[client][state] = raw;
				result.rates[client][state] = rate;
			}
		}
	}
	for (client = 0; client < 8; client++) {
		ret = read(context, status_offsets[client], &raw);
		if (ret)
			return ret < 0 ? ret : -EIO;
		if (raw)
			return -EUCLEAN;
	}
	*out = result;
	return 0;
}

#endif /* UKE_CAMCC_SM7675_CRM_STARTUP_H */
