// SPDX-License-Identifier: GPL-2.0-only
// Uke APM private configuration DMA. No persistent data or userspace interface.
#include <linux/dma-mapping.h>
#include <linux/init.h>
#include <linux/iommu.h>
#include <linux/limits.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/of.h>
#include <linux/of_platform.h>
#include <linux/platform_device.h>
#include <linux/soc/qcom/uke-audio-config-memory.h>

#define UKE_CONFIG_BYTES 8192

/* Built in, nonremovable and without bind/unbind attributes. This supplier is
 * a static root DT node, independent of remoteproc, GPR and ASoC lifetimes.
 * Keep its stream-map reference and DMA ownership until system restart.
 */
static DEFINE_MUTEX(uke_config_lock);
static struct device *uke_config_device;
static struct uke_audio_config_memory uke_config_lease;
static u32 uke_config_next_token = 1;
static bool uke_config_busy;
static bool uke_config_uncertain;

/* Probe readiness must not depend on the APM frontend, which is populated
 * only after the APM probe succeeds. Domain equality is checked on acquire.
 */
int uke_audio_config_ready(void)
{
	int ret;

	mutex_lock(&uke_config_lock);
	ret = uke_config_device ? 0 : -EPROBE_DEFER;
	mutex_unlock(&uke_config_lock);
	return ret;
}
EXPORT_SYMBOL_GPL(uke_audio_config_ready);

static bool uke_config_iommus(struct device_node *node,
			      struct device_node **smmu)
{
	struct of_phandle_args args;
	struct device_node *first = NULL;
	const u32 sid[] = { 0x1001, 0x1061 };
	const u32 mask[] = { 0x80, 0 };
	int i, ret;

	if (of_count_phandle_with_args(node, "iommus", "#iommu-cells") != 2)
		return false;
	for (i = 0; i < 2; i++) {
		ret = of_parse_phandle_with_args(node, "iommus", "#iommu-cells", i, &args);
		if (ret)
			goto refuse;
		if (args.args_count != 2 || args.args[0] != sid[i] ||
		    args.args[1] != mask[i] || (first && first != args.np)) {
			of_node_put(args.np);
			goto refuse;
		}
		if (!first)
			first = of_node_get(args.np);
		of_node_put(args.np);
	}
	*smmu = first;
	return true;
refuse:
	of_node_put(first);
	return false;
}

static bool uke_config_same_domain(struct device *apm)
{
	struct device_node *node, *supplier_smmu = NULL, *frontend_smmu = NULL;
	struct platform_device *frontend = NULL;
	struct iommu_group *a = NULL, *b = NULL;
	struct iommu_domain *domain;
	bool valid = false;

	if (!apm || !of_machine_is_compatible("xiaomi,uke") ||
	    !of_device_is_compatible(apm->of_node, "qcom,q6apm") ||
	    !of_property_read_bool(apm->of_node, "xiaomi,fs19xx-protected"))
		return false;
	node = of_get_child_by_name(apm->of_node, "dais");
	if (!node)
		return false;
	if (!of_device_is_compatible(node, "qcom,q6apm-dais") ||
	    !of_device_is_available(node) ||
	    !uke_config_iommus(node, &frontend_smmu) ||
	    !uke_config_iommus(uke_config_device->of_node, &supplier_smmu) ||
	    frontend_smmu != supplier_smmu)
		goto out;
	frontend = of_find_device_by_node(node);
	if (!frontend)
		goto out;
	a = iommu_group_get(uke_config_device);
	b = iommu_group_get(&frontend->dev);
	domain = iommu_get_domain_for_dev(uke_config_device);
	valid = a && b && a == b && domain && iommu_is_dma_domain(domain) &&
		domain == iommu_get_domain_for_dev(&frontend->dev);
out:
	iommu_group_put(a);
	iommu_group_put(b);
	if (frontend)
		put_device(&frontend->dev);
	of_node_put(node);
	of_node_put(supplier_smmu);
	of_node_put(frontend_smmu);
	return valid;
}

int uke_audio_config_acquire(struct device *apm,
			     struct uke_audio_config_memory *memory)
{
	struct uke_audio_config_memory lease = { .bytes = UKE_CONFIG_BYTES };
	int ret = 0;

