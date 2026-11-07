// SPDX-License-Identifier: GPL-2.0-only
/* Uke's permanent configuration supplier uses the existing audio DMA group.
 * OF identity is sufficient here: APM must wait for this supplier before it
 * populates its frontend. The provider later verifies group/domain equality.
 */
static bool qcom_uke_audio_config_dma(struct device *dev,
				    struct arm_smmu_device *smmu)
{
	struct iommu_fwspec *spec = dev_iommu_fwspec_get(dev);
	struct device_node *node, *apm = NULL, *fe = NULL, *controller = NULL;
	const __be32 *supplier, *frontend, *cells;
	bool match = false;
	int bytes;

	if (!of_machine_is_compatible("xiaomi,uke") ||
	    !of_machine_is_compatible("qcom,sm7675") ||
	    !dev->of_node || dev->of_node->parent != of_root ||
	    !of_device_is_available(dev->of_node) ||
	    !of_device_is_compatible(dev->of_node, "xiaomi,uke-audio-config-memory") ||
	    !of_device_is_compatible(smmu->dev->of_node, "qcom,sm7675-boot-smmu") ||
	    !spec || spec->num_ids != 2 ||
	    spec->ids[0] != 0x801001 || spec->ids[1] != 0x1061)
		return false;
	node = of_find_node_by_path("/audio-config-memory");
	if (!node || node != dev->of_node)
		goto out;
	apm = of_find_node_by_path("/soc/remoteproc-adsp@03000000/glink-edge/qcom,gpr/service@1");
	if (!apm || !of_device_is_available(apm) ||
	    !of_device_is_compatible(apm, "qcom,q6apm") ||
	    !of_find_property(apm, "xiaomi,fs19xx-protected", &bytes) || bytes)
		goto out;
	fe = of_find_node_by_path("/soc/remoteproc-adsp@03000000/glink-edge/qcom,gpr/service@1/dais");
	if (!fe || fe->parent != apm || !of_device_is_available(fe) ||
	    !of_device_is_compatible(fe, "qcom,q6apm-dais") ||
	    !of_find_property(fe, "xiaomi,hdmi-only", &bytes) || bytes)
		goto out;
	supplier = of_get_property(node, "iommus", &bytes);
	if (!supplier || bytes != 6 * sizeof(*supplier) ||
	    !be32_to_cpu(supplier[0]) || supplier[0] != supplier[3] ||
	    be32_to_cpu(supplier[1]) != 0x1001 || be32_to_cpu(supplier[2]) != 0x80 ||
	    be32_to_cpu(supplier[4]) != 0x1061 || be32_to_cpu(supplier[5]))
		goto out;
	frontend = of_get_property(fe, "iommus", &bytes);
	if (!frontend || bytes != 6 * sizeof(*frontend) ||
	    memcmp(supplier, frontend, bytes))
		goto out;
	controller = of_find_node_by_phandle(be32_to_cpu(supplier[0]));
	if (!controller || controller != smmu->dev->of_node ||
	    !of_device_is_available(controller))
		goto out;
	cells = of_get_property(controller, "#iommu-cells", &bytes);
	match = cells && bytes == sizeof(*cells) && be32_to_cpu(*cells) == 2;
out:
	of_node_put(controller);
	of_node_put(fe);
	of_node_put(apm);
	of_node_put(node);
	return match;
}
