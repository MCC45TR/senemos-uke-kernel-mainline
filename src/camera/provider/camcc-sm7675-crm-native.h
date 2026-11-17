/* SPDX-License-Identifier: GPL-2.0-only */
/* Complete permanent CRM admission; include after ROM and transport ownership. */
#ifndef UKE_CAMCC_SM7675_CRM_NATIVE_H
#define UKE_CAMCC_SM7675_CRM_NATIVE_H

#include "camcc-sm7675-crm-startup.h"
#include "camcc-sm7675-crm-floor.h"

static struct cam_cc_crm_lut cam_cc_crm_native_tables[8];
static struct cam_cc_crm_clock cam_cc_crm_native_clients[8];
static struct cam_cc_crm_floor cam_cc_crm_native_floor;
static struct {
	u32 offsets[14];
	u32 values[14];
	u32 count;
} cam_cc_crm_native_rom_words[8];
static bool cam_cc_crm_native_started;
static bool cam_cc_crm_native_ready;

static int cam_cc_crm_native_primary_read(void *context, u32 offset, u32 *value)
{
	int ret;

	if (context != &cam_cc_crm_guard || !value ||
	    !cam_cc_crm_guard.owned || !cam_cc_crm_guard.base ||
	    !cam_cc_crm_guard.checked || !cam_cc_crm_guard.firmware_enabled)
		return -EINVAL;
	if ((offset & 3) || offset >= CAM_CC_CRM_SIZE)
		return -ERANGE;
	ret = cam_cc_power_access(&cam_cc_power, 0);
	if (ret)
		return ret;
	*value = readl(cam_cc_crm_guard.base + offset);
	return 0;
}

static int cam_cc_crm_native_rom_read(void *context, u32 offset, u32 *value)
{
	u32 *client = context, count;
	int ret;

	if (!client || *client >= 8 || !value ||
	    !cam_cc_crmc_resource.owned || !cam_cc_crmc_resource.base ||
	    cam_cc_power.publication_started)
		return -EINVAL;
	if ((offset & 3) || offset >= CAM_CC_CRMC_SIZE)
		return -ERANGE;
	count = cam_cc_crm_native_rom_words[*client].count;
	if (count >= 14)
		return -EOVERFLOW;
	ret = cam_cc_power_access(&cam_cc_power, 0);
	if (ret)
		return ret;
	*value = readl(cam_cc_crmc_resource.base + offset);
	cam_cc_crm_native_rom_words[*client].offsets[count] = offset;
	cam_cc_crm_native_rom_words[*client].values[count] = *value;
	cam_cc_crm_native_rom_words[*client].count++;
	return 0;
}

static int cam_cc_crm_native_send(void *context, u32 kind, u32 resource, u32 value)
{
	if (context != &cam_cc_crm_owner_transport)
		return -EINVAL;
	return cam_cc_crm_transport_vote(context, kind, resource, value);
}

/* The controller PM core has restored rails and iface; IRQs are still quiesced. */
static int cam_cc_crm_native_resume(void *context)
{
	struct cam_cc_crm_transport *transport = &cam_cc_crm_owner_transport;
	u32 client, word, value, i;
	int ret;

	if (context != transport || !cam_cc_crm_native_ready ||
	    !transport->quiesced)
		return -EINVAL;
	ret = cam_cc_power_access(&cam_cc_power, 0);
	if (ret)
		return ret;
	/* Check only ROM words read during admission, before rearming the IRQ. */
	for (client = 0; client < 8; client++) {
		if (!cam_cc_crm_native_rom_words[client].count ||
		    cam_cc_crm_native_rom_words[client].count > 14 ||
		    (cam_cc_crm_native_rom_words[client].count & 1))
			return cam_cc_crm_owner_fail(-EUCLEAN);
		for (word = 0; word < cam_cc_crm_native_rom_words[client].count; word++) {
			if ((cam_cc_crm_native_rom_words[client].offsets[word] & 3) ||
			    cam_cc_crm_native_rom_words[client].offsets[word] >= CAM_CC_CRMC_SIZE)
				return cam_cc_crm_owner_fail(-ERANGE);
			value = readl(cam_cc_crmc_resource.base +
				cam_cc_crm_native_rom_words[client].offsets[word]);
			if (value != cam_cc_crm_native_rom_words[client].values[word])
				return cam_cc_crm_owner_fail(-EUCLEAN);
		}
	}
	for (i = 0; i < ARRAY_SIZE(cam_cc_crm_passive); i++) {
		ret = cam_cc_crm_passive_snapshot(i);
		if (ret)
			return cam_cc_crm_owner_fail(ret);
	}
	ret = cam_cc_crm_transport_resume(transport);
	return ret ? cam_cc_crm_owner_fail(ret) : 0;
}

