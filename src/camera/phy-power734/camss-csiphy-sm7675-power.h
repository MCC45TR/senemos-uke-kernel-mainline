/* SPDX-License-Identifier: GPL-2.0-only */
/* Demand-scoped Uke PHY supply votes. No DT activation or sensor operation. */
#ifndef UKE_CAMSS_CSIPHY_SM7675_POWER_H
#define UKE_CAMSS_CSIPHY_SM7675_POWER_H

#include <linux/device/driver.h>
#include <linux/limits.h>
#include <linux/mutex.h>
#include <linux/of.h>
#include <linux/slab.h>
#include <linux/soc/qcom/sm7675-camcc.h>

struct csiphy_sm7675_power {
	struct device *dev;
	struct regulator_bulk_data supplies[2];
	struct mutex lock;
	unsigned int voted;
	unsigned int enabled;
	bool pm_held;
	bool clocks;
	bool irq;
	bool active;
	int fault;
};

/* Fault records own their allocation, device and regulator references. */
static void csiphy_sm7675_power_release(void *data)
{
	struct csiphy_sm7675_power *power = data;
	unsigned int i;

	if (power->fault || power->active || power->voted || power->enabled ||
	    power->pm_held || power->clocks || power->irq) {
		dev_err(power->dev, "PHY supply ownership retained until reboot\n");
		return;
	}
	for (i = ARRAY_SIZE(power->supplies); i-- > 0;)
		regulator_put(power->supplies[i].consumer);
	put_device(power->dev);
	kfree(power);
}

static int csiphy_sm7675_owner_check(struct camss *camss)
{
	struct device *dev = camss->dev;

	/* A fault cannot rely on module text, devres or removable DT storage. */
	if (!of_machine_is_compatible("xiaomi,uke") || !dev->of_node ||
	    of_node_check_flag(dev->of_node, OF_DYNAMIC) || !dev->driver ||
	    dev->driver->owner || !dev->driver->suppress_bind_attrs)
		return -EINVAL;
	return qcom_sm7675_camcc_status();
}

static int csiphy_sm7675_power_init(struct csiphy_device *csiphy,
				  const struct camss_subdev_resources *res)
{
	struct csiphy_sm7675_power *power;
	unsigned int i;
	int ret;

	if (csiphy->num_supplies != 2)
		return -EINVAL;
	for (i = 0; i < 2; i++)
		if (!csiphy->res->voltage[i].min_uV ||
		    csiphy->res->voltage[i].min_uV > csiphy->res->voltage[i].max_uV)
			return -EINVAL;
	power = kzalloc(sizeof(*power), GFP_KERNEL);
	if (!power)
		return -ENOMEM;
	power->dev = get_device(csiphy->camss->dev);
	mutex_init(&power->lock);
	for (i = 0; i < 2; i++) {
		power->supplies[i] = res->regulators[i];
		power->supplies[i].consumer = regulator_get(power->dev,
							  power->supplies[i].supply);
		if (IS_ERR(power->supplies[i].consumer)) {
			ret = PTR_ERR(power->supplies[i].consumer);
			while (i-- > 0)
				regulator_put(power->supplies[i].consumer);
			put_device(power->dev);
			kfree(power);
			return ret;
		}
	}
	ret = devm_add_action_or_reset(power->dev, csiphy_sm7675_power_release, power);
	if (ret)
		return ret;
	csiphy->supplies = power->supplies;
	csiphy->uke_power = power;
	return 0;
}

static int csiphy_sm7675_power_fault(struct csiphy_sm7675_power *power, int error)
{
	power->fault = error < 0 ? error : -EIO;
	dev_err(power->dev, "PHY power fault %d; ownership retained until reboot\n",
		power->fault);
	return power->fault;
}

