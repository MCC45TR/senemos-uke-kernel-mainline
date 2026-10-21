// SPDX-License-Identifier: GPL-2.0-only
/* Kernel object fixture only; does not register a driver or access hardware. */
#include "camcc-sm7675-data.h"

static_assert(ARRAY_SIZE(cam_cc_sm7675_clocks) == 137);
static_assert(ARRAY_SIZE(cam_cc_sm7675_gdscs) == 8);
static_assert(ARRAY_SIZE(cam_cc_sm7675_resets) == 10);
static_assert(ARRAY_SIZE(cam_cc_voltage_clocks) == 44);

const struct qcom_cc_desc *uke_camcc_data_check(void);

const struct qcom_cc_desc *uke_camcc_data_check(void)
{
	if (cam_cc_validate_voltage_data())
		return NULL;
	return &cam_cc_sm7675_desc;
}
