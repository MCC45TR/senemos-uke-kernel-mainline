/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_SSC_DUAL_LIGHT_H
#define UKE_SSC_DUAL_LIGHT_H

#include <linux/errno.h>
#include <linux/types.h>

/* Measurement reduction only. The owner serializes access and admits SSC ACK,
 * metadata, sample status and channel units before calling these functions.
 * Acquisition epochs must advance across every stop/restart, including one
 * within the same DSP namespace. This state never requests or polls hardware.
 */
struct uke_ssc_light_pair {
	u64 epoch, ticks[2];
	s64 micro_lux[2], last_output;
	unsigned int valid;
	bool active, lid_known, lid_closed, have_output;
};

enum uke_ssc_light_side {
	UKE_SSC_LIGHT_FRONT,
	UKE_SSC_LIGHT_REAR,
};

static inline unsigned int
uke_ssc_light_required(const struct uke_ssc_light_pair *pair)
{
	return pair->lid_known && pair->lid_closed ? 2U : 3U;
}

/* 1: a new valid reading, 0: unchanged, negative: no valid output. */
static inline int uke_ssc_light_result(struct uke_ssc_light_pair *pair, s64 *out)
{
	unsigned int required = uke_ssc_light_required(pair);
	s64 value;

	if (!pair->active)
		return -ENODEV;
	if ((pair->valid & required) != required)
		return -EAGAIN;
	value = pair->micro_lux[UKE_SSC_LIGHT_REAR];
	if (required == 3U && pair->micro_lux[UKE_SSC_LIGHT_FRONT] > value)
		value = pair->micro_lux[UKE_SSC_LIGHT_FRONT];
	if (pair->have_output && pair->last_output == value)
		return 0;
	pair->last_output = value;
	pair->have_output = true;
	*out = value;
	return 1;
}

static inline int uke_ssc_light_begin(struct uke_ssc_light_pair *pair,
				      u64 epoch, bool lid_known, bool lid_closed)
{
	if (!epoch || epoch <= pair->epoch || pair->active)
		return -EINVAL;
	*pair = (struct uke_ssc_light_pair) {
		.epoch = epoch, .active = true,
		.lid_known = lid_known, .lid_closed = lid_closed,
	};
	return 0;
}

static inline void uke_ssc_light_end(struct uke_ssc_light_pair *pair)
{
	u64 epoch = pair->epoch;

	/* Forget measurements while retaining the stale-epoch admission boundary. */
	*pair = (struct uke_ssc_light_pair) { .epoch = epoch };
}

static inline int uke_ssc_light_update(struct uke_ssc_light_pair *pair,
				       u64 epoch, unsigned int side,
				       u64 ticks, s64 micro_lux, s64 *out)
{
	if (side > UKE_SSC_LIGHT_REAR)
		return -EINVAL;
	if (!pair->active)
		return -ENODEV;
	if (epoch != pair->epoch || !ticks || ticks <= pair->ticks[side])
		return -ESTALE;
	/* An occluded front sensor cannot contribute to rear-only output. */
	if (!(uke_ssc_light_required(pair) & (1U << side))) {
		/* Retain the watermark so a late closed-cover indication cannot
		 * masquerade as the first fresh front sample after reopening.
		 */
		pair->ticks[side] = ticks;
		return 0;
	}
	if (micro_lux < 0)
		return -ERANGE;
	pair->ticks[side] = ticks;
	pair->micro_lux[side] = micro_lux;
	pair->valid |= 1U << side;
	return uke_ssc_light_result(pair, out);
}

/* The caller supplies an actual Hall input event or a verified initial state.
 * It reconciles the returned required mask in its serialized lifecycle worker.
 */
static inline int uke_ssc_light_lid(struct uke_ssc_light_pair *pair,
				    bool known, bool closed, s64 *out)
{
	unsigned int before = uke_ssc_light_required(pair);

	pair->lid_known = known;
	pair->lid_closed = closed;
	if (before == 2U && uke_ssc_light_required(pair) == 3U) {
		/* Wait for a new front indication after uncovering, never cached light. */
		pair->valid &= ~1U;
		pair->micro_lux[UKE_SSC_LIGHT_FRONT] = 0;
		pair->have_output = false;
	}
	return uke_ssc_light_result(pair, out);
}
#endif
