// SPDX-License-Identifier: GPL-2.0-only
/* Permanent native provider; source candidate, outside the active build. */
#include <linux/init.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>

#define CAM_CC_GDSC_PM_FLAGS (POLL_CFG_GDSCR | RETAIN_FF_ENABLE | GDSC_CONTROLLER_PM)
#include "camcc-sm7675-data.h"
#include "provider/camcc-sm7675-power.h"

static const struct clk_ops * const cam_cc_native_base_ops[] = {
	&clk_alpha_pll_lucid_evo_ops, &clk_alpha_pll_rivian_evo_ops,
	&clk_alpha_pll_postdiv_lucid_ole_ops, &clk_rcg2_shared_ops, &clk_branch2_ops,
};
static struct clk_ops cam_cc_native_ops[ARRAY_SIZE(cam_cc_native_base_ops)];
static struct clk_init_data cam_cc_native_inits[ARRAY_SIZE(cam_cc_sm7675_clocks)];
static const struct clk_ops *cam_cc_native_original[ARRAY_SIZE(cam_cc_sm7675_clocks)];
static bool cam_cc_native_clocks_ready;
static bool cam_cc_native_probe_held;
static bool cam_cc_native_proxy_active;
static bool cam_cc_native_published;
static bool cam_cc_native_reset_registered;
static struct qcom_reset_controller cam_cc_native_reset;

static void cam_cc_native_detach(void *data);

static int cam_cc_native_fault(int error, unsigned int uncertain)
{
	if (READ_ONCE(cam_cc_power.fault))
		return READ_ONCE(cam_cc_power.fault);
	return cam_cc_power_fail(error, 0, uncertain);
}

static const struct clk_ops *cam_cc_native_original_ops(struct clk_hw *hw)
{
	unsigned int i;

	for (i = 0; i < ARRAY_SIZE(cam_cc_sm7675_clocks); i++)
		if (cam_cc_sm7675_clocks[i] && &cam_cc_sm7675_clocks[i]->hw == hw)
			return cam_cc_native_original[i];
	return NULL;
}

static int cam_cc_native_clock_prepare(struct clk_hw *hw)
{
	const struct clk_ops *ops = cam_cc_native_original_ops(hw);
	struct clk_regmap *clock = to_clk_regmap(hw);
	int ret;

	if (!ops)
		return -EINVAL;
	ret = cam_cc_power_access(&cam_cc_power, 0);
	if (ret)
		return ret;
	if (clock->vdd_data.rate_max) {
		ret = clk_find_vdd_level(hw, &clock->vdd_data, clk_hw_get_rate(hw));
		if (ret < 0)
			return ret;
		ret = clk_prepare_regmap(hw);
		if (ret)
			return cam_cc_native_fault(ret, CAM_CC_POWER_RAILS);
	}
	ret = ops->prepare ? ops->prepare(hw) : 0;
	if (ret)
		/* Keep voltage votes after a failed hardware preparation. */
		return cam_cc_native_fault(ret, 0);
	return 0;
}

static void cam_cc_native_clock_unprepare(struct clk_hw *hw)
{
	const struct clk_ops *ops = cam_cc_native_original_ops(hw);
	struct clk_regmap *clock = to_clk_regmap(hw);
	int ret;

	if (!ops || cam_cc_power_access(&cam_cc_power, 0))
		return;
	if (ops->unprepare)
		ops->unprepare(hw);
	if (clock->vdd_data.rate_max) {
		ret = clk_unvote_vdd_level(&clock->vdd_data, clock->vdd_data.vdd_level);
		if (ret)
			cam_cc_native_fault(ret, CAM_CC_POWER_RAILS);
	}
}

static int cam_cc_native_clock_pre_rate(struct clk_hw *hw, unsigned long old,
					unsigned long rate)
{
	struct clk_regmap *clock = to_clk_regmap(hw);
	int ret = cam_cc_power_access(&cam_cc_power, 0);

	if (ret || !clock->vdd_data.rate_max)
		return ret;
	ret = clk_find_vdd_level(hw, &clock->vdd_data, rate);
	if (ret < 0)
		return ret;
	ret = clk_pre_change_regmap(hw, old, rate);
	return ret ? cam_cc_native_fault(ret, CAM_CC_POWER_RAILS) : 0;
}

static int cam_cc_native_clock_post_rate(struct clk_hw *hw, unsigned long old,
					 unsigned long rate)
{
	int ret = cam_cc_power_access(&cam_cc_power, 0);

	if (ret)
		return ret;
	ret = clk_post_change_regmap(hw, old, rate);
	return ret ? cam_cc_native_fault(ret, CAM_CC_POWER_RAILS) : 0;
}

