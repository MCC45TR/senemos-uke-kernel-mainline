/* SPDX-License-Identifier: GPL-2.0-only */
/* Included by arm-smmu-qcom.c in the isolated SM7675 display tree. */
#include <linux/qcom-uke-display.h>
#include <linux/pm_runtime.h>

int qcom_uke_display_release(struct device *supplier, struct device *display)
{
	struct arm_smmu_device *smmu = dev_get_drvdata(supplier);
	int i, ret;

	if (!of_device_is_compatible(supplier->of_node, "qcom,sm7675-boot-smmu") ||
	    !of_device_is_compatible(display->of_node, "qcom,sm7675-mdss"))
		return -EINVAL;
	if (!smmu)
		return -EPROBE_DEFER;
	ret = pm_runtime_resume_and_get(supplier);
	if (ret < 0)
		return ret;
	mutex_lock(&smmu->stream_map_mutex);
	/* Caller has verified VBIF halt acknowledgements and asserted core reset.
	 * Only unsecure 1c00/mask-2 SMRs may retire; secure 1c01 stays untouched.
	 * Keep old context banks reserved: firmware may share a bank with secure
	 * streams. New display domains always allocate a different context bank.
	 */
	for (i = 0; i < smmu->num_mapping_groups; i++) {
		struct arm_smmu_smr *smr = &smmu->smrs[i];

		if (!smr->valid || ((smr->id ^ 0x1c00) & ~2U) || (smr->mask & ~2U))
			continue;
		if (!smmu->s2crs[i].boot_reserved || smmu->s2crs[i].count) {
			ret = -EBUSY;
			goto out;
		}
	}
	for (i = 0; i < smmu->num_mapping_groups; i++) {
		struct arm_smmu_smr *smr = &smmu->smrs[i];

		if (!smr->valid || ((smr->id ^ 0x1c00) & ~2U) || (smr->mask & ~2U))
			continue;
		/* Invalidate the old match only after DMA has been drained. No bypass. */
		arm_smmu_gr0_write(smmu, ARM_SMMU_GR0_SMR(i), 0);
		if (arm_smmu_gr0_read(smmu, ARM_SMMU_GR0_SMR(i)) & ARM_SMMU_SMR_VALID) {
			ret = -EACCES;
			goto out;
		}
		smr->valid = false;
		smmu->s2crs[i].boot_reserved = false;
		smmu->s2crs[i].type = S2CR_TYPE_FAULT;
		smmu->s2crs[i].cbndx = 0xff;
	}
	smmu->uke_display_quiesced = true;
	ret = 0;
out:
	mutex_unlock(&smmu->stream_map_mutex);
	pm_runtime_put(supplier);
	return ret;
}
EXPORT_SYMBOL_GPL(qcom_uke_display_release);

static bool qcom_uke_display_domain(struct arm_smmu_device *smmu,
				    struct device *dev)
{
	struct iommu_fwspec *spec = dev_iommu_fwspec_get(dev);

	return smmu->uke_display_quiesced &&
		of_device_is_compatible(dev->of_node, "qcom,sm7675-dpu") &&
		spec && spec->num_ids == 1 && spec->ids[0] == 0x00021c00;
}

static int qcom_uke_display_init_context(struct arm_smmu_domain *domain,
				       struct io_pgtable_cfg *cfg, struct device *dev)
{
	struct arm_smmu_device *smmu = domain->smmu;
	u32 value;

	if (!qcom_uke_display_domain(smmu, dev))
		return 0; /* Existing USB/GPI behavior is unchanged. */
	if (domain->stage != ARM_SMMU_DOMAIN_S1)
		return -EOPNOTSUPP;
	/* OEM Cliffs ACTLR table: 1c00/mask-2 -> 1. New, stopped context only. */
	arm_smmu_cb_write(smmu, domain->cfg.cbndx, ARM_SMMU_CB_ACTLR, 1);
	value = arm_smmu_cb_read(smmu, domain->cfg.cbndx, ARM_SMMU_CB_ACTLR);
	if (value != 1)
		return dev_err_probe(dev, -EACCES, "display ACTLR write did not stick\n");
	return 0;
}

static bool qcom_uke_display_actlr_matches(struct arm_smmu_device *smmu)
{
	const __be32 *rules;
	int len, i;

	rules = of_get_property(smmu->dev->of_node, "qcom,actlr", &len);
	if (!rules || len % (3 * sizeof(u32)))
		return false;
	for (i = 0; i < len / sizeof(u32); i += 3)
		if (be32_to_cpu(rules[i]) == 0x1c00 &&
		    be32_to_cpu(rules[i + 1]) == 2)
			return be32_to_cpu(rules[i + 2]) == 1;
	return false;
}
