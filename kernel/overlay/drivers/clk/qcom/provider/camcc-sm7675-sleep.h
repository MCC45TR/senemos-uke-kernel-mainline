/* SPDX-License-Identifier: GPL-2.0-only */
/* Unpublished firmware-CRM quarantine keeps its existing votes during s2idle. */
#ifndef UKE_CAMCC_SM7675_SLEEP_H
#define UKE_CAMCC_SM7675_SLEEP_H
#include <linux/suspend.h>

static bool cam_cc_system_sleep_held;

/* One probe hold plus the PM core prepare reference; neither is released. */
static bool cam_cc_quarantine_sleep_hold(struct device *dev)
{
	size_t i;

	if (dev != cam_cc_power.dev || dev_get_drvdata(dev) != &cam_cc_power ||
	    !dev->driver || dev->driver->pm != &cam_cc_native_pm_ops ||
	    dev->pm_domain || !cam_cc_native.probe.complete ||
	    cam_cc_native.probe.error != -EOPNOTSUPP ||
	    !cam_cc_native.probe.phase || strcmp(cam_cc_native.probe.phase, "crm-admission") ||
	    cam_cc_power.fault != -EIO || cam_cc_power.primary_error != -EOPNOTSUPP ||
	    cam_cc_power.rollback_error || cam_cc_power.uncertain_rails ||
	    !cam_cc_power.iface_on || cam_cc_power.votes != CAM_CC_POWER_RAILS ||
	    cam_cc_native.proxy_votes != CAM_CC_POWER_RAILS ||
	    !cam_cc_native.pm_enabled || !cam_cc_native.probe_pm_held ||
	    cam_cc_native.ready || cam_cc_power.publication_started ||
	    atomic_read(&dev->power.usage_count) != 2 || atomic_read(&dev->power.child_count))
		return false;
	for (i = 0; i < ARRAY_SIZE(cam_cc_native.registered); i++)
		if (cam_cc_native.registered[i] || cam_cc_native.boot_rcgs[i])
			return false;
	for (i = 0; i < ARRAY_SIZE(cam_cc_sm7675_gdscs); i++)
		if (cam_cc_sm7675_gdscs[i]->controller_pm_held)
			return false;
	return true;
}

static int __maybe_unused cam_cc_system_suspend(struct device *dev)
{
	if (cam_cc_system_sleep_held)
		return -EBUSY;
	if (pm_suspend_target_state == PM_SUSPEND_TO_IDLE && cam_cc_quarantine_sleep_hold(dev)) {
		/* No MMIO, power transition, publication, or false runtime-state change. */
		cam_cc_system_sleep_held = true;
		dev_info(dev, "retaining unpublished CRM quarantine for s2idle\n");
		return 0;
	}
	return pm_runtime_force_suspend(dev);
}

static int __maybe_unused cam_cc_system_resume(struct device *dev)
{
	if (cam_cc_system_sleep_held) {
		if (!cam_cc_quarantine_sleep_hold(dev))
			return -EIO;
		cam_cc_system_sleep_held = false;
		return 0;
	}
	return pm_runtime_force_resume(dev);
}

static const struct dev_pm_ops cam_cc_native_pm_ops = {
	RUNTIME_PM_OPS(cam_cc_power_suspend, cam_cc_power_resume, NULL)
	SYSTEM_SLEEP_PM_OPS(cam_cc_system_suspend, cam_cc_system_resume)
};
#endif