static int cam_cc_native_clock_enable(struct clk_hw *hw)
{
	const struct clk_ops *ops = cam_cc_native_original_ops(hw);
	int ret = cam_cc_power_access(&cam_cc_power, 0);

	if (ret)
		return ret;
	ret = ops->enable(hw);
	return ret ? cam_cc_native_fault(ret, 0) : 0;
}

static void cam_cc_native_clock_disable(struct clk_hw *hw)
{
	const struct clk_ops *ops = cam_cc_native_original_ops(hw);
	int ret;

	if (cam_cc_power_access(&cam_cc_power, 0))
		return;
	ops->disable(hw);
	if (ops->is_enabled) {
		ret = ops->is_enabled(hw);
		if (ret)
			cam_cc_native_fault(ret < 0 ? ret : -EBUSY, 0);
	}
}

static int cam_cc_native_clock_set_rate(struct clk_hw *hw, unsigned long rate,
					unsigned long parent_rate)
{
	const struct clk_ops *ops = cam_cc_native_original_ops(hw);
	int ret = cam_cc_power_access(&cam_cc_power, 0);

	if (ret)
		return ret;
	ret = ops->set_rate(hw, rate, parent_rate);
	return ret ? cam_cc_native_fault(ret, 0) : 0;
}

static int cam_cc_native_clock_set_parent(struct clk_hw *hw, u8 parent)
{
	const struct clk_ops *ops = cam_cc_native_original_ops(hw);
	struct clk_regmap *clock = to_clk_regmap(hw);
	struct clk_hw *parent_hw;
	unsigned long old = clk_hw_get_rate(hw), rate = old;
	int ret = cam_cc_power_access(&cam_cc_power, 0);

	if (ret)
		return ret;
	/* The existing CCF parent-only path does not call the voltage hooks. */
	if (clock->vdd_data.rate_max) {
		parent_hw = clk_hw_get_parent_by_index(hw, parent);
		if (IS_ERR_OR_NULL(parent_hw) || !ops->recalc_rate)
			return -EINVAL;
		rate = ops->recalc_rate(hw, clk_hw_get_rate(parent_hw));
		ret = cam_cc_native_clock_pre_rate(hw, old, rate);
		if (ret)
			return ret;
	}
	ret = ops->set_parent(hw, parent);
	if (ret)
		return cam_cc_native_fault(ret, 0);
	return clock->vdd_data.rate_max ? cam_cc_native_clock_post_rate(hw, old, rate) : 0;
}

static int cam_cc_native_clock_set_rate_parent(struct clk_hw *hw, unsigned long rate,
					       unsigned long parent_rate, u8 parent)
{
	const struct clk_ops *ops = cam_cc_native_original_ops(hw);
	int ret = cam_cc_power_access(&cam_cc_power, 0);

	if (ret)
		return ret;
	ret = ops->set_rate_and_parent(hw, rate, parent_rate, parent);
	return ret ? cam_cc_native_fault(ret, 0) : 0;
}

static int cam_cc_native_clock_init(void)
{
	const struct clk_ops *base;
	struct clk_ops *ops;
	unsigned int i, group;

	if (cam_cc_native_clocks_ready)
		return 0;
	for (i = 0; i < ARRAY_SIZE(cam_cc_sm7675_clocks); i++) {
		if (!cam_cc_sm7675_clocks[i])
			continue;
		base = cam_cc_sm7675_clocks[i]->hw.init->ops;
		for (group = 0; group < ARRAY_SIZE(cam_cc_native_base_ops); group++)
			if (base == cam_cc_native_base_ops[group])
				break;
		if (group == ARRAY_SIZE(cam_cc_native_base_ops) ||
		    base->pre_rate_change || base->post_rate_change)
			return -EINVAL;
		cam_cc_native_original[i] = base;
	}
	for (group = 0; group < ARRAY_SIZE(cam_cc_native_ops); group++) {
		base = cam_cc_native_base_ops[group];
		ops = &cam_cc_native_ops[group];
		*ops = *base;
		ops->prepare = cam_cc_native_clock_prepare;
		ops->unprepare = cam_cc_native_clock_unprepare;
		ops->pre_rate_change = cam_cc_native_clock_pre_rate;
		ops->post_rate_change = cam_cc_native_clock_post_rate;
		if (base->enable)
			ops->enable = cam_cc_native_clock_enable;
		if (base->disable)
			ops->disable = cam_cc_native_clock_disable;
		if (base->set_rate)
			ops->set_rate = cam_cc_native_clock_set_rate;
		if (base->set_parent)
			ops->set_parent = cam_cc_native_clock_set_parent;
		if (base->set_rate_and_parent)
			ops->set_rate_and_parent = cam_cc_native_clock_set_rate_parent;
	}
	for (i = 0; i < ARRAY_SIZE(cam_cc_sm7675_clocks); i++) {
		if (!cam_cc_sm7675_clocks[i])
			continue;
		for (group = 0; group < ARRAY_SIZE(cam_cc_native_base_ops); group++)
			if (cam_cc_native_original[i] == cam_cc_native_base_ops[group])
				break;
		cam_cc_native_inits[i] = *cam_cc_sm7675_clocks[i]->hw.init;
		cam_cc_native_inits[i].ops = &cam_cc_native_ops[group];
		cam_cc_sm7675_clocks[i]->hw.init = &cam_cc_native_inits[i];
	}
	cam_cc_native_clocks_ready = true;
	return 0;
}