	if (!memory)
		return -EINVAL;
	mutex_lock(&uke_config_lock);
	if (!uke_config_device) {
		ret = -ENODEV;
		goto out;
	}
	if (uke_config_busy || uke_config_uncertain) {
		ret = -EBUSY;
		goto out;
	}
	if (!uke_config_same_domain(apm)) {
		ret = -EXDEV;
		goto out;
	}
	/* Three nonrecycled tokens per lease, also across APM module reloads. */
	if (uke_config_next_token > U32_MAX - 3) {
		ret = -EOVERFLOW;
		goto out;
	}
	lease.area = dma_alloc_coherent(uke_config_device, lease.bytes,
					&lease.dma, GFP_KERNEL);
	if (!lease.area) {
		ret = -ENOMEM;
		goto out;
	}
	if (!lease.dma || upper_32_bits(lease.dma) || (lease.dma & 4095) ||
	    lease.dma > U32_MAX - (lease.bytes - 1)) {
		memzero_explicit(lease.area, lease.bytes);
		dma_free_coherent(uke_config_device, lease.bytes, lease.area, lease.dma);
		ret = -ERANGE;
		goto out;
	}
	/* Exact fitted first SID0x1001 & upstream SID_MASK_DEFAULT0xf. */
	lease.dsp_address = (u64)lease.dma | (1ULL << 32);
	lease.first_token = uke_config_next_token;
	uke_config_next_token += 3;
	uke_config_lease = lease;
	uke_config_busy = true;
	*memory = lease;
out:
	mutex_unlock(&uke_config_lock);
	return ret;
}
EXPORT_SYMBOL_GPL(uke_audio_config_acquire);

void uke_audio_config_release(struct uke_audio_config_memory *memory, bool uncertain)
{
	mutex_lock(&uke_config_lock);
	if (!uke_config_busy)
		goto out;
	/* A mismatched caller must never release the real remote-owned pages. */
	if (!memory || memory->area != uke_config_lease.area ||
	    memory->dma != uke_config_lease.dma ||
	    memory->bytes != uke_config_lease.bytes ||
	    memory->dsp_address != uke_config_lease.dsp_address ||
	    memory->first_token != uke_config_lease.first_token)
		uncertain = true;
	memzero_explicit(uke_config_lease.area, uke_config_lease.bytes);
	dma_wmb();
	if (uncertain || uke_config_uncertain) {
		uke_config_uncertain = true;
		goto out;
	}
	dma_free_coherent(uke_config_device, uke_config_lease.bytes,
			  uke_config_lease.area, uke_config_lease.dma);
	memset(&uke_config_lease, 0, sizeof(uke_config_lease));
	uke_config_busy = false;
	memset(memory, 0, sizeof(*memory));
out:
	mutex_unlock(&uke_config_lock);
}
EXPORT_SYMBOL_GPL(uke_audio_config_release);

static int uke_config_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct device_node *smmu = NULL;
	struct iommu_domain *domain;
	int ret;

	if (!of_machine_is_compatible("xiaomi,uke") || dev->of_node->parent != of_root ||
	    !uke_config_iommus(dev->of_node, &smmu))
		return -ENODEV;
	of_node_put(smmu);
	domain = iommu_get_domain_for_dev(dev);
	if (!domain || !iommu_is_dma_domain(domain))
		return -EPROBE_DEFER;
	ret = dma_set_mask_and_coherent(dev, DMA_BIT_MASK(32));
	if (ret)
		return ret;
	mutex_lock(&uke_config_lock);
	if (uke_config_device)
		ret = -EBUSY;
	else
		uke_config_device = dev;
	mutex_unlock(&uke_config_lock);
	return ret;
}

static const struct of_device_id uke_config_match[] = {
	{ .compatible = "xiaomi,uke-audio-config-memory" },
	{ }
};
static struct platform_driver uke_config_driver = {
	.probe = uke_config_probe,
	.driver = {
		.name = "uke-audio-config-memory",
		.of_match_table = uke_config_match,
		.suppress_bind_attrs = true,
	},
};
builtin_platform_driver(uke_config_driver);
