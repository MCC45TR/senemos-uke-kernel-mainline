/* SPDX-License-Identifier: GPL-2.0-only */
/* Included by qcom_scm.c: use its convention, descriptor and transport. */
#ifdef CONFIG_QCOM_UKE_EL2_QUERY
struct uke_el2_query_snapshot {
	int transport;
	u64 result[3];
	unsigned int current_el;
	bool boot_hyp_available;
	const char *convention;
};

static struct uke_el2_query_snapshot uke_el2_query;

static ssize_t uke_el2_query_show(struct device *dev,
				struct device_attribute *attr, char *buf)
{
	return sysfs_emit(buf,
		"mode=query-only\nphase=qcom-scm-probe\n"
		"target=0x02000121\nconvention=%s\ntransport=%d\n"
		"availability=%s\nresult0=0x%llx\nresult1=0x%llx\n"
		"result2=0x%llx\ncurrent_el=%u\nboot_hyp_available=%u\n"
		"exit_requested=0\n",
		uke_el2_query.convention, uke_el2_query.transport,
		uke_el2_query.transport ? "unknown" :
			(uke_el2_query.result[0] ? "advertised" : "not-advertised"),
		(unsigned long long)uke_el2_query.result[0],
		(unsigned long long)uke_el2_query.result[1],
		(unsigned long long)uke_el2_query.result[2],
		uke_el2_query.current_el, uke_el2_query.boot_hyp_available);
}
static DEVICE_ATTR_RO(uke_el2_query);

static struct attribute *uke_el2_query_attrs[] = {
	&dev_attr_uke_el2_query.attr,
	NULL,
};
static const struct attribute_group uke_el2_query_group = {
	.attrs = uke_el2_query_attrs,
};

static void uke_el2_query_run(struct device *dev)
{
	struct qcom_scm_desc desc = {
		.svc = QCOM_SCM_SVC_INFO,
		.cmd = QCOM_SCM_INFO_IS_CALL_AVAIL,
		.arginfo = QCOM_SCM_ARGS(1),
		.owner = ARM_SMCCC_OWNER_SIP,
	};
	struct qcom_scm_res res = {};
	int ret;

	if (!of_machine_is_compatible("xiaomi,uke")) {
		dev_info(dev, "UKE_EL2_QUERY: skipped foreign board\n");
		return;
	}

	uke_el2_query.current_el = read_sysreg(CurrentEL) >> 2;
	uke_el2_query.boot_hyp_available = is_hyp_mode_available();
	switch (__get_convention()) {
	case SMC_CONVENTION_ARM_64:
		uke_el2_query.convention = "smc64";
		break;
	case SMC_CONVENTION_ARM_32:
		uke_el2_query.convention = "smc32";
		break;
	case SMC_CONVENTION_LEGACY:
		uke_el2_query.convention = "legacy";
		break;
	default:
		uke_el2_query.convention = "unknown";
		uke_el2_query.transport = -EOPNOTSUPP;
		goto publish;
	}

	if (__get_convention() == SMC_CONVENTION_LEGACY)
		desc.args[0] = SCM_LEGACY_FNID(QCOM_SCM_SVC_BOOT, 0x21);
	else
		desc.args[0] = SCM_SMC_FNID(QCOM_SCM_SVC_BOOT, 0x21) |
			(ARM_SMCCC_OWNER_SIP << ARM_SMCCC_OWNER_SHIFT);

	/* INFO query only. Never invoke BOOT/0x21 or the early-exit tuple. */
	uke_el2_query.transport = qcom_scm_call(dev, &desc, &res);
	memcpy(uke_el2_query.result, res.result, sizeof(uke_el2_query.result));
publish:
	dev_info(dev,
		 "UKE_EL2_QUERY: query-only phase=qcom-scm-probe target=0x02000121 convention=%s transport=%d result0=0x%llx result1=0x%llx result2=0x%llx current_el=%u boot_hyp_available=%u exit_requested=0\n",
		 uke_el2_query.convention, uke_el2_query.transport,
		 (unsigned long long)uke_el2_query.result[0],
		 (unsigned long long)uke_el2_query.result[1],
		 (unsigned long long)uke_el2_query.result[2],
		 uke_el2_query.current_el, uke_el2_query.boot_hyp_available);
	ret = devm_device_add_group(dev, &uke_el2_query_group);
	if (ret)
		dev_warn(dev, "UKE_EL2_QUERY: snapshot sysfs unavailable: %d\n", ret);
}
#else
static inline void uke_el2_query_run(struct device *dev) {}
#endif
