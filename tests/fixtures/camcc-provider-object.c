// SPDX-License-Identifier: GPL-2.0-only
/* Object fixture only: no driver registration, binding or hardware execution. */
#include "camcc-sm7675-data.h"
#include "provider/camcc-sm7675-power.h"

struct regmap *uke_camcc_provider_map_check(struct device *dev, void __iomem *base,
					 resource_size_t size);
const struct dev_pm_ops *uke_camcc_provider_pm_check(void);

struct regmap *uke_camcc_provider_map_check(struct device *dev, void __iomem *base,
					 resource_size_t size)
{
	int ret = cam_cc_power_init(dev, base, size);

	if (ret)
		return ERR_PTR(ret);
	return devm_regmap_init(dev, NULL, &cam_cc_power, &cam_cc_power_regmap_config);
}

const struct dev_pm_ops *uke_camcc_provider_pm_check(void)
{
	return &cam_cc_power_pm_ops;
}
