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
#endif
