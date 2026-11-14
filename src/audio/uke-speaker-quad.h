/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_SPEAKER_QUAD_H
#define UKE_SPEAKER_QUAD_H

/* Source indices for fixed physical TL, TR, BL, BR output slots. The input
 * order is FL, FR, RL, RR. This changes program material before protection;
 * it does not reorder amplifier identities, calibration or VI feedback. */
static const unsigned int uke_quad_sources[4][4] = {
	{ 0, 1, 2, 3 },
	{ 1, 3, 0, 2 },
	{ 3, 2, 1, 0 },
	{ 2, 0, 3, 1 },
};

static inline int uke_quad_turn(const unsigned int *map, unsigned int channels)
{
	unsigned int turn, slot;

	if (!map || channels != 4)
		return -EINVAL;
	for (turn = 0; turn < 4; turn++) {
		for (slot = 0; slot < 4; slot++)
			if (map[slot] != uke_quad_sources[turn][slot])
				break;
		if (slot == 4)
			return turn;
	}
	return -EINVAL;
}

struct uke_quad_route_ops {
	int (*apply)(void *context, const unsigned int *map);
	void (*fault)(void *context);
};

/* The caller holds the same mutex as graph open/prepare/trigger/close. A
 * failed DSP command may have applied: always send the saved mapping back. */
static inline int uke_quad_route(void *context,
				 const struct uke_quad_route_ops *ops,
				 unsigned int *current_turn, unsigned int target)
{
	int ret;

	if (!ops || !ops->apply || !ops->fault || !current_turn ||
	    *current_turn > 3 || target > 3)
		return -EINVAL;
	if (*current_turn == target)
		return 0;
	ret = ops->apply(context, uke_quad_sources[target]);
	if (ret < 0) {
		if (ops->apply(context, uke_quad_sources[*current_turn]) < 0)
			ops->fault(context);
		return ret;
	}
	*current_turn = target;
	return 1;
}
#endif
