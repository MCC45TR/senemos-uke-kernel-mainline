/* SPDX-License-Identifier: GPL-2.0-only */
/* Include after camcc-sm7675-data.h in the permanent native provider. */
#ifndef UKE_CAMCC_SM7675_POWER_H
#define UKE_CAMCC_SM7675_POWER_H

#include <linux/clk.h>
#include <linux/io.h>
#include <linux/pm_runtime.h>
#include <linux/spinlock.h>

#define CAM_CC_POWER_RAILS GENMASK(2, 0)

static struct {
	struct device *dev;
	struct clk *iface;
	void __iomem *base;
	unsigned int votes;
	unsigned int uncertain_rails;
	bool iface_on;
	int fault;
	int primary_error;
	int rollback_error;
} cam_cc_power;
static DEFINE_SPINLOCK(cam_cc_power_lock);

static int cam_cc_power_fail(int primary, int rollback, unsigned int uncertain)
{
	unsigned long flags;

	/* Fault publication must wait for an in-flight checked MMIO transaction. */
	spin_lock_irqsave(&cam_cc_power_lock, flags);
	cam_cc_power.uncertain_rails |= uncertain;
	if (!cam_cc_power.fault) {
		cam_cc_power.primary_error = primary;
		cam_cc_power.rollback_error = rollback;
		WRITE_ONCE(cam_cc_power.fault, -EIO);
	}
	spin_unlock_irqrestore(&cam_cc_power_lock, flags);
	return -EIO;
}

static int cam_cc_power_rail(unsigned int rail, bool on)
{
	struct clk_vdd_class_data vote = {
		.vdd_class = cam_cc_sm7675_regulators[rail],
	};

	return on ? clk_vote_vdd_level(&vote, VDD_MIN) :
		    clk_unvote_vdd_level(&vote, VDD_MIN);
}

static int __maybe_unused cam_cc_power_resume(struct device *dev)
{
	int rail, ret, rollback;

	if (dev_get_drvdata(dev) != &cam_cc_power || cam_cc_power.dev != dev)
		return -ENODEV;
	if (cam_cc_power.fault)
		return cam_cc_power.fault;
	if (cam_cc_power.iface_on && cam_cc_power.votes == CAM_CC_POWER_RAILS)
		return 0;
	if (cam_cc_power.iface_on || cam_cc_power.votes)
		return cam_cc_power_fail(-EUCLEAN, 0, 0);

	for (rail = 0; rail < ARRAY_SIZE(cam_cc_sm7675_regulators); rail++) {
		ret = cam_cc_power_rail(rail, true);
		if (ret)
			/* The voltage helper cannot qualify backend rollback on error. */
			return cam_cc_power_fail(ret, 0, BIT(rail));
		WRITE_ONCE(cam_cc_power.votes, cam_cc_power.votes | BIT(rail));
	}

	ret = clk_prepare_enable(cam_cc_power.iface);
	if (!ret) {
		WRITE_ONCE(cam_cc_power.iface_on, true);
		return 0;
	}

	cam_cc_power.primary_error = ret;
	for (rail--; rail >= 0; rail--) {
		rollback = cam_cc_power_rail(rail, false);
		if (rollback)
			return cam_cc_power_fail(ret, rollback, BIT(rail));
		WRITE_ONCE(cam_cc_power.votes, cam_cc_power.votes & ~BIT(rail));
	}
	return ret;
}

static int __maybe_unused cam_cc_power_suspend(struct device *dev)
{
	int rail, ret;

	if (dev_get_drvdata(dev) != &cam_cc_power || cam_cc_power.dev != dev)
		return -ENODEV;
	if (cam_cc_power.fault)
		return cam_cc_power.fault;

	/* Forced system suspend bypasses the normal runtime usage checks. */
	if (atomic_read(&dev->power.usage_count) || atomic_read(&dev->power.child_count))
		return -EBUSY;
	for (rail = 0; rail < ARRAY_SIZE(cam_cc_sm7675_gdscs); rail++)
		if (READ_ONCE(cam_cc_sm7675_gdscs[rail]->controller_pm_held))
			return -EBUSY;

	if (!cam_cc_power.iface_on && !cam_cc_power.votes)
		return 0;
	if (!cam_cc_power.iface_on || cam_cc_power.votes != CAM_CC_POWER_RAILS)
		return cam_cc_power_fail(-EUCLEAN, 0, 0);

	clk_disable_unprepare(cam_cc_power.iface);
	WRITE_ONCE(cam_cc_power.iface_on, false);
	for (rail = ARRAY_SIZE(cam_cc_sm7675_regulators) - 1; rail >= 0; rail--) {
		ret = cam_cc_power_rail(rail, false);
		if (ret)
			return cam_cc_power_fail(ret, 0, BIT(rail));
		WRITE_ONCE(cam_cc_power.votes, cam_cc_power.votes & ~BIT(rail));
	}
	return 0;
}

