/* SPDX-License-Identifier: GPL-2.0-only */
/* Included after the retained video/display helpers in arm-smmu-qcom.c.
 * Exact Uke DT 94c84aeb: unmasked CDSP streams c01/c02 require ACTLR 0x303.
 * Upstream qcom,fastrpc-compute-cb uses the same deep-prefetch/CPRE/CMTLB bits.
 */
static bool qcom_uke_cdsp_domain(struct arm_smmu_device *smmu, struct device *dev)
{
	struct iommu_fwspec *spec = dev_iommu_fwspec_get(dev);

	return of_machine_is_compatible("xiaomi,uke") &&
		of_device_is_compatible(smmu->dev->of_node, "qcom,sm7675-boot-smmu") &&
		spec && spec->num_ids == 1 &&
		(spec->ids[0] == 0xc01 || spec->ids[0] == 0xc02) &&
		qcom_uke_sensor_cb(dev);
}

static bool qcom_uke_cdsp_actlr_matches(struct arm_smmu_device *smmu,
				       struct device *dev)
{
	struct iommu_fwspec *spec = dev_iommu_fwspec_get(dev);
	const __be32 *rules;
	unsigned int found = 0, i;
	u32 sid;
	int len;

	if (!qcom_uke_cdsp_domain(smmu, dev))
		return false;
	sid = spec->ids[0];
	rules = of_get_property(smmu->dev->of_node, "qcom,actlr", &len);
	if (!rules || len <= 0 || len % (3 * sizeof(u32)))
		return false;
	for (i = 0; i < len / sizeof(u32); i += 3) {
		u32 id = be32_to_cpu(rules[i]);
		u32 mask = be32_to_cpu(rules[i + 1]);
		u32 value = be32_to_cpu(rules[i + 2]);

		if ((sid ^ id) & ~mask)
			continue;
		/* No broad, conflicting or duplicate rule may authorize a context. */
		if (id != sid || mask || value != 0x303 || ++found != 1)
			return false;
	}
	return found == 1;
}

static int qcom_uke_cdsp_init_context(struct arm_smmu_domain *domain,
				      struct io_pgtable_cfg *cfg, struct device *dev)
{
	struct arm_smmu_device *smmu = domain->smmu;
	unsigned int cb = domain->cfg.cbndx;
	u32 value;

	if (!qcom_uke_cdsp_domain(smmu, dev))
		return qcom_uke_init_context(domain, cfg, dev);
	if (domain->stage != ARM_SMMU_DOMAIN_S1 || cfg->ias < 32)
		return -EOPNOTSUPP;
	if (cb >= smmu->num_context_banks || test_bit(cb, smmu->boot_context_map))
		return -EBUSY;
	if (!qcom_uke_cdsp_actlr_matches(smmu, dev))
		return -EINVAL;
	/* Generic allocation chose a fresh bank; no firmware-owned bank is changed. */
	arm_smmu_cb_write(smmu, cb, ARM_SMMU_CB_ACTLR, 0x303);
	value = arm_smmu_cb_read(smmu, cb, ARM_SMMU_CB_ACTLR);
	if (value != 0x303)
		return dev_err_probe(dev, -EACCES, "CDSP ACTLR write did not stick\n");
	return 0;
}
