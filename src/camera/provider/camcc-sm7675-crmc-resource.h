/* SPDX-License-Identifier: GPL-2.0-only */
/* Permanent, passive CRMC ownership. No register access or IRQ activation. */
#ifndef UKE_CAMCC_SM7675_CRMC_RESOURCE_H
#define UKE_CAMCC_SM7675_CRMC_RESOURCE_H

#include <linux/io.h>
#include <linux/ioport.h>
#include <linux/platform_device.h>

/* Exact Uke OEM DT94c84aeb, qcom/cliffs.dtsi, cam_crm crm_c resource. */
#define CAM_CC_CRMC_START 0x0adda000
#define CAM_CC_CRMC_SIZE 0x2000

static struct {
	struct device *dev;
	void __iomem *base;
	int irq;
	bool owned;
} cam_cc_crmc_resource;

static int cam_cc_crmc_resource_map(struct platform_device *pdev)
{
	struct resource *resource;
	void __iomem *base;
	int irq;

	/* The original permanent owner holds the device and all later PM state. */
	if (!cam_cc_power.dev || cam_cc_power.dev != &pdev->dev ||
	    !cam_cc_crm_guard.owned || !cam_cc_crm_guard.base)
		return -ENODEV;
	if (cam_cc_crmc_resource.dev || cam_cc_crmc_resource.owned ||
	    cam_cc_crmc_resource.base)
		return -EBUSY;
	resource = platform_get_resource_byname(pdev, IORESOURCE_MEM, "crmc");
	if (!resource || resource->start != CAM_CC_CRMC_START ||
	    resource_size(resource) != CAM_CC_CRMC_SIZE)
		return -EINVAL;
	irq = platform_get_irq_byname(pdev, "crm");
	if (irq <= 0)
		return irq ?: -ENXIO;
	if (!request_mem_region(resource->start, CAM_CC_CRMC_SIZE, dev_name(&pdev->dev)))
		return -EBUSY;
	base = ioremap(resource->start, CAM_CC_CRMC_SIZE);
	if (!base) {
		release_mem_region(resource->start, CAM_CC_CRMC_SIZE);
		return -ENOMEM;
	}
	cam_cc_crmc_resource.dev = &pdev->dev;
	cam_cc_crmc_resource.base = base;
	cam_cc_crmc_resource.irq = irq;
	cam_cc_crmc_resource.owned = true;
	return 0;
}

/* Registration calls this only on its unpublished, pre-transport error path.
 * Any fault/PM/publication evidence retains the mapping with the old owner.
 * Transport attachment must extend this contract before it may own this IRQ.
 */
static void cam_cc_crmc_resource_put(void)
{
	if (!cam_cc_crmc_resource.owned)
		return;
	if (cam_cc_power.dev != cam_cc_crmc_resource.dev ||
	    cam_cc_power.transport_context || cam_cc_owner_busy())
		return;
	iounmap(cam_cc_crmc_resource.base);
	release_mem_region(CAM_CC_CRMC_START, CAM_CC_CRMC_SIZE);
	memset(&cam_cc_crmc_resource, 0, sizeof(cam_cc_crmc_resource));
}

#endif /* UKE_CAMCC_SM7675_CRMC_RESOURCE_H */
