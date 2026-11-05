/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Cliffs AP SWDRV0 transport, derived from the register/IRQ protocol in
 * Xiaomi Uke drivers/soc/qcom/crm.c at5712080a4b0c0b1a879e6d145c601c649ddaddfd.
 * Copyright (c) 2022-2023, Qualcomm Innovation Center, Inc. All rights reserved.
 *
 * The permanent controller owner must retain this object, mapping, device and
 * powered access while its IRQ is owned, including probe failure/quarantine.
 * This header is not yet called by the CAMCC provider. IRQ quiesce/release and
 * managed CCF/runtime-PM integration are prerequisites for provider activation.
 */
#ifndef UKE_CAMCC_SM7675_CRM_TRANSPORT_H
#define UKE_CAMCC_SM7675_CRM_TRANSPORT_H

#include <linux/completion.h>
#include <linux/compiler.h>
#include <linux/device.h>
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/jiffies.h>
#include <linux/mutex.h>
#include <linux/spinlock.h>
#include "camcc-sm7675-crm-core.h"

#define CAM_CC_CRM_TIMEOUT_MS 5000

struct cam_cc_crm_transport {
	void __iomem *base;
	struct device *dev;
	struct cam_cc_crm_caps caps;
	struct mutex transaction;
	spinlock_t lock;
	struct completion completion;
	struct cam_cc_crm_vote_state votes[2][8];
	int (*access)(void *context);
	void *power_context;
	u32 version;
	u32 pending_kind;
	u32 pending_resource;
	int irq;
	int fault;
	bool irq_owned;
	bool irq_masked;
	bool pending;
	bool ready;
};

struct cam_cc_crm_transaction {
	struct cam_cc_crm_transport *transport;
	u32 kind;
	u32 resource;
};

/* Called with lock held; a late acknowledgement can never clear this fault. */
static inline int cam_cc_crm_transport_fail(struct cam_cc_crm_transport *t, int error)
{
	if (!t->fault)
		t->fault = error < 0 ? error : -EIO;
	t->ready = false;
	if (t->irq_owned && !t->irq_masked) {
		disable_irq_nosync(t->irq);
		t->irq_masked = true;
	}
	if (t->pending) {
		t->pending = false;
		complete(&t->completion);
	}
	return t->fault;
}

static inline irqreturn_t cam_cc_crm_transport_irq(int irq, void *context)
{
	struct cam_cc_crm_transport *t = context;
	unsigned long flags;
	u32 kind, resource, offset, clear, status;
	bool handled = false;
	int ret;

	if (!t || !READ_ONCE(t->irq_owned) || irq != t->irq)
		return IRQ_NONE;
	spin_lock_irqsave(&t->lock, flags);
	if (t->fault) {
		handled = true;
		goto out;
	}
	/* The owner's access check is non-sleeping and performs no register I/O. */
	ret = t->access(t->power_context);
	if (ret) {
		cam_cc_crm_transport_fail(t, ret);
		handled = true;
		goto out;
	}
	for (kind = 0; kind < 2; kind++) {
		for (resource = 0; resource < 8; resource++) {
			if (!cam_cc_crm_owned(kind, resource))
				continue;
			ret = cam_cc_crm_offset(&t->caps, kind, resource,
				CAM_CC_CRM_IRQ_STATUS, CAM_CC_CRM_ACTIVE, 0x2000, &offset);
			if (!ret)
				ret = cam_cc_crm_offset(&t->caps, kind, resource,
					CAM_CC_CRM_IRQ_CLEAR, CAM_CC_CRM_ACTIVE, 0x2000, &clear);
			if (ret) {
				cam_cc_crm_transport_fail(t, ret);
				handled = true;
				goto out;
			}
			status = readl(t->base + offset);
			if (!status)
				continue;
			handled = true;
			/* Never acknowledge undocumented status bits or unowned voters. */
			if (status != 1) {
				cam_cc_crm_transport_fail(t, -EUCLEAN);
				goto out;
			}
			writel(1, t->base + clear);
			if (!t->pending || t->pending_kind != kind ||
			    t->pending_resource != resource) {
				cam_cc_crm_transport_fail(t, -EUCLEAN);
				goto out;
			}
			t->pending = false;
			complete(&t->completion);
		}
	}
out:
	spin_unlock_irqrestore(&t->lock, flags);
	return handled ? IRQ_HANDLED : IRQ_NONE;
}