static int cam_cc_native_hold_failure(struct device *dev, int error)
{
	/* shortcut: post-start failures need reboot; add retries after rollback qualification. */
	cam_cc_native_fault(error, 0);
	if (!cam_cc_native_probe_held) {
		pm_runtime_get_noresume(dev);
		cam_cc_native_probe_held = true;
	}
	/* The permanent backends also survive a later driver-core bind failure. */
	dev_err(dev, "camera controller disabled after error %d; resources retained\n", error);
	return 0;
}

static int cam_cc_native_reset_run(struct reset_controller_dev *rcdev, unsigned long id,
				   int (*operation)(struct reset_controller_dev *, unsigned long))
{
	struct device *dev = cam_cc_power.dev;
	int ret;

	if (!dev || rcdev->of_node != dev->of_node || id >= cam_cc_sm7675_desc.num_resets)
		return -EINVAL;
	if (cam_cc_power.fault)
		return cam_cc_power.fault;
	ret = pm_runtime_resume_and_get(dev);
	if (ret < 0) {
		if (cam_cc_power.fault)
			cam_cc_native_hold_failure(dev, ret);
		return ret;
	}
	ret = operation(rcdev, id);
	if (ret) {
		cam_cc_native_hold_failure(dev, ret);
		ret = cam_cc_power.fault;
	}
	pm_runtime_put(dev);
	return ret;
}

static int cam_cc_native_reset_assert(struct reset_controller_dev *rcdev, unsigned long id)
{
	return cam_cc_native_reset_run(rcdev, id, qcom_reset_ops.assert);
}

static int cam_cc_native_reset_deassert(struct reset_controller_dev *rcdev, unsigned long id)
{
	return cam_cc_native_reset_run(rcdev, id, qcom_reset_ops.deassert);
}

static int cam_cc_native_reset_pulse(struct reset_controller_dev *rcdev, unsigned long id)
{
	return cam_cc_native_reset_run(rcdev, id, qcom_reset_ops.reset);
}

static const struct reset_control_ops cam_cc_native_reset_ops = {
	.assert = cam_cc_native_reset_assert,
	.deassert = cam_cc_native_reset_deassert,
	.reset = cam_cc_native_reset_pulse,
};

