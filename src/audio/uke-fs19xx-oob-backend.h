/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_FS19XX_OOB_BACKEND_H
#define UKE_FS19XX_OOB_BACKEND_H
#include <linux/types.h>
struct q6apm;
int q6apm_fs19xx_oob_send(struct q6apm *apm, u32 instance, u32 parameter,
			 const u8 *data, size_t bytes);
#endif
