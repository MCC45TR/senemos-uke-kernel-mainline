/* SPDX-License-Identifier: GPL-2.0-only */
/* Exact Uke OEM 94c84aeb9e517dbde546fc732033c184094c8e57.
 * Preserve boot-selected handles. No arbitrary context bank or rail admission.
 */
#define UKE_CDSP_PATH "/soc/remoteproc-cdsp@32300000"
#define UKE_CDSP_RPC UKE_CDSP_PATH "/glink-edge/qcom,msm_fastrpc_rpmsg"
#define UKE_POGO_BUS "/soc/qcom,qupv3_0_geni_se@ac0000/i2c@a8c000"
#define UKE_POGO_NODE UKE_POGO_BUS "/nanosic@4c"

static int UKE_INIT uke_cp_cells(const void *fdt, int node, const char *property,
				 const unsigned int *expected, unsigned int count)
{
	const fdt32_t *value;
	unsigned int i;
	int bytes;

	value = fdt_getprop(fdt, node, property, &bytes);
	if (!value || bytes != (int)(count * sizeof(*value)))
		return -FDT_ERR_BADVALUE;
	for (i = 0; i < count; i++)
		if (fdt32_to_cpu(value[i]) != expected[i])
			return -FDT_ERR_BADVALUE;
	return 0;
}

static int UKE_INIT uke_cp_string(const void *fdt, int node,
				  const char *property, const char *expected)
{
	const char *value;
	int bytes;

	value = fdt_getprop(fdt, node, property, &bytes);
	return value && bytes == (int)strlen(expected) + 1 &&
	       !memcmp(value, expected, bytes) ? 0 : -FDT_ERR_BADVALUE;
}