/* The caller serializes both first-on and last-off with this instance lock. */
static int csiphy_sm7675_set_power(struct csiphy_device *csiphy, int on)
{
	struct csiphy_sm7675_power *power = csiphy->uke_power;
	struct device *dev = csiphy->camss->dev;
	int i, ret;

	if (!power)
		return -EINVAL;
	mutex_lock(&power->lock);
	if (power->fault) {
		ret = power->fault;
		goto out;
	}
	if (!!on == power->active) {
		ret = on ? qcom_sm7675_camcc_status() : 0;
		if (ret)
			goto fault;
		goto out;
	}
	ret = qcom_sm7675_camcc_status();
	if (ret)
		goto fault;
	if (on) {
		ret = pm_runtime_resume_and_get(dev);
		if (ret < 0)
			goto out;
		power->pm_held = true;
		ret = csiphy_set_clock_rates(csiphy);
		if (ret < 0) {
			int primary = ret;

			if (qcom_sm7675_camcc_status())
				goto fault;
			ret = pm_runtime_put_sync(dev);
			power->pm_held = false;
			if (ret >= 0)
				ret = qcom_sm7675_camcc_status();
			if (ret < 0) {
				pm_runtime_get_noresume(dev);
				power->pm_held = true;
				goto fault;
			}
			ret = primary;
			goto out;
		}
		for (i = 0; i < 2; i++) {
			ret = regulator_set_voltage(power->supplies[i].consumer,
				csiphy->res->voltage[i].min_uV,
				csiphy->res->voltage[i].max_uV);
			if (ret)
				goto fault;
			power->voted |= BIT(i);
			ret = regulator_set_load(power->supplies[i].consumer,
						 power->supplies[i].init_load_uA);
			if (ret)
				goto fault;
		}
		for (i = 0; i < 2; i++) {
			ret = regulator_enable(power->supplies[i].consumer);
			if (ret)
				goto fault;
			power->enabled |= BIT(i);
		}
		ret = camss_enable_clocks(csiphy->nclocks, csiphy->clock, dev);
		if (ret)
			goto fault;
		power->clocks = true;
		ret = qcom_sm7675_camcc_status();
		if (ret)
			goto fault;
		enable_irq(csiphy->irq);
		power->irq = true;
		csiphy->res->hw_ops->reset(csiphy);
		csiphy->res->hw_ops->hw_version_read(csiphy, dev);
		ret = qcom_sm7675_camcc_status();
		if (ret)
			goto fault;
		power->active = true;
	} else {
		disable_irq(csiphy->irq);
		power->irq = false;
		camss_disable_clocks(csiphy->nclocks, csiphy->clock);
		ret = qcom_sm7675_camcc_status();
		if (ret)
			goto fault;
		power->clocks = false;
		for (i = 1; i >= 0; i--) {
			ret = regulator_disable(power->supplies[i].consumer);
			if (ret)
				goto fault;
			power->enabled &= ~BIT(i);
		}
		/* Withdraw only this consumer's requests, after both rails are off. */
		for (i = 1; i >= 0; i--) {
			ret = regulator_set_load(power->supplies[i].consumer, 0);
			if (ret)
				goto fault;
			ret = regulator_set_voltage(power->supplies[i].consumer, 0, INT_MAX);
			if (ret)
				goto fault;
			power->voted &= ~BIT(i);
		}
		ret = pm_runtime_put_sync(dev);
		power->pm_held = false;
		if (ret >= 0)
			ret = qcom_sm7675_camcc_status();
		if (ret < 0) {
			pm_runtime_get_noresume(dev);
			power->pm_held = true;
			goto fault;
		}
		power->active = false;
	}
	ret = 0;
	goto out;
fault:
	if (power->irq) {
		disable_irq(csiphy->irq);
		power->irq = false;
	}
	ret = csiphy_sm7675_power_fault(power, ret);
out:
	mutex_unlock(&power->lock);
	return ret;
}

#endif /* UKE_CAMSS_CSIPHY_SM7675_POWER_H */
