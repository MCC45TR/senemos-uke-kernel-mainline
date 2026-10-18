/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _DRM_QCOM_UKE_O82_AVR_H
#define _DRM_QCOM_UKE_O82_AVR_H

#include <linux/math64.h>
#include <drm/uke-o82-mode.h>

/* Experimental request floor from the lowest OEM mode, not a VRR rating. */
static inline int qcom_uke_o82_avr_lines(const struct drm_display_mode *mode,
				      unsigned int min_hz)
{
	u64 lines;

	if (min_hz < 30 || !qcom_uke_o82_mode(mode))
		return -EINVAL;
	lines = div64_u64((u64)mode->clock * 1000, (u64)mode->htotal * min_hz);
	/* Floor keeps the longest frame at or above the requested minimum Hz. */
	/* Retain an OEM base whose integer-kHz clock rounds below nominal Hz. */
	if (lines + 1 == (u64)mode->vtotal)
		lines = mode->vtotal;
	if (lines < (u64)mode->vtotal || lines > 65535)
		return -EINVAL;
	return lines;
}

#endif
