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

/* Synchronous, exact O82 120 Hz four-packet HS TP-FPS group; no queued state. */
#if IS_REACHABLE(CONFIG_DRM_MSM) && IS_ENABLED(CONFIG_DRM_MSM_DSI)
int qcom_uke_dsi_tp_fps_batch(struct mipi_dsi_device *dsi,
			      const struct mipi_dsi_msg *msgs);
#else
static inline int qcom_uke_dsi_tp_fps_batch(struct mipi_dsi_device *dsi,
					 const struct mipi_dsi_msg *msgs)
{
	return -EOPNOTSUPP;
}
#endif
#endif