static int UKE_INIT uke_cdsp(void *fdt)
{
	static const unsigned int geometry[][4] = {
		{ 0, 0x99900000, 0, 0x01400000 },
		{ 0, 0x9ad00000, 0, 0x00080000 },
		{ 0, 0x82600000, 0, 0x00100000 },
	};
	static const unsigned int pd[] = { 1, 7 };
	static const char *const cb[] = {
		"/soc/qcom,msm_fastrpc/qcom,msm_fastrpc_compute_cb1",
		"/soc/qcom,msm_fastrpc/qcom,msm_fastrpc_compute_cb2",
	};
	fdt32_t regions[3], maps[2][3];
	const fdt32_t *value;
	unsigned int smmu, expected[3], i;
	int node, bytes, region, ret;

	node = fdt_path_offset(fdt, UKE_CDSP_PATH);
	if (node < 0 || fdt_node_check_compatible(fdt, node, "qcom,cliffs-cdsp-pas") ||
	    uke_path_reg(fdt, UKE_CDSP_PATH, 0x32300000, 0x10000))
		return -FDT_ERR_BADVALUE;
	value = fdt_getprop(fdt, node, "memory-region", &bytes);
	if (!value || bytes != 8)
		return -FDT_ERR_BADVALUE;
	memcpy(regions, value, 8);
	value = fdt_getprop(fdt, node, "global-sync-mem-reg", &bytes);
	if (!value || bytes != 4)
		return -FDT_ERR_BADVALUE;
	regions[2] = *value;
	for (i = 0; i < 3; i++) {
		region = fdt_node_offset_by_phandle(fdt, fdt32_to_cpu(regions[i]));
		if (region < 0 || uke_cp_cells(fdt, region, "reg", geometry[i], 4) ||
		    !fdt_getprop(fdt, region, "no-map", &bytes) || bytes)
			return -FDT_ERR_BADVALUE;
	}
	smmu = fdt_get_phandle(fdt, fdt_path_offset(fdt, "/soc/apps-smmu@15000000"));
	if (!smmu)
		return -FDT_ERR_BADPHANDLE;
	for (i = 0; i < 2; i++) {
		node = fdt_path_offset(fdt, cb[i]);
		expected[0] = smmu;
		expected[1] = 0xc01 + i;
		expected[2] = 0;
		if (node < 0 || fdt_node_check_compatible(fdt, node, "qcom,msm-fastrpc-compute-cb") ||
		    uke_cp_string(fdt, node, "label", "cdsprpc-smd") ||
		    uke_cp_cells(fdt, node, "pd-type", &pd[i], 1) ||
		    uke_cp_cells(fdt, node, "iommus", expected, 3) ||
		    fdt_getprop(fdt, node, "qcom,secure-context-bank", NULL) ||
		    !fdt_getprop(fdt, node, "dma-coherent", &bytes) || bytes)
			return -FDT_ERR_BADVALUE;
		value = fdt_getprop(fdt, node, "iommus", NULL);
		memcpy(maps[i], value, sizeof(maps[i]));
	}
	node = fdt_path_offset(fdt, UKE_CDSP_RPC);
	if (node < 0 || fdt_node_check_compatible(fdt, node, "qcom,msm-fastrpc-rpmsg") ||
	    uke_cp_string(fdt, node, "qcom,glink-channels", "fastrpcglink-apps-dsp") ||
	    fdt_getprop(fdt, node, "qcom,non-secure-domain", NULL) ||
	    fdt_getprop(fdt, node, "qcom,vmids", NULL) ||
	    fdt_getprop(fdt, node, "memory-region", NULL) ||
	    fdt_first_subnode(fdt, node) != -FDT_ERR_NOTFOUND)
		return -FDT_ERR_BADVALUE;
	ret = fdt_setprop_string(fdt, node, "compatible", "qcom,fastrpc");
	if (ret)
		return ret;
	ret = fdt_setprop_string(fdt, node, "label", "cdsp");
	if (ret)
		return ret;
	ret = fdt_setprop_u32(fdt, node, "#address-cells", 1);
	if (ret)
		return ret;
	ret = fdt_setprop_u32(fdt, node, "#size-cells", 0);
	if (ret)
		return ret;
	ret = uke_delete_optional(fdt, UKE_CDSP_RPC, "qcom,intents");
	if (ret)
		return ret;
	for (i = 0; i < 2; i++) {
		char name[24];

		snprintf(name, sizeof(name), "compute-cb@%u", i + 1);
		node = fdt_add_subnode(fdt, fdt_path_offset(fdt, UKE_CDSP_RPC), name);
		if (node < 0)
			return node;
		ret = fdt_setprop_string(fdt, node, "compatible", "qcom,fastrpc-compute-cb");
		if (ret)
			return ret;
		ret = fdt_setprop_u32(fdt, node, "reg", i + 1);
		if (ret)
			return ret;
		ret = fdt_setprop(fdt, node, "iommus", maps[i], sizeof(maps[i]));
		if (ret)
			return ret;
		ret = fdt_setprop(fdt, node, "dma-coherent", NULL, 0);
		if (ret)
			return ret;
	}
	node = fdt_path_offset(fdt, UKE_CDSP_PATH);
	ret = fdt_setprop(fdt, node, "memory-region", regions, sizeof(regions));
	if (ret)
		return ret;
	/* No unsigned-domain override, remote heap or new memory reservation. */
	return fdt_setprop_string(fdt, node, "status", "okay");
}

