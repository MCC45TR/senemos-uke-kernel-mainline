/* SPDX-License-Identifier: GPL-2.0-only */
/* Explicit native-display candidate only; called on the private adapted FDT. */
static int UKE_INIT uke_abl_native(void *fdt, void *overlay, size_t bytes,
				 const char *panel_selector)
{
	static const char backlight[] = "/soc/qcom,qupv3_0_geni_se@ac0000/i2c@a80000/ktz8866@11";
	static const char *const bias_paths[] = {
		"/soc/display_gpio_regulator_vsp", "/soc/display_gpio_regulator_vsn"
	};
	static const char *const bias_symbols[] = { "display_panel_vsp", "display_panel_vsn" };
	char framebuffer[128];
	const char *text;
	int chosen, node, size, ret;
	unsigned int i;

	if (!fdt || !overlay || bytes < sizeof(struct fdt_header) ||
	    fdt_check_full(overlay, bytes) ||
	    fdt_node_check_compatible(fdt, 0, "xiaomi,uke"))
		return -FDT_ERR_BADVALUE;
	chosen = fdt_path_offset(fdt, "/chosen");
	text = (const char *)fdt_getprop(fdt, chosen, "bootargs", &size);
	if (!text || size <= 0 || text[size - 1] || !strstr(text, panel_selector))
		return -FDT_ERR_BADVALUE;
	text = (const char *)fdt_getprop(fdt, chosen, "stdout-path", &size);
	if (!text || size <= 0 || size > (int)sizeof(framebuffer) || text[size - 1] ||
	    strncmp(text, "/chosen/framebuffer@", 20))
		return -FDT_ERR_BADVALUE;
	memcpy(framebuffer, text, size);
	node = fdt_path_offset(fdt, framebuffer);
	if (node < 0 || fdt_node_check_compatible(fdt, node, "simple-framebuffer"))
		return -FDT_ERR_BADVALUE;
	node = fdt_path_offset(fdt, backlight);
	if (node < 0 || fdt_node_check_compatible(fdt, node, "xiaomi,uke-ktz8866-primary") ||
	    !fdt_get_phandle(fdt, node))
		return -FDT_ERR_BADVALUE;
	for (i = 0; i < 2; i++) {
		node = fdt_path_offset(fdt, bias_paths[i]);
		if (node < 0 || fdt_node_check_compatible(fdt, node, "regulator-fixed") ||
		    !fdt_get_phandle(fdt, node))
			return -FDT_ERR_BADVALUE;
	}
	node = fdt_path_offset(fdt, "/__symbols__");
	if (node < 0)
		return node;
	ret = fdt_setprop_string(fdt, node, "uke_primary_backlight", backlight);
	if (ret)
		return ret;
	/* ABL preserves the Uke bias providers but drops their OEM symbol names. */
	for (i = 0; i < 2; i++) {
		ret = fdt_setprop_string(fdt, node, bias_symbols[i], bias_paths[i]);
		if (ret)
			return ret;
	}
	ret = fdt_overlay_apply(fdt, overlay);
	if (ret)
		return ret;
	node = fdt_path_offset(fdt, framebuffer);
	ret = fdt_setprop_string(fdt, node, "status", "disabled");
	if (ret)
		return ret;
	chosen = fdt_path_offset(fdt, "/chosen");
	ret = fdt_delprop(fdt, chosen, "stdout-path");
	return ret ? ret : fdt_pack(fdt);
}