static int cam_cc_power_access(void *context, unsigned int reg)
{
	if (context != &cam_cc_power)
		return -EINVAL;
	if (reg > cam_cc_sm7675_regmap_config.max_register || reg % sizeof(u32))
		return -EINVAL;
	if (READ_ONCE(cam_cc_power.fault))
		return READ_ONCE(cam_cc_power.fault);
	if (!cam_cc_power.base || !READ_ONCE(cam_cc_power.iface_on) ||
	    READ_ONCE(cam_cc_power.votes) != CAM_CC_POWER_RAILS)
		return -EHOSTDOWN;
	return 0;
}

static int cam_cc_power_read(void *context, unsigned int reg, unsigned int *value)
{
	unsigned long flags;
	int ret;

	if (!value)
		return -EINVAL;
	spin_lock_irqsave(&cam_cc_power_lock, flags);
	ret = cam_cc_power_access(context, reg);
	if (!ret)
		*value = readl(cam_cc_power.base + reg);
	spin_unlock_irqrestore(&cam_cc_power_lock, flags);
	return ret;
}

static int cam_cc_power_write(void *context, unsigned int reg, unsigned int value)
{
	unsigned long flags;
	int ret;

	spin_lock_irqsave(&cam_cc_power_lock, flags);
	ret = cam_cc_power_access(context, reg);
	if (!ret)
		writel(value, cam_cc_power.base + reg);
	spin_unlock_irqrestore(&cam_cc_power_lock, flags);
	return ret;
}

static const struct regmap_config cam_cc_power_regmap_config = {
	CAM_CC_SM7675_REGMAP_FORMAT,
	.reg_read = cam_cc_power_read,
	.reg_write = cam_cc_power_write,
};

static int cam_cc_power_init(struct device *dev, void __iomem *base, resource_size_t size)
{
	static const char * const supplies[] = { "vdd_mm", "vdd_mx", "vdd_mxc" };
	struct clk *iface;
	struct regulator *supply;
	int rail, ret;

	static_assert(ARRAY_SIZE(supplies) == ARRAY_SIZE(cam_cc_sm7675_regulators));
	if (cam_cc_power.dev || dev_get_drvdata(dev))
		return -EBUSY;
	if (IS_ERR(base))
		return PTR_ERR(base);
	if (!base || size < cam_cc_sm7675_regmap_config.max_register + sizeof(u32))
		return -EINVAL;
	ret = cam_cc_validate_voltage_data();
	if (ret)
		return ret;
	iface = clk_get(dev, "iface");
	if (IS_ERR(iface))
		return PTR_ERR(iface);
	for (rail = 0; rail < ARRAY_SIZE(supplies); rail++) {
		cam_cc_sm7675_regulators[rail]->class_name = supplies[rail];
		cam_cc_sm7675_regulators[rail]->regulator_names[0] = supplies[rail];
		/* Required supplies must fail on absence instead of accepting a dummy. */
		supply = regulator_get_optional(dev, supplies[rail]);
		if (IS_ERR(supply)) {
			for (rail--; rail >= 0; rail--)
				regulator_put(cam_cc_sm7675_regulators[rail]->regulator[0]);
			clk_regulator_deinit(&cam_cc_sm7675_desc);
			clk_put(iface);
			return PTR_ERR(supply);
		}
		cam_cc_sm7675_regulators[rail]->regulator[0] = supply;
	}

	/* These handles outlive failed binding and ambiguous power transitions. */
	cam_cc_power.dev = get_device(dev);
	cam_cc_power.iface = iface;
	cam_cc_power.base = base;
	dev_set_drvdata(dev, &cam_cc_power);
	return 0;
}

static const struct dev_pm_ops cam_cc_power_pm_ops = {
	RUNTIME_PM_OPS(cam_cc_power_suspend, cam_cc_power_resume, NULL)
	SYSTEM_SLEEP_PM_OPS(pm_runtime_force_suspend, pm_runtime_force_resume)
};

#endif /* UKE_CAMCC_SM7675_POWER_H */