/* The core validates all three packets before calling this transport. */
static inline int cam_cc_crm_transport_send(void *context,
					  const struct cam_cc_crm_packet *packet)
{
	struct cam_cc_crm_transaction *transaction = context;
	struct cam_cc_crm_transport *t = transaction->transport;
	unsigned long flags, completed;
	u32 offset, status;
	int ret;

	spin_lock_irqsave(&t->lock, flags);
	if (t->fault) {
		ret = t->fault;
		goto unlock;
	}
	ret = t->access(t->power_context);
	if (ret) {
		ret = cam_cc_crm_transport_fail(t, ret);
		goto unlock;
	}
	if (!t->ready) {
		ret = -ENODEV;
		goto unlock;
	}
	if (!packet->wait_for_ack) {
		writel(packet->data, t->base + packet->offset);
		ret = 0;
		goto unlock;
	}
	ret = cam_cc_crm_offset(&t->caps, transaction->kind, transaction->resource,
		CAM_CC_CRM_IRQ_STATUS, CAM_CC_CRM_ACTIVE, 0x2000, &offset);
	if (ret) {
		ret = cam_cc_crm_transport_fail(t, ret);
		goto unlock;
	}
	status = readl(t->base + offset);
	/* A previous/stale completion must not be attributed to the new command. */
	if (t->pending || status) {
		ret = cam_cc_crm_transport_fail(t, -EUCLEAN);
		goto unlock;
	}
	reinit_completion(&t->completion);
	t->pending_kind = transaction->kind;
	t->pending_resource = transaction->resource;
	t->pending = true;
	writel(packet->data, t->base + packet->offset);
	spin_unlock_irqrestore(&t->lock, flags);

	completed = wait_for_completion_timeout(&t->completion,
					      msecs_to_jiffies(CAM_CC_CRM_TIMEOUT_MS));
	spin_lock_irqsave(&t->lock, flags);
	if (!completed)
		ret = cam_cc_crm_transport_fail(t, -ETIMEDOUT);
	else if (t->fault)
		ret = t->fault;
	else if (t->pending)
		ret = cam_cc_crm_transport_fail(t, -EUCLEAN);
	else
		ret = 0;
unlock:
	spin_unlock_irqrestore(&t->lock, flags);
	return ret;
}

static inline int cam_cc_crm_transport_vote(struct cam_cc_crm_transport *t,
					  u32 kind, u32 resource, u32 value)
{
	struct cam_cc_crm_transaction transaction;
	unsigned long flags;
	int ret;

	if (!t || !cam_cc_crm_owned(kind, resource))
		return -EINVAL;
	if (!t->base || !t->access)
		return -ENODEV;
	/* CCF transactions do not queue behind an ambiguous or wedged command. */
	if (!mutex_trylock(&t->transaction))
		return -EBUSY;
	spin_lock_irqsave(&t->lock, flags);
	ret = t->fault ? t->fault : t->ready ? 0 : -ENODEV;
	spin_unlock_irqrestore(&t->lock, flags);
	if (ret)
		goto unlock;
	transaction.transport = t;
	transaction.kind = kind;
	transaction.resource = resource;
	ret = cam_cc_crm_send_vote(&t->caps, kind, resource, value, 0x2000,
		&t->votes[kind][resource], cam_cc_crm_transport_send, &transaction);
unlock:
	mutex_unlock(&t->transaction);
	return ret;
}

static inline int cam_cc_crm_transport_init(struct cam_cc_crm_transport *t,
		struct device *dev, void __iomem *base, int irq,
		int (*access)(void *context), void *power_context)
{
	unsigned long flags;
	u32 cfg1, cfg2, kind, resource, offset, status;
	int ret;

	if (!t || !dev || !base || irq < 0 || !access)
		return -EINVAL;
	if (t->base || t->irq_owned || t->ready)
		return -EBUSY;
	ret = access(power_context);
	if (ret)
		return ret < 0 ? ret : -EIO;
	t->base = base;
	t->dev = dev;
	t->irq = irq;
	t->access = access;
	t->power_context = power_context;
	mutex_init(&t->transaction);
	spin_lock_init(&t->lock);
	init_completion(&t->completion);
	t->version = readl(base);
	cfg1 = readl(base + 4);
	cfg2 = readl(base + 8);
	if (!readl(base + 0xc))
		return -EOPNOTSUPP;
	ret = cam_cc_crm_decode_caps(cfg1, cfg2, &t->caps);
	if (ret)
		return ret;
	ret = request_irq(irq, cam_cc_crm_transport_irq, IRQF_TRIGGER_RISING,
			  dev_name(dev), t);
	if (ret)
		return ret;
	spin_lock_irqsave(&t->lock, flags);
	t->irq_owned = true;
	ret = t->access(t->power_context);
	if (ret)
		goto fault;
	/* Preflight every owned status and enable register before the first write. */
	for (kind = 0; kind < 2; kind++) {
		for (resource = 0; resource < 8; resource++) {
			if (!cam_cc_crm_owned(kind, resource))
				continue;
			ret = cam_cc_crm_offset(&t->caps, kind, resource,
				CAM_CC_CRM_IRQ_STATUS, CAM_CC_CRM_ACTIVE, 0x2000, &offset);
			if (ret)
				goto fault;
			if (readl(base + offset)) {
				ret = -EUCLEAN;
				goto fault;
			}
			ret = cam_cc_crm_offset(&t->caps, kind, resource,
				CAM_CC_CRM_IRQ_ENABLE, CAM_CC_CRM_ACTIVE, 0x2000, &offset);
			if (ret)
				goto fault;
			if (readl(base + offset) & ~1U) {
				ret = -EOPNOTSUPP;
				goto fault;
			}
		}
	}
	for (kind = 0; kind < 2; kind++) {
		for (resource = 0; resource < 8; resource++) {
			if (!cam_cc_crm_owned(kind, resource))
				continue;
			ret = cam_cc_crm_offset(&t->caps, kind, resource,
				CAM_CC_CRM_IRQ_ENABLE, CAM_CC_CRM_ACTIVE, 0x2000, &offset);
			if (ret)
				goto fault;
			writel(1, base + offset);
			status = readl(base + offset);
			if (status != 1) {
				ret = -EIO;
				goto fault;
			}
		}
	}
	t->ready = true;
	spin_unlock_irqrestore(&t->lock, flags);
	return 0;
fault:
	ret = cam_cc_crm_transport_fail(t, ret);
	spin_unlock_irqrestore(&t->lock, flags);
	return ret;
}

#endif /* UKE_CAMCC_SM7675_CRM_TRANSPORT_H */
