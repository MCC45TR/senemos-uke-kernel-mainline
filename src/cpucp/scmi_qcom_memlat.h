/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _LINUX_SCMI_QCOM_MEMLAT_H
#define _LINUX_SCMI_QCOM_MEMLAT_H

#include <linux/types.h>

struct scmi_protocol_handle;

/* Units, monitor ownership and timestamp epoch require firmware admission. */
struct scmi_qcom_memlat_ops {
	int (*timestamp_raw)(const struct scmi_protocol_handle *ph, u64 *value);
	int (*current_raw)(const struct scmi_protocol_handle *ph, u32 hardware,
			   u32 monitor, u32 *value);
	int (*adaptive_raw)(const struct scmi_protocol_handle *ph, u32 hardware, u32 *value);
};

/* No protocol registration until its actual revision and algorithm are admitted. */
extern const struct scmi_qcom_memlat_ops scmi_qcom_memlat_read_ops;

#endif
