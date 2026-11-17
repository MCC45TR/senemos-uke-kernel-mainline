/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef QCOM_SM7675_CAMCC_H
#define QCOM_SM7675_CAMCC_H

#include <linux/errno.h>
#include <linux/kconfig.h>

/* Cached ownership/fault state only; this function performs no hardware I/O. */
#if IS_ENABLED(CONFIG_SM_CAMCC_7675)
int qcom_sm7675_camcc_status(void);
#else
static inline int qcom_sm7675_camcc_status(void)
{
	return -ENODEV;
}
#endif

#endif /* QCOM_SM7675_CAMCC_H */
