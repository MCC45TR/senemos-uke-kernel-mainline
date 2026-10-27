/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _DRM_QCOM_UKE_O82_AVR_H
#define _DRM_QCOM_UKE_O82_AVR_H

#include <linux/math64.h>
#include <linux/limits.h>
#include <drm/uke-o82-mode.h>

/* Source timing arithmetic only; receiver/touch admission is the caller's job. */
static inline int qcom_uke_o82_avr_lines(const struct drm_display_mode *mode,
				      unsigned int min_hz)
{
	u64 lines;

	if (!min_hz || !qcom_uke_o82_mode(mode))
		return -EINVAL;
	lines = div64_u64((u64)mode->clock * 1000, (u64)mode->htotal * min_hz);
	/* Floor keeps the longest frame at or above the requested minimum Hz. */
	/* Retain an OEM base whose integer-kHz clock rounds below nominal Hz. */
	if (lines + 1 == (u64)mode->vtotal)
		lines = mode->vtotal;
	/* AVR stores a 32-bit pixel period, not a 16-bit DRM mode vtotal. */
	if (lines < (u64)mode->vtotal || lines * mode->htotal > U32_MAX)
		return -EINVAL;
	return lines;
}

#endif
