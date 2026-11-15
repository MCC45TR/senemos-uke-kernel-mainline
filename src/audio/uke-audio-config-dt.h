/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_AUDIO_CONFIG_DT_H
#define UKE_AUDIO_CONFIG_DT_H
#define UKE_CONFIG_APM "/soc/remoteproc-adsp@03000000/glink-edge/qcom,gpr/service@1"
#define UKE_CONFIG_FE UKE_CONFIG_APM "/dais"

/* Called on the private, fully composed Uke output, immediately before pack.
 * Preserve the frontend property byte-for-byte; no new SID or hardware range.
 * Any failure discards the output, as in the existing ABL transformation.
 */
static int UKE_INIT uke_audio_config_graph(void *fdt)
{
	fdt32_t iommus[6];
	const fdt32_t *value;
	const void *protected_property;
	const char *status;
	int apm, fe, smmu, node, bytes, ret;
	unsigned int phandle;

	if (fdt_node_check_compatible(fdt, 0, "xiaomi,uke") ||
	    fdt_node_check_compatible(fdt, 0, "qcom,sm7675"))
		return -FDT_ERR_BADVALUE;
	apm = fdt_path_offset(fdt, UKE_CONFIG_APM);
	if (apm < 0)
		return apm == -FDT_ERR_NOTFOUND ? 0 : apm;
	protected_property = fdt_getprop(fdt, apm, "xiaomi,fs19xx-protected", &bytes);
	if (!protected_property)
		return bytes == -FDT_ERR_NOTFOUND ? 0 : bytes;
	if (bytes || fdt_node_check_compatible(fdt, apm, "qcom,q6apm"))
		return -FDT_ERR_BADVALUE;
	fe = fdt_path_offset(fdt, UKE_CONFIG_FE);
	if (fe < 0 || fdt_node_check_compatible(fdt, fe, "qcom,q6apm-dais"))
		return -FDT_ERR_BADVALUE;
	status = fdt_getprop(fdt, fe, "status", &bytes);
	if (!status || bytes != (int)sizeof("okay") || memcmp(status, "okay", bytes))
		return -FDT_ERR_BADVALUE;
	value = fdt_getprop(fdt, fe, "iommus", &bytes);
	if (!value || bytes != (int)sizeof(iommus))
		return -FDT_ERR_BADVALUE;
	memcpy(iommus, value, sizeof(iommus));
	phandle = fdt32_to_cpu(iommus[0]);
	if (!phandle || iommus[0] != iommus[3] ||
	    fdt32_to_cpu(iommus[1]) != 0x1001 || fdt32_to_cpu(iommus[2]) != 0x80 ||
	    fdt32_to_cpu(iommus[4]) != 0x1061 || fdt32_to_cpu(iommus[5]))
		return -FDT_ERR_BADVALUE;
	smmu = fdt_node_offset_by_phandle(fdt, phandle);
	if (smmu < 0)
		return -FDT_ERR_BADVALUE;
	value = fdt_getprop(fdt, smmu, "#iommu-cells", &bytes);
	if (!value || bytes != (int)sizeof(*value) || fdt32_to_cpu(*value) != 2 ||
	    fdt_path_offset(fdt, "/audio-config-memory") != -FDT_ERR_NOTFOUND)
		return -FDT_ERR_BADVALUE;
	node = fdt_add_subnode(fdt, 0, "audio-config-memory");
	if (node < 0)
		return node;
	ret = fdt_setprop_string(fdt, node, "compatible", "xiaomi,uke-audio-config-memory");
	if (ret)
		return ret;
	ret = fdt_setprop_string(fdt, node, "status", "okay");
	if (ret)
		return ret;
	return fdt_setprop(fdt, node, "iommus", iommus, sizeof(iommus));
}
#endif
