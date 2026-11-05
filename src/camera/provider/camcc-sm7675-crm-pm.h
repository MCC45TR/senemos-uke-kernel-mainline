/* SPDX-License-Identifier: GPL-2.0-only */
/* Install only after permanent owned IRQ/transport admission, before publication. */
#ifndef UKE_CAMCC_SM7675_CRM_PM_H
#define UKE_CAMCC_SM7675_CRM_PM_H

#include "camcc-sm7675-crm-transport.h"

static int __maybe_unused cam_cc_crm_pm_access(void *context)
{
	return cam_cc_power_access(context, 0);
}

static int cam_cc_crm_pm_idle(void *context)
{
	return cam_cc_crm_transport_idle(context, false);
}

static int cam_cc_crm_pm_resume(void *context)
{
	return cam_cc_crm_transport_resume(context);
}

static int __maybe_unused cam_cc_crm_pm_bind(struct cam_cc_crm_transport *transport)
{
	if (!transport || !READ_ONCE(transport->ready) || !transport->irq_owned ||
	    transport->quiesced || transport->fault ||
	    transport->dev != cam_cc_power.dev ||
	    transport->power_context != &cam_cc_power ||
	    transport->access != cam_cc_crm_pm_access ||
	    cam_cc_power.publication_started || cam_cc_power.before_suspend ||
	    cam_cc_power.after_resume || cam_cc_power.transport_context)
		return -EINVAL;
	if (cam_cc_power_access(&cam_cc_power, 0))
		return -EHOSTDOWN;
	cam_cc_power.transport_context = transport;
	cam_cc_power.before_suspend = cam_cc_crm_pm_idle;
	cam_cc_power.after_resume = cam_cc_crm_pm_resume;
	return 0;
}

#endif /* UKE_CAMCC_SM7675_CRM_PM_H */