static int cam_cc_crm_native_admit(void)
{
	struct cam_cc_crm_transport *transport = &cam_cc_crm_owner_transport;
	struct cam_cc_crm_caps caps;
	struct cam_cc_crm_startup initial, observed;
	struct cam_cc_clock *clock;
	u32 cfg1, cfg2, client, state, level, minimum[8] = {};
	unsigned long flags;
	int ret;

	if (!cam_cc_clocks_ready || cam_cc_power.publication_started ||
	    !cam_cc_crm_guard.checked || !cam_cc_crm_guard.firmware_enabled ||
	    !cam_cc_crm_guard.owned || !cam_cc_crmc_resource.owned ||
	    cam_cc_crmc_resource.dev != cam_cc_power.dev ||
	    !cam_cc_native.probe_pm_held ||
	    cam_cc_native.proxy_votes != CAM_CC_POWER_RAILS)
		return -EINVAL;
	if (cam_cc_crm_native_started || cam_cc_crm_native_ready ||
	    cam_cc_crm_passive_attached || cam_cc_crm_native_floor.ready)
		return -EBUSY;
	ret = cam_cc_power_access(&cam_cc_power, 0);
	if (ret)
		return ret;
	cam_cc_crm_native_started = true;
	cam_cc_native_probe_phase("crm-rom");
	for (client = 0; client < 8; client++) {
		ret = cam_cc_crm_rom_load(client, cam_cc_crm_native_rom_read,
					&client, &cam_cc_crm_native_tables[client]);
		if (ret)
			return ret;
		clock = cam_cc_clock_find(&cam_cc_crm_rcgs[client].rcg->clkr.hw);
		if (!clock)
			return -EINVAL;
		/* ROM frequencies must fit the original, characterized voltage map. */
		for (level = 0; level < cam_cc_crm_native_tables[client].count; level++) {
			ret = clk_find_vdd_level(&clock->clock->hw, &clock->clock->vdd_data,
				cam_cc_crm_native_tables[client].rates[level].hz);
			if (ret < 0)
				return ret;
		}
		cam_cc_crm_native_clients[client] = (struct cam_cc_crm_clock) {
			.table = &cam_cc_crm_native_tables[client],
			.send = cam_cc_crm_floor_vote,
			.context = &cam_cc_crm_native_floor,
			.kind = cam_cc_crm_rcgs[client].kind,
			.resource = cam_cc_crm_rcgs[client].resource,
			.desired = cam_cc_crm_native_tables[client].rates[0].hz,
		};
	}
	cam_cc_native_probe_phase("crm-topology");
	ret = cam_cc_crm_passive_preflight();
	if (!ret)
		ret = cam_cc_crm_ccf_preflight(cam_cc_crm_native_clients);
	if (ret)
		return ret;
	cam_cc_native_probe_phase("crm-startup");
	ret = cam_cc_crm_native_primary_read(&cam_cc_crm_guard, 4, &cfg1);
	if (!ret)
		ret = cam_cc_crm_native_primary_read(&cam_cc_crm_guard, 8, &cfg2);
	if (!ret)
		ret = cam_cc_crm_decode_caps(cfg1, cfg2, &caps);
	if (!ret)
		ret = cam_cc_crm_startup_read(&caps, cam_cc_crm_native_tables,
			CAM_CC_CRM_SIZE, cam_cc_crm_native_primary_read,
			&cam_cc_crm_guard, &initial);
	if (ret)
		return ret;
	for (client = 0; client < 8; client++) {
		for (state = 0; state < CAM_CC_CRM_STATES; state++) {
			cfg1 = initial.words[client][state] & (client == 7 ? 0x3fffU : 7U);
			if (cfg1 > minimum[client])
				minimum[client] = cfg1;
		}
	}
	ret = cam_cc_crm_floor_init(&cam_cc_crm_native_floor, minimum,
		cam_cc_crm_native_send, transport);
	if (ret)
		return ret;
	cam_cc_native_probe_phase("crm-transport");
	ret = cam_cc_crm_owner_transport_bind();
	if (ret)
		return ret;
	/* No vote is written while obtaining the permanent IRQ. Refuse observed
	 * changes rather than claiming that two reads transfer firmware ownership.
	 */
	mutex_lock(&transport->transaction);
	spin_lock_irqsave(&transport->lock, flags);
	ret = transport->fault;
	if (!ret && (!transport->ready ||
	    memcmp(&caps, &transport->caps, sizeof(caps))))
		ret = -EUCLEAN;
	if (!ret)
		ret = cam_cc_crm_startup_read(&caps, cam_cc_crm_native_tables,
			CAM_CC_CRM_SIZE, cam_cc_crm_native_primary_read,
			&cam_cc_crm_guard, &observed);
	if (!ret && memcmp(&initial, &observed, sizeof(initial)))
		ret = -EAGAIN;
	spin_unlock_irqrestore(&transport->lock, flags);
	mutex_unlock(&transport->transaction);
	if (ret)
		return cam_cc_crm_owner_fail(ret);
	cam_cc_native_probe_phase("crm-attach");
	ret = cam_cc_crm_managed_attach(cam_cc_crm_native_clients);
	if (ret)
		return cam_cc_crm_owner_fail(ret);
	ret = cam_cc_power_access(&cam_cc_power, 0);
	if (ret)
		return cam_cc_crm_owner_fail(ret);
	cam_cc_power.after_resume = cam_cc_crm_native_resume;
	WRITE_ONCE(cam_cc_crm_native_ready, true);
	return 0;
}

static int cam_cc_crm_native_sync(void)
{
	struct cam_cc_crm_transport *transport = &cam_cc_crm_owner_transport;
	int ret;

	if (!cam_cc_crm_guard.firmware_enabled)
		return 0;
	if (!cam_cc_crm_native_ready)
		return -EINVAL;
	ret = cam_cc_power_access(&cam_cc_power, 0);
	if (!ret)
		ret = cam_cc_crm_native_floor.fault;
	if (!ret)
		ret = READ_ONCE(transport->fault);
	if (!ret)
		ret = cam_cc_crm_floor_sync(&cam_cc_crm_native_floor);
	if (!ret)
		ret = READ_ONCE(transport->fault);
	if (!ret)
		ret = cam_cc_power_access(&cam_cc_power, 0);
	return ret ? cam_cc_crm_owner_fail(ret) : 0;
}

#endif /* UKE_CAMCC_SM7675_CRM_NATIVE_H */
