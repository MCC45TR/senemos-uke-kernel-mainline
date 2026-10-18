/* SPDX-License-Identifier: GPL-2.0-only */
/* Translate the selected Uke OEM UART/power graph; never borrow donor rails. */
static int UKE_INIT uke_bluetooth(void *fdt)
{
	static const char uart_path[] = "/soc/qcom,qupv3_1_geni_se@8c0000/qcom,qup_uart@888000";
	static const char bt_path[] = "/soc/bt_wcn6750";
	static const struct { const char *oem, *native, *resource; } supplies[] = {
		{ "qcom,bt-vdd-io", "vddio-supply", "ldob7" },
		{ "qcom,bt-vdd-aon", "vddaon-supply", "smpb3" },
		{ "qcom,bt-vdd-dig", "vddbtcxmx-supply", "smpb3" },
		{ "qcom,bt-vdd-rfacmn", "vddrfacmn-supply", "smpb3" },
		{ "qcom,bt-vdd-rfa-0p8", "vddrfa0p8-supply", "smpb3" },
		{ "qcom,bt-vdd-rfa1", "vddrfa1p7-supply", "smpb1" },
		{ "qcom,bt-vdd-rfa2", "vddrfa1p2-supply", "smpb2" },
		{ "qcom,bt-vdd-ipa-2p2", "vddrfa2p2-supply", "smpe3" },
	};
	fdt32_t rails[8], active[4], sleep[4], enable[3], swctrl[3], reset_pin, irqs[7];
	const fdt32_t *value;
	const char *text;
	char property[64], pin[16], function[24];
	int uart, bt, tlmm, node, mux, size, ret, i, state;
	unsigned int gpio_phandle, gcc_phandle, gic_phandle;

	uart = fdt_path_offset(fdt, uart_path);
	bt = fdt_path_offset(fdt, bt_path);
	tlmm = fdt_path_offset(fdt, "/soc/pinctrl@f000000");
	gpio_phandle = tlmm < 0 ? 0 : fdt_get_phandle(fdt, tlmm);
	gcc_phandle = fdt_get_phandle(fdt, fdt_path_offset(fdt, "/soc/clock-controller@100000"));
	gic_phandle = fdt_get_phandle(fdt, fdt_path_offset(fdt, "/soc/interrupt-controller@17100000"));
	if (uart < 0 || bt < 0 || !gpio_phandle ||
	    uke_path_reg(fdt, uart_path, 0x888000, 0x4000) ||
	    fdt_node_check_compatible(fdt, uart, "qcom,msm-geni-serial-hs") ||
	    fdt_node_check_compatible(fdt, bt, "qcom,wcn6750-bt") ||
	    fdt_subnode_offset(fdt, uart, "bluetooth") != -FDT_ERR_NOTFOUND)
		return -FDT_ERR_BADVALUE;
	value = fdt_getprop(fdt, uart, "clocks", &size);
	if (!value || size != 8 || !gcc_phandle || fdt32_to_cpu(value[0]) != gcc_phandle ||
	    fdt32_to_cpu(value[1]) != 90)
		return -FDT_ERR_BADVALUE;
	value = fdt_getprop(fdt, uart, "interrupts-extended", &size);
	if (!value || size != 28 || !gic_phandle || fdt32_to_cpu(value[0]) != gic_phandle ||
	    fdt32_to_cpu(value[1]) != 0 ||
	    fdt32_to_cpu(value[2]) != 584 || fdt32_to_cpu(value[3]) != 4 ||
	    fdt32_to_cpu(value[4]) != gpio_phandle ||
	    fdt32_to_cpu(value[5]) != 43 || fdt32_to_cpu(value[6]) != 4)
		return -FDT_ERR_BADVALUE;
	memcpy(irqs, value, sizeof(irqs));
	/* The OEM UART driver overrides its DT wake level with a falling edge. */
	irqs[6] = cpu_to_fdt32(2);
	value = fdt_getprop(fdt, uart, "pinctrl-1", &size);
	if (!value || size != sizeof(active))
		return -FDT_ERR_BADVALUE;
	memcpy(active, value, sizeof(active));
	value = fdt_getprop(fdt, uart, "pinctrl-3", &size);
	if (!value || size != sizeof(sleep))
		return -FDT_ERR_BADVALUE;
	memcpy(sleep, value, sizeof(sleep));
	for (state = 0; state < 2; state++) {
		for (i = 0; i < 4; i++) {
			node = fdt_node_offset_by_phandle(fdt, fdt32_to_cpu(state ? sleep[i] : active[i]));
			mux = fdt_subnode_offset(fdt, node, "mux");
			snprintf(pin, sizeof(pin), "gpio%d", 40 + i);
			if (state)
				snprintf(function, sizeof(function), "gpio");
			else
				snprintf(function, sizeof(function), "qup1_se2_l%d", i);
			if (fdt_stringlist_count(fdt, mux, "pins") != 1 ||
			    fdt_stringlist_search(fdt, mux, "pins", pin) != 0 ||
			    fdt_stringlist_count(fdt, mux, "function") != 1 ||
			    fdt_stringlist_search(fdt, mux, "function", function) != 0)
				return -FDT_ERR_BADVALUE;
		}
	}
	for (i = 0; i < 8; i++) {
		snprintf(property, sizeof(property), "%s-supply", supplies[i].oem);
		value = fdt_getprop(fdt, bt, property, &size);
		if (!value || size != 4)
			return -FDT_ERR_BADVALUE;
		rails[i] = *value;
		node = fdt_node_offset_by_phandle(fdt, fdt32_to_cpu(*value));
		if (node < 0)
			return -FDT_ERR_BADPHANDLE;
		node = fdt_parent_offset(fdt, node);
		if (fdt_stringlist_count(fdt, node, "qcom,resource-name") != 1 ||
		    fdt_stringlist_search(fdt, node, "qcom,resource-name", supplies[i].resource) != 0)
			return -FDT_ERR_BADVALUE;
		snprintf(property, sizeof(property), "%s-config", supplies[i].oem);
		value = fdt_getprop(fdt, bt, property, &size);
		if (!value || size != 16 || fdt32_to_cpu(value[2]) != 0 || fdt32_to_cpu(value[3]) != 1)
			return -FDT_ERR_BADVALUE;
	}
	value = fdt_getprop(fdt, bt, "qcom,bt-reset-gpio", &size);
	if (!value || size != sizeof(enable) || fdt32_to_cpu(value[0]) != gpio_phandle ||
	    fdt32_to_cpu(value[1]) != 156 || fdt32_to_cpu(value[2]) != 0)
		return -FDT_ERR_BADVALUE;
	memcpy(enable, value, sizeof(enable));
	value = fdt_getprop(fdt, bt, "qcom,bt-sw-ctrl-gpio", &size);
	if (!value || size != sizeof(swctrl) || fdt32_to_cpu(value[0]) != gpio_phandle ||
	    fdt32_to_cpu(value[1]) != 80 || fdt32_to_cpu(value[2]) != 0)
		return -FDT_ERR_BADVALUE;
	memcpy(swctrl, value, sizeof(swctrl));
	text = fdt_getprop(fdt, bt, "pinctrl-names", &size);
	if (!text || size != sizeof("default") || memcmp(text, "default", size))
		return -FDT_ERR_BADVALUE;
	value = fdt_getprop(fdt, bt, "pinctrl-0", &size);
	if (!value || size != sizeof(reset_pin))
		return -FDT_ERR_BADVALUE;
	reset_pin = *value;
	node = fdt_node_offset_by_phandle(fdt, fdt32_to_cpu(reset_pin));
	if (node != fdt_subnode_offset(fdt, tlmm, "bt_en_sleep"))
		return -FDT_ERR_BADVALUE;
	mux = fdt_subnode_offset(fdt, node, "mux");
	if (fdt_stringlist_count(fdt, mux, "pins") != 1 ||
	    fdt_stringlist_search(fdt, mux, "pins", "gpio156") != 0 ||
	    fdt_stringlist_count(fdt, mux, "function") != 1 ||
	    fdt_stringlist_search(fdt, mux, "function", "gpio") != 0)
		return -FDT_ERR_BADVALUE;

#define UKE_BT_SET(operation) do { ret = (operation); if (ret) return ret; } while (0)
	UKE_BT_SET(fdt_setprop_string(fdt, bt, "status", "disabled"));
	uart = fdt_path_offset(fdt, uart_path);
	UKE_BT_SET(fdt_setprop(fdt, uart, "interrupts-extended", irqs, sizeof(irqs)));
	UKE_BT_SET(fdt_setprop_string(fdt, uart, "compatible", "qcom,geni-uart"));
	UKE_BT_SET(fdt_setprop_string(fdt, uart, "clock-names", "se"));
	UKE_BT_SET(fdt_setprop(fdt, uart, "pinctrl-names", "default\0sleep", sizeof("default\0sleep")));
	UKE_BT_SET(fdt_setprop(fdt, uart, "pinctrl-0", active, sizeof(active)));
	UKE_BT_SET(fdt_setprop(fdt, uart, "pinctrl-1", sleep, sizeof(sleep)));
	UKE_BT_SET(fdt_delprop(fdt, uart, "pinctrl-2"));
	UKE_BT_SET(fdt_delprop(fdt, uart, "pinctrl-3"));
	UKE_BT_SET(fdt_setprop_string(fdt, uart, "status", "okay"));
	node = fdt_add_subnode(fdt, uart, "bluetooth");
	if (node < 0)
		return node;
	UKE_BT_SET(fdt_setprop_string(fdt, node, "compatible", "xiaomi,uke-wcn6750-bt"));
	UKE_BT_SET(fdt_setprop_string(fdt, node, "pinctrl-names", "default"));
	UKE_BT_SET(fdt_setprop(fdt, node, "pinctrl-0", &reset_pin, sizeof(reset_pin)));
	UKE_BT_SET(fdt_setprop(fdt, node, "enable-gpios", enable, sizeof(enable)));
	UKE_BT_SET(fdt_setprop(fdt, node, "swctrl-gpios", swctrl, sizeof(swctrl)));
	/* The Uke TLV transfer times out at 115200; 3 Mbit/s completes firmware setup. */
	UKE_BT_SET(fdt_setprop_u32(fdt, node, "max-speed", 3000000));
	for (i = 0; i < 8; i++)
		UKE_BT_SET(fdt_setprop(fdt, node, supplies[i].native, &rails[i], sizeof(rails[i])));
#undef UKE_BT_SET
	return 0;
}
