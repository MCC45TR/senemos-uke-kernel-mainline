/* SPDX-License-Identifier: GPL-2.0-only */
/* Link the existing firmware sensor description to the board's lid switch.
 * No sample, brightness curve, firmware identity or calibration is embedded.
 */
static int UKE_INIT uke_dual_light_lid(void *fdt)
{
	const char *paths[] = {
		"/firmware/ssc-sensors/front-light",
		"/firmware/ssc-sensors/rear-light",
	};
	const char *datatypes[] = { "ambient_light", "ambient_light_back" };
	const fdt32_t *code, *old;
	const char *type;
	unsigned int phandle;
	unsigned int i;
	int node, lid, bytes, ret;

	if (fdt_node_check_compatible(fdt, 0, "xiaomi,uke") ||
	    fdt_node_check_compatible(fdt, 0, "qcom,sm7675"))
		return -FDT_ERR_BADVALUE;
	node = fdt_path_offset(fdt, "/firmware/ssc-sensors");
	if (node < 0 || fdt_node_check_compatible(fdt, node, "xiaomi,uke-ssc-iio"))
		return -FDT_ERR_BADVALUE;
	for (i = 0; i < 2; i++) {
		node = fdt_path_offset(fdt, paths[i]);
		if (node < 0)
			return -FDT_ERR_BADVALUE;
		type = fdt_getprop(fdt, node, "qcom,ssc-datatype", &bytes);
		if (!type || bytes != (int)strlen(datatypes[i]) + 1 ||
		    strcmp(type, datatypes[i]))
			return -FDT_ERR_BADVALUE;
	}
	lid = fdt_path_offset(fdt, "/hall-lid");
	if (lid < 0 || fdt_node_check_compatible(fdt, lid, "qcom,smp2p-switch"))
		return -FDT_ERR_BADVALUE;
	code = fdt_getprop(fdt, lid, "linux,code", &bytes);
	if (!code || bytes != (int)sizeof(*code) || fdt32_to_cpu(*code) != 0)
		return -FDT_ERR_BADVALUE;
	phandle = fdt_get_phandle(fdt, lid);
	node = fdt_path_offset(fdt, "/firmware/ssc-sensors");
	old = fdt_getprop(fdt, node, "lid-switch", &bytes);
	if (old && (bytes != (int)sizeof(*old) || !phandle ||
		    fdt32_to_cpu(*old) != phandle))
		return -FDT_ERR_BADVALUE;
	if (!phandle) {
		ret = fdt_generate_phandle(fdt, &phandle);
		if (ret)
			return ret;
		ret = fdt_setprop_u32(fdt, lid, "phandle", phandle);
		if (ret)
			return ret;
	}
	node = fdt_path_offset(fdt, "/firmware/ssc-sensors");
	return fdt_setprop_u32(fdt, node, "lid-switch", phandle);
}