static int UKE_INIT uke_pogo(void *fdt)
{
	static const char *const gpio_props[] = { "irq_pin", "reset_pin", "status_pin", "sleep_pin" };
	static const unsigned int gpios[] = { 116, 127, 128, 98 };
	static const unsigned int flags[] = { 0x2001, 0, 0, 0 };
	static const char *const supplies[] = { "vdd-supply", "dvdd-supply" };
	static const unsigned int voltage[] = { 3300000, 1800000 };
	static const char *const resources[] = { "ldob22", "ldob23" };
	fdt32_t route[8], irq[6], reset[3], wake[3];
	unsigned int tlmm, gpi, expected[12], i;
	const fdt32_t *value;
	int node, bus, bytes, ret, rail;

	bus = fdt_path_offset(fdt, UKE_POGO_BUS);
	node = fdt_path_offset(fdt, UKE_POGO_NODE);
	tlmm = fdt_get_phandle(fdt, fdt_path_offset(fdt, "/soc/pinctrl@f000000"));
	gpi = fdt_get_phandle(fdt, fdt_path_offset(fdt, "/soc/qcom,gpi-dma@a00000"));
	if (bus < 0 || node < 0 || !tlmm || !gpi ||
	    uke_path_reg(fdt, UKE_POGO_BUS, 0xa8c000, 0x4000) ||
	    fdt_node_check_compatible(fdt, bus, "qcom,i2c-geni") ||
	    fdt_node_check_compatible(fdt, node, "nanosic,803"))
		return -FDT_ERR_BADVALUE;
	if (fdt_first_subnode(fdt, bus) != node ||
	    fdt_next_subnode(fdt, node) != -FDT_ERR_NOTFOUND)
		return -FDT_ERR_BADVALUE;
	expected[0] = 0x4c;
	if (uke_cp_cells(fdt, node, "reg", expected, 1))
		return -FDT_ERR_BADVALUE;
	for (i = 0; i < 4; i++) {
		expected[0] = tlmm;
		expected[1] = gpios[i];
		expected[2] = flags[i];
		if (uke_cp_cells(fdt, node, gpio_props[i], expected, 3))
			return -FDT_ERR_BADVALUE;
	}
	for (i = 0; i < 2; i++) {
		value = fdt_getprop(fdt, node, supplies[i], &bytes);
		if (!value || bytes != 4)
			return -FDT_ERR_BADVALUE;
		rail = fdt_node_offset_by_phandle(fdt, fdt32_to_cpu(*value));
		if (rail < 0 || uke_cp_cells(fdt, rail, "regulator-min-microvolt", &voltage[i], 1) ||
		    uke_cp_cells(fdt, rail, "regulator-max-microvolt", &voltage[i], 1) ||
		    uke_cp_string(fdt, fdt_parent_offset(fdt, rail), "qcom,resource-name", resources[i]))
			return -FDT_ERR_BADVALUE;
	}
	for (i = 0; i < 2; i++) {
		expected[i * 6] = gpi;
		expected[i * 6 + 1] = i;
		expected[i * 6 + 2] = 3;
		expected[i * 6 + 3] = 3;
		expected[i * 6 + 4] = 64;
		expected[i * 6 + 5] = 0;
		route[i * 4] = cpu_to_fdt32(gpi);
		route[i * 4 + 1] = cpu_to_fdt32(i);
		route[i * 4 + 2] = cpu_to_fdt32(3);
		route[i * 4 + 3] = cpu_to_fdt32(3);
	}
	if (uke_cp_cells(fdt, bus, "dmas", expected, 12))
		return -FDT_ERR_BADVALUE;
	irq[0] = irq[3] = reset[0] = wake[0] = cpu_to_fdt32(tlmm);
	irq[1] = cpu_to_fdt32(116);
	irq[4] = cpu_to_fdt32(128);
	irq[2] = irq[5] = reset[2] = cpu_to_fdt32(1);
	reset[1] = cpu_to_fdt32(127);
	wake[1] = cpu_to_fdt32(98);
	wake[2] = 0;
	ret = fdt_setprop_string(fdt, node, "compatible", "xiaomi,uke-wn8030");
	if (ret)
		return ret;
	ret = fdt_setprop(fdt, node, "interrupts-extended", irq, sizeof(irq));
	if (ret)
		return ret;
	ret = fdt_setprop(fdt, node, "interrupt-names", "data\0wakeup", sizeof("data\0wakeup"));
	if (ret)
		return ret;
	ret = fdt_setprop(fdt, node, "reset-gpios", reset, sizeof(reset));
	if (ret)
		return ret;
	ret = fdt_setprop(fdt, node, "wake-gpios", wake, sizeof(wake));
	if (ret)
		return ret;
	ret = fdt_setprop_string(fdt, node, "firmware-name", "qcom/uke/nanosic/MCU_Upgrade.bin");
	if (ret)
		return ret;
	ret = fdt_setprop(fdt, node, "wakeup-source", NULL, 0);
	if (ret)
		return ret;
	ret = fdt_setprop_string(fdt, node, "status", "okay");
	if (ret)
		return ret;
	bus = fdt_path_offset(fdt, UKE_POGO_BUS);
	ret = fdt_setprop_string(fdt, bus, "compatible", "qcom,geni-i2c");
	if (ret)
		return ret;
	ret = fdt_setprop_string(fdt, bus, "clock-names", "se");
	if (ret)
		return ret;
	ret = fdt_setprop(fdt, bus, "dmas", route, sizeof(route));
	if (ret)
		return ret;
	ret = fdt_setprop_u32(fdt, bus, "clock-frequency", 1000000);
	if (ret)
		return ret;
	return fdt_setprop_string(fdt, bus, "status", "okay");
}
