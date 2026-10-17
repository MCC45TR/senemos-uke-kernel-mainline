/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _LINUX_QCOM_UKE_DISPLAY_H
#define _LINUX_QCOM_UKE_DISPLAY_H
#include <linux/device.h>
#include <linux/errno.h>
#include <linux/kconfig.h>

/* Call only with display VBIF drained and verified core reset asserted.
 * Old firmware context banks remain reserved; this retires unsecure SMRs only.
 */
#if IS_REACHABLE(CONFIG_ARM_SMMU)
int qcom_uke_display_release(struct device *supplier, struct device *display);
#else
static inline int qcom_uke_display_release(struct device *supplier,
					 struct device *display)
{
	return -ENODEV;
}
#endif

struct mipi_dsi_device;
struct mipi_dsi_msg;
struct drm_panel;
struct drm_display_mode;

/* Registered by the panel so modular MSM never depends on its client module. */
struct qcom_uke_o82_dfps_ops {
	bool (*check)(struct drm_panel *panel, const struct drm_display_mode *old,
		      const struct drm_display_mode *new_mode);
	int (*apply)(struct drm_panel *panel, const struct drm_display_mode *old,
		     const struct drm_display_mode *new_mode, bool before);
};

/* Synchronous, exact O82 four-packet HS TP-FPS group; no queued state. */
#if IS_REACHABLE(CONFIG_DRM_MSM) && IS_ENABLED(CONFIG_DRM_MSM_DSI)
int qcom_uke_dsi_tp_fps_batch(struct mipi_dsi_device *dsi,
			      const struct mipi_dsi_msg *msgs);
int qcom_uke_dsi_pen_clear_batch(struct mipi_dsi_device *dsi,
				 const struct mipi_dsi_msg *msgs);
/* NULL ops unregisters and waits for in-flight callbacks. */
int qcom_uke_dsi_dfps_register(struct mipi_dsi_device *dsi,
		struct drm_panel *panel, const struct qcom_uke_o82_dfps_ops *ops);
/* One bounded LP ON chunk, selected by an explicit O82 panel profile. */
int qcom_uke_dsi_on_batch(struct mipi_dsi_device *dsi,
			 const struct mipi_dsi_msg *msgs, unsigned int count);
/* Exact O82 post-start normal-pixel or dimming LP group. */
int qcom_uke_dsi_lp_batch(struct mipi_dsi_device *dsi,
			 const struct mipi_dsi_msg *msgs, unsigned int count);
#else
static inline int qcom_uke_dsi_tp_fps_batch(struct mipi_dsi_device *dsi,
					 const struct mipi_dsi_msg *msgs)
{
	return -EOPNOTSUPP;
}
static inline int qcom_uke_dsi_pen_clear_batch(struct mipi_dsi_device *dsi,
					 const struct mipi_dsi_msg *msgs)
{
	return -EOPNOTSUPP;
}
static inline int qcom_uke_dsi_dfps_register(struct mipi_dsi_device *dsi,
		struct drm_panel *panel, const struct qcom_uke_o82_dfps_ops *ops)
{
	return -EOPNOTSUPP;
}
static inline int qcom_uke_dsi_on_batch(struct mipi_dsi_device *dsi,
				      const struct mipi_dsi_msg *msgs, unsigned int count)
{
	return -EOPNOTSUPP;
}
static inline int qcom_uke_dsi_lp_batch(struct mipi_dsi_device *dsi,
				      const struct mipi_dsi_msg *msgs, unsigned int count)
{
	return -EOPNOTSUPP;
}
#endif
#endif
