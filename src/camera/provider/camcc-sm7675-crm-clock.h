/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Linux software-vote state for a Cliffs CRM RCG. The checked CCF PRE callback
 * sends a prepared rate change after the voltage increase. set_rate() only
 * commits that acknowledged change: Linux 7.3.1 ignores its return value.
 * ABORT restores a completed PRE vote before the wrapper lowers voltage.
 * The caller holds the CCF prepare lock and the controller PM reference.
 * Firmware aggregation is deliberately not reported as this client's rate.
 * Protocol attribution is retained in camcc-sm7675-crm-core.h and -lut.h.
 */
#ifndef UKE_CAMCC_SM7675_CRM_CLOCK_H
#define UKE_CAMCC_SM7675_CRM_CLOCK_H

#include "camcc-sm7675-crm-lut.h"

struct cam_cc_crm_clock {
	const struct cam_cc_crm_lut *table;
	int (*send)(void *context, u32 kind, u32 resource, u32 value);
	void *context;
	u32 kind;
	u32 resource;
	u64 desired;
	u64 old_rate;
	u64 new_rate;
	int fault;
	bool prepared;
	bool staged;
	bool committed;
};

static inline int cam_cc_crm_clock_value(struct cam_cc_crm_clock *c,
					u64 rate, u32 *value)
{
	u64 rounded, quantized;
	u32 level, quantized_level;
	int ret;

	if (!c || !value || !c->send || !cam_cc_crm_owned(c->kind, c->resource))
		return -EINVAL;
	ret = cam_cc_crm_lut_pick(c->table, rate, &level, &rounded);
	if (ret)
		return ret;
	/* CCF must first determine a supported rate; no implicit rounding on set. */
	if (rounded != rate)
		return -ERANGE;
	if (c->kind == CAM_CC_CRM_PERF) {
		*value = level;
		return 0;
	}
	/* OEM sends IB in whole MHz, AB0. Do not round a boundary below its CP. */
	quantized = rate / 1000000;
	if (quantized > 0x3fff || (rate && !quantized))
		return -ERANGE;
	ret = cam_cc_crm_lut_pick(c->table, quantized * 1000000,
				  &quantized_level, &rounded);
	if (ret)
		return ret;
	if (quantized_level != level)
		return -ERANGE;
	*value = quantized;
	return 0;
}

static inline int cam_cc_crm_clock_fail(struct cam_cc_crm_clock *c, int error)
{
	if (!c->fault)
		c->fault = error < 0 ? error : -EIO;
	return c->fault;
}

static inline int cam_cc_crm_clock_send(struct cam_cc_crm_clock *c, u64 rate)
{
	u32 value;
	int ret;

	if (c->fault)
		return c->fault;
	ret = cam_cc_crm_clock_value(c, rate, &value);
	if (!ret)
		ret = c->send(c->context, c->kind, c->resource, value);
	return ret ? cam_cc_crm_clock_fail(c, ret) : 0;
}

/* Called before the voltage helper; a rejected request must not change votes. */
static inline int cam_cc_crm_clock_validate(struct cam_cc_crm_clock *c,
					   u64 old_rate, u64 new_rate)
{
	u32 value;

	if (!c)
		return -EINVAL;
	if (c->fault)
		return c->fault;
	if (c->staged || old_rate != c->desired)
		return -EUCLEAN;
	return cam_cc_crm_clock_value(c, new_rate, &value);
}

static inline int cam_cc_crm_clock_prepare(struct cam_cc_crm_clock *c)
{
	int ret;

	if (c->fault)
		return c->fault;
	if (c->prepared || c->staged)
		return cam_cc_crm_clock_fail(c, -EUCLEAN);
	ret = cam_cc_crm_clock_send(c, c->desired);
	if (!ret)
		c->prepared = true;
	return ret;
}

static inline int cam_cc_crm_clock_unprepare(struct cam_cc_crm_clock *c)
{
	int ret;

	if (c->fault)
		return c->fault;
	if (!c->prepared || c->staged)
		return cam_cc_crm_clock_fail(c, -EUCLEAN);
	ret = cam_cc_crm_clock_send(c, 0);
	if (!ret)
		c->prepared = false;
	return ret;
}

/* The wrapper has already raised voltage; errors must retain those resources. */
static inline int cam_cc_crm_clock_pre(struct cam_cc_crm_clock *c,
				      u64 old_rate, u64 new_rate)
{
	int ret = cam_cc_crm_clock_validate(c, old_rate, new_rate);

	if (ret)
		return cam_cc_crm_clock_fail(c, ret);
	c->old_rate = old_rate;
	c->new_rate = new_rate;
	c->staged = true;
	c->committed = false;
	if (c->prepared && old_rate != new_rate)
		return cam_cc_crm_clock_send(c, new_rate);
	return 0;
}

static inline int cam_cc_crm_clock_commit(struct cam_cc_crm_clock *c, u64 rate)
{
	if (c->fault)
		return c->fault;
	if (!c->staged || c->committed || c->new_rate != rate)
		return cam_cc_crm_clock_fail(c, -EUCLEAN);
	c->desired = rate;
	c->committed = true;
	return 0;
}

/* *voltage says whether the wrapper has a matching PRE voltage to finish. */
static inline int cam_cc_crm_clock_post(struct cam_cc_crm_clock *c,
				       u64 old_rate, u64 new_rate, bool *voltage)
{
	int ret;

	*voltage = false;
	if (c->fault)
		return c->fault;
	/* ABORT traverses clocks whose PRE callback may not have been reached. */
	if (!c->staged)
		return 0;
	if (c->committed) {
		if (old_rate != c->old_rate || new_rate != c->new_rate ||
		    c->desired != new_rate)
			return cam_cc_crm_clock_fail(c, -EUCLEAN);
	} else {
		/* The existing CCF hook passes (requested, original) on ABORT. */
		if (old_rate != c->new_rate || new_rate != c->old_rate ||
		    c->desired != new_rate)
			return cam_cc_crm_clock_fail(c, -EUCLEAN);
		if (c->prepared && old_rate != new_rate) {
			ret = cam_cc_crm_clock_send(c, new_rate);
			if (ret)
				return ret;
		}
	}
	c->staged = false;
	c->committed = false;
	*voltage = true;
	return 0;
}

#endif /* UKE_CAMCC_SM7675_CRM_CLOCK_H */
