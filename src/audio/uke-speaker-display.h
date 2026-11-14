/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_SPEAKER_DISPLAY_H
#define UKE_SPEAKER_DISPLAY_H

/* Four physical amplifier endpoints; the codec owns register/position logic. */
#define UKE_DISPLAY_SPEAKERS 4
struct uke_display_route_ops {
	int (*get)(void *context, unsigned int amplifier, unsigned int *turn);
	int (*set)(void *context, unsigned int amplifier, unsigned int turn);
	void (*fault)(void *context);
};

/* Caller serializes card requests. Existing individual codec controls remain. */
static inline int uke_display_route(void *context,
				    const struct uke_display_route_ops *ops,
				    unsigned int turn)
{
	unsigned int before[UKE_DISPLAY_SPEAKERS], actual, i;
	int ret, first_error, changed = 0;
	bool rollback_failed = false;

	if (turn > 3)
		return -EINVAL;
	for (i = 0; i < UKE_DISPLAY_SPEAKERS; i++) {
		ret = ops->get(context, i, &before[i]);
		if (ret < 0)
			return ret;
		if (before[i] > 3)
			return -EPROTO;
	}
	for (i = 0; i < UKE_DISPLAY_SPEAKERS; i++) {
		if (before[i] == turn)
			continue;
		ret = ops->set(context, i, turn);
		if (ret < 0)
			goto rollback;
		changed = 1;
	}
	for (i = 0; i < UKE_DISPLAY_SPEAKERS; i++) {
		ret = ops->get(context, i, &actual);
		if (ret < 0)
			goto rollback;
		if (actual != turn) {
			ret = -EIO;
			goto rollback;
		}
	}
	return changed;

rollback:
	first_error = ret;
	/* Include a failing writer: its hardware access may have partially applied. */
	for (i = 0; i < UKE_DISPLAY_SPEAKERS; i++) {
		if (ops->set(context, i, before[i]) < 0)
			rollback_failed = true;
		ret = ops->get(context, i, &actual);
		if (ret < 0 || actual != before[i])
			rollback_failed = true;
	}
	if (rollback_failed)
		ops->fault(context);
	return first_error;
}
#endif
