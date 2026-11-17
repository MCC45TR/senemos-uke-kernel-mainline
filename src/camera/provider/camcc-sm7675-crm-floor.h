/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Preserve inherited AP0 minimum votes until provider synchronization. The
 * permanent caller first validates all ROM/startup words, holds the maximum
 * admitted voltage proxy and probe power, then binds the checked transport.
 * This adapter never addresses a HW voter or firmware-owned PLL directly.
 * Include after camcc-sm7675-crm-core.h. All callbacks are sleepable.
 */
#ifndef UKE_CAMCC_SM7675_CRM_FLOOR_H
#define UKE_CAMCC_SM7675_CRM_FLOOR_H

#include <linux/compiler.h>
#include <linux/mutex.h>

struct cam_cc_crm_floor {
	struct mutex lock;
	int (*send)(void *context, u32 kind, u32 resource, u32 value);
	void *context;
	u32 minimum[8];
	u32 requested[8];
	int fault;
	bool ready;
	bool released;
};

static inline int cam_cc_crm_floor_index(u32 kind, u32 resource)
{
	if (!cam_cc_crm_owned(kind, resource))
		return -EINVAL;
	if (kind == CAM_CC_CRM_BW)
		return 7;
	return resource < 5 ? resource : resource - 1;
}

/* Initialization itself performs no writes and does not adopt transport state. */
static inline int cam_cc_crm_floor_init(struct cam_cc_crm_floor *floor,
		const u32 minimum[8],
		int (*send)(void *context, u32 kind, u32 resource, u32 value),
		void *context)
{
	u32 i;

	if (!floor || !minimum || !send || !context)
		return -EINVAL;
	if (floor->send || floor->context || floor->ready || floor->released ||
	    floor->fault)
		return -EBUSY;
	for (i = 0; i < 8; i++) {
		if (floor->minimum[i] || floor->requested[i])
			return -EBUSY;
		if (minimum[i] > (i == 7 ? 0x3fffU : 7U))
			return -ERANGE;
	}
	mutex_init(&floor->lock);
	for (i = 0; i < 8; i++)
		floor->minimum[i] = minimum[i];
	floor->send = send;
	floor->context = context;
	WRITE_ONCE(floor->ready, true);
	return 0;
}

static inline int cam_cc_crm_floor_vote(void *context, u32 kind,
				       u32 resource, u32 value)
{
	struct cam_cc_crm_floor *floor = context;
	u32 effective;
	int index, ret;

	if (!floor || !READ_ONCE(floor->ready))
		return -ENODEV;
	index = cam_cc_crm_floor_index(kind, resource);
	if (index < 0)
		return index;
	if (value > (kind == CAM_CC_CRM_BW ? 0x3fffU : 7U))
		return -ERANGE;
	/* Serialize a consumer vote with the whole synchronization withdrawal.
	 * No CCF fields are read here: the successful caller supplies its current
	 * software request, including PRE/ABORT and prepare/unprepare changes.
	 */
	mutex_lock(&floor->lock);
	if (floor->fault) {
		ret = floor->fault;
		goto out;
	}
	effective = !floor->released && value < floor->minimum[index] ?
		floor->minimum[index] : value;
	ret = floor->send(floor->context, kind, resource, effective);
	if (ret)
		floor->fault = ret < 0 ? ret : -EIO;
	else
		floor->requested[index] = value;
	ret = floor->fault;
out:
	mutex_unlock(&floor->lock);
	return ret;
}

/* Call after successful CCF boot-reference release, before genpd/proxy put.
 * A partial failure is permanent; its caller retains power and maximum proxy.
 */
static inline int cam_cc_crm_floor_sync(struct cam_cc_crm_floor *floor)
{
	static const u32 resources[8] = { 0, 1, 2, 3, 4, 6, 7, 0 };
	u32 i, kind;
	int ret = 0;

	if (!floor || !READ_ONCE(floor->ready))
		return -ENODEV;
	mutex_lock(&floor->lock);
	if (floor->fault) {
		ret = floor->fault;
		goto out;
	}
	if (floor->released)
		goto out;
	for (i = 0; i < 8; i++) {
		/* Zero floors or a higher Linux vote need no extra IRQ transaction. */
		if (floor->minimum[i] <= floor->requested[i])
			continue;
		kind = i == 7 ? CAM_CC_CRM_BW : CAM_CC_CRM_PERF;
		ret = floor->send(floor->context, kind, resources[i], floor->requested[i]);
		if (ret) {
			floor->fault = ret < 0 ? ret : -EIO;
			ret = floor->fault;
			goto out;
		}
	}
	floor->released = true;
out:
	mutex_unlock(&floor->lock);
	return ret;
}

#endif /* UKE_CAMCC_SM7675_CRM_FLOOR_H */
