/* SPDX-License-Identifier: GPL-2.0-only */
/* Permanent AP0 IRQ/transport binding; activation still needs all38/ROM/votes. */
#ifndef UKE_CAMCC_SM7675_CRM_OWNER_H
#define UKE_CAMCC_SM7675_CRM_OWNER_H

static struct cam_cc_crm_transport cam_cc_crm_owner_transport;

static int cam_cc_crm_owner_fail(int error)
{
	struct cam_cc_crm_transport *transport = &cam_cc_crm_owner_transport;
	unsigned long flags;

	/* init established the lock before any capability/IRQ operation. */
	if (!transport->base)
		return error;
	spin_lock_irqsave(&transport->lock, flags);
	cam_cc_crm_transport_fail(transport, error);
	spin_unlock_irqrestore(&transport->lock, flags);
	/* No failed owner may reach resource_put or power-off with a live IRQ. */
	if (!cam_cc_power.transport_context)
		cam_cc_power.transport_context = transport;
	return cam_cc_power_fail(error, 0, 0);
}

/* Called once by a future fully admitted CRM path, before CCF publication.
 * Never call this to restart the already quarantined direct-programming probe.
 * No ROM/CCF attachment or inherited AP0 withdrawal is performed here.
 */
static int __maybe_unused cam_cc_crm_owner_transport_bind(void)
{
	struct cam_cc_crm_transport *transport = &cam_cc_crm_owner_transport;
	int ret;

	if (!cam_cc_clocks_ready || cam_cc_power.publication_started ||
	    !cam_cc_crm_guard.owned || !cam_cc_crm_guard.base ||
	    !cam_cc_crm_guard.checked || !cam_cc_crm_guard.firmware_enabled ||
	    !cam_cc_crmc_resource.owned || !cam_cc_crmc_resource.base ||
	    cam_cc_crmc_resource.base == cam_cc_crm_guard.base ||
	    cam_cc_crmc_resource.irq <= 0 ||
	    cam_cc_crmc_resource.dev != cam_cc_power.dev || !cam_cc_power.dev)
		return -EINVAL;
	if (cam_cc_power.transport_context || cam_cc_power.before_suspend ||
	    cam_cc_power.after_resume || transport->base || transport->irq_owned ||
	    transport->ready || transport->released || transport->fault)
		return -EBUSY;
	ret = cam_cc_power_access(&cam_cc_power, 0);
	if (ret)
		return ret;
	ret = cam_cc_crm_transport_init(transport, cam_cc_power.dev,
			cam_cc_crm_guard.base, cam_cc_crmc_resource.irq,
			cam_cc_crm_pm_access, &cam_cc_power);
	if (ret)
		return cam_cc_crm_owner_fail(ret);
	ret = cam_cc_crm_pm_bind(transport);
	if (ret)
		return cam_cc_crm_owner_fail(ret);
	return 0;
}

#endif /* UKE_CAMCC_SM7675_CRM_OWNER_H */