static int cam_cc_native_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct qcom_cc_desc desc = cam_cc_sm7675_desc;
	struct resource *resource;
	struct regmap *map;
	void __iomem *base;
	int ret;

	if (!dev->driver || dev->driver->owner || !dev->driver->suppress_bind_attrs ||
	    !dev->of_node || of_node_check_flag(dev->of_node, OF_DYNAMIC) || dev->pm_domain ||
	    of_find_property(dev->of_node, "power-domains", NULL))
		return -EINVAL;
	if (cam_cc_power.dev)
		return -EBUSY;
	ret = cam_cc_native_clock_init();
	if (ret)
		return ret;
	ret = devm_add_action_or_reset(dev, cam_cc_native_detach, dev);
	if (ret)
		return ret;
	resource = platform_get_resource(pdev, IORESOURCE_MEM, 0);
	if (!resource)
		return -EINVAL;
	if (!request_mem_region(resource->start, resource_size(resource), dev_name(dev)))
		return -EBUSY;
	base = ioremap(resource->start, resource_size(resource));
	if (!base) {
		ret = -ENOMEM;
		goto release_region;
	}
	map = regmap_init(dev, NULL, &cam_cc_power, &cam_cc_power_regmap_config);
	if (IS_ERR(map)) {
		ret = PTR_ERR(map);
		goto unmap;
	}
	ret = pm_runtime_set_suspended(dev);
	if (ret)
		goto release_map;
	ret = cam_cc_power_init(dev, base, resource_size(resource));
	if (ret)
		goto release_map;
	pm_runtime_enable(dev);
	ret = pm_runtime_resume_and_get(dev);
	if (ret < 0)
		return cam_cc_native_hold_failure(dev, ret);
	cam_cc_native_probe_held = true;
	ret = clk_vdd_proxy_vote(dev, &cam_cc_sm7675_desc);
	if (ret) {
		cam_cc_native_fault(ret, CAM_CC_POWER_RAILS);
		return cam_cc_native_hold_failure(dev, ret);
	}
	cam_cc_native_proxy_active = true;
	/* PM is already enabled; the common helper must not enable it again. */
	desc.use_rpm = false;
	desc.skip_reset_provider = true;
	ret = qcom_cc_really_probe(dev, &desc, map);
	if (ret)
		return cam_cc_native_hold_failure(dev, ret);
	cam_cc_native_reset.rcdev = (struct reset_controller_dev) {
		.dev = dev,
		.of_node = dev->of_node,
		.ops = &cam_cc_native_reset_ops,
		.nr_resets = cam_cc_sm7675_desc.num_resets,
	};
	cam_cc_native_reset.regmap = map;
	cam_cc_native_reset.reset_map = cam_cc_sm7675_resets;
	ret = reset_controller_register(&cam_cc_native_reset.rcdev);
	if (ret)
		return cam_cc_native_hold_failure(dev, ret);
	cam_cc_native_reset_registered = true;
	cam_cc_native_published = true;
	cam_cc_native_probe_held = false;
	pm_runtime_put(dev);
	return 0;

release_map:
	regmap_exit(map);
unmap:
	iounmap(base);
release_region:
	release_mem_region(resource->start, resource_size(resource));
	return ret;
}

static void cam_cc_native_sync_state(struct device *dev)
{
	int ret;

	if (cam_cc_power.dev != dev || cam_cc_power.fault ||
	    !cam_cc_native_published || !cam_cc_native_proxy_active)
		return;
	ret = pm_runtime_resume_and_get(dev);
	if (ret < 0) {
		cam_cc_native_hold_failure(dev, ret);
		return;
	}
	cam_cc_native_probe_held = true;
	ret = clk_sync_state(dev);
	if (!ret) {
		ret = clk_vdd_proxy_unvote(dev, &cam_cc_sm7675_desc);
		if (ret) {
			cam_cc_native_fault(ret, CAM_CC_POWER_RAILS);
			cam_cc_native_hold_failure(dev, ret);
			return;
		}
		cam_cc_native_proxy_active = false;
	}
	cam_cc_native_probe_held = false;
	pm_runtime_put(dev);
}

static void cam_cc_native_shutdown(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;

	if (cam_cc_power.dev != dev)
		return;
	if (!cam_cc_native_probe_held) {
		pm_runtime_get_noresume(dev);
		cam_cc_native_probe_held = true;
	}
	pm_runtime_barrier(dev);
	cam_cc_native_fault(-ESHUTDOWN, 0);
}

static void cam_cc_native_detach(void *data)
{
	struct device *dev = data;

	if (cam_cc_power.dev != dev)
		return;
	cam_cc_native_shutdown(to_platform_device(dev));
	if (cam_cc_native_reset_registered) {
		reset_controller_unregister(&cam_cc_native_reset.rcdev);
		cam_cc_native_reset_registered = false;
	}
}

static void cam_cc_native_remove(struct platform_device *pdev)
{
	cam_cc_native_detach(&pdev->dev);
}

static const struct of_device_id cam_cc_native_match[] = {
	{ .compatible = "qcom,sm7675-camcc" },
	{ }
};

static struct platform_driver cam_cc_native_driver = {
	.probe = cam_cc_native_probe,
	.remove = cam_cc_native_remove,
	.shutdown = cam_cc_native_shutdown,
	.driver = {
		.name = "sm7675-camcc",
		.of_match_table = cam_cc_native_match,
		.pm = &cam_cc_power_pm_ops,
		.sync_state = cam_cc_native_sync_state,
		.suppress_bind_attrs = true,
		.probe_type = PROBE_FORCE_SYNCHRONOUS,
	},
};
builtin_platform_driver(cam_cc_native_driver);
MODULE_DESCRIPTION("Native SM7675 camera clock controller");
MODULE_LICENSE("GPL");
