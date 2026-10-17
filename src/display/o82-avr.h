/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _DRM_QCOM_UKE_O82_AVR_H
#define _DRM_QCOM_UKE_O82_AVR_H

#include <linux/math64.h>
#include <drm/uke-o82-mode.h>

/* Development bound, not a panel rating: at most 32 extra lines at OEM 120 Hz. */
static inline int qcom_uke_o82_avr_lines(const struct drm_display_mode *mode,
				      unsigned int min_hz)
{
	u64 lines;

	if (!min_hz || qcom_uke_o82_mode_group(mode) != 0 || mode->vtotal != 2310)
		return -EINVAL;
	lines = div64_u64((u64)mode->clock * 1000, (u64)mode->htotal * min_hz);
	/* Floor keeps the longest frame at or above the requested minimum Hz. */
	if (lines <= (u64)mode->vtotal || lines > (u64)mode->vtotal + 32)
		return -EINVAL;
	return lines;
}

#endif
