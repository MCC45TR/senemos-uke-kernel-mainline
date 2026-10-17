/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _DRM_QCOM_UKE_O82_MODE_H
#define _DRM_QCOM_UKE_O82_MODE_H

#include <linux/errno.h>
#include <drm/drm_modes.h>

/* Exact OEM VFP groups; board, panel and link admission remain the caller's job. */
static inline int qcom_uke_o82_mode_group(const struct drm_display_mode *mode)
{
	int group = -EINVAL;

	if (!mode || mode->hdisplay != 3200 || mode->vdisplay != 2136 ||
	    mode->flags || mode->hskew || mode->vscan)
		return -EINVAL;

	switch (mode->clock) {
	case 967428:
		if (mode->htotal == 3490 &&
		    (mode->vtotal == 2310 || mode->vtotal == 4620))
			group = 0;
		break;
	case 1097712:
		if (mode->htotal == 3300 && mode->vtotal == 2310)
			group = 1;
		break;
	case 804988:
		if (mode->htotal == 3872 &&
		    (mode->vtotal == 2310 || mode->vtotal == 4158 ||
		     mode->vtotal == 4331 || mode->vtotal == 6930))
			group = 2;
		break;
	}
	if (group < 0 || mode->hsync_start != mode->htotal - 64 ||
	    mode->hsync_end != mode->htotal - 32 ||
	    mode->vsync_start != mode->vtotal - 148 ||
	    mode->vsync_end != mode->vtotal - 146)
		return -EINVAL;
	return group;
}

static inline bool qcom_uke_o82_mode(const struct drm_display_mode *mode)
{
	return qcom_uke_o82_mode_group(mode) >= 0;
}

/* Within one OEM timing group only VFP changes; DDIC and touch commands stay put. */
static inline bool qcom_uke_o82_vfp_change(const struct drm_display_mode *old,
					const struct drm_display_mode *new_mode)
{
	int group = qcom_uke_o82_mode_group(old);

	return group >= 0 && group == qcom_uke_o82_mode_group(new_mode) &&
		old->vtotal != new_mode->vtotal;
}

#endif
