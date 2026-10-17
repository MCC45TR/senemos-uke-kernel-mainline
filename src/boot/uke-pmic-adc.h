/* SPDX-License-Identifier: GPL-2.0-only */
/* Exact Uke OEM ADC graph; unsupported charger scalers stay unexported. */
static int UKE_INIT uke_pmic_adc(void *fdt)
{
	static const char path[] = "/soc/qcom,spmi@c42d000/qcom,pmk8550@0/vadc@9000";
	static const unsigned int channels[] = {
		0x000, 0x001, 0x003, 0x044, 0x203, 0x303, 0x100, 0x101,
		0x103, 0x18e, 0x700, 0x701, 0x703, 0x78e,
		0x710, 0x717, 0x7a1, 0x744,
		0x145, 0x147, 0x148, 0x14c, 0x14d, 0x74b, 0x74c, 0x749, 0x747,
	};
	static const struct { const char *zone, *name; unsigned int channel; } thermistors[] = {
		{ "xo-therm", "xo-thermal-sensor", 0x044 },
		{ "cpu_therm", "board-cpu-thermal-sensor", 0x145 },
		{ "quiet_therm", "quiet-thermal-sensor", 0x147 },
		{ "flash_therm", "flash-thermal-sensor", 0x148 },
		{ "display_therm", "display-thermal-sensor", 0x14c },
		{ "conn_therm2", "connector2-thermal-sensor", 0x14d },
		{ "wifi_therm", "wifi-thermal-sensor", 0x74c },
		{ "backlight_therm", "backlight-thermal-sensor", 0x74b },
		{ "charger_therm0", "charger-thermal-sensor", 0x749 },
		{ "conn_therm", "connector-thermal-sensor", 0x747 },
	};
	fdt32_t hwmon[46], io[2];
	unsigned int phandle, found = 0, count = 0, i;
	int adc = fdt_path_offset(fdt, path), child, bytes, ret, node, zone;
	const fdt32_t *value;

	if (adc < 0 || fdt_node_check_compatible(fdt, adc, "qcom,spmi-adc5-gen3") ||
	    !(phandle = fdt_get_phandle(fdt, adc)))
		return -FDT_ERR_BADVALUE;
	value = fdt_getprop(fdt, adc, "reg", &bytes);
	if (!value || bytes != 8 || fdt32_to_cpu(value[0]) != 0x9000 ||
	    fdt32_to_cpu(value[1]) != 0x9100)
		return -FDT_ERR_BADVALUE;
	fdt_for_each_subnode(child, fdt, adc) {
		value = fdt_getprop(fdt, child, "reg", &bytes);
		if (!value || bytes != 4)
			return -FDT_ERR_BADVALUE;
		for (i = 0; i < sizeof(channels) / sizeof(channels[0]); i++)
			if (fdt32_to_cpu(*value) == channels[i])
				break;
		if (i == sizeof(channels) / sizeof(channels[0]) || found & (1U << i))
			return -FDT_ERR_BADVALUE;
		found |= 1U << i;
	}
	if (found != (1U << (sizeof(channels) / sizeof(channels[0]))) - 1)
		return -FDT_ERR_BADVALUE;

	/* These four OEM scalers are absent upstream; GLINK still supplies battery telemetry. */
	for (i = 14; i < 18; i++) {
		fdt_for_each_subnode(child, fdt, adc) {
			value = fdt_getprop(fdt, child, "reg", NULL);
			if (fdt32_to_cpu(*value) == channels[i])
				break;
		}
		ret = fdt_del_node(fdt, child);
		if (ret)
			return ret;
	}
	fdt_for_each_subnode(child, fdt, adc) {
		unsigned int channel = fdt32_to_cpu(*(const fdt32_t *)fdt_getprop(fdt, child, "reg", NULL));
		char name[24];

		ret = fdt_delprop(fdt, child, "qcom,adc-tm-type");
		if (ret && ret != -FDT_ERR_NOTFOUND)
			return ret;
		snprintf(name, sizeof(name), "channel@%x", channel);
		ret = fdt_set_name(fdt, child, name);
		if (ret)
			return ret;
		hwmon[count++] = cpu_to_fdt32(phandle);
		hwmon[count++] = cpu_to_fdt32(channel);
	}
	ret = uke_delete_optional(fdt, path, "qcom,debug-base");
	if (ret)
		return ret;
	ret = uke_delete_optional(fdt, path, "io-channel-ranges");
	if (ret)
		return ret;
	ret = uke_delete_optional(fdt, path, "interrupt-names");
	if (ret)
		return ret;
	node = fdt_add_subnode(fdt, 0, "pmic-adc-hwmon");
	if (node < 0)
		return node;
	ret = fdt_setprop_string(fdt, node, "compatible", "iio-hwmon");
	if (ret)
		return ret;
	ret = fdt_setprop(fdt, node, "io-channels", hwmon, count * sizeof(hwmon[0]));
	if (ret)
		return ret;

	for (i = 0; i < sizeof(thermistors) / sizeof(thermistors[0]); i++) {
		unsigned int sensor;
		char zone_path[80];

		snprintf(zone_path, sizeof(zone_path), "/thermal-zones/%s", thermistors[i].zone);
		zone = fdt_path_offset(fdt, zone_path);
		value = fdt_getprop(fdt, zone, "thermal-sensors", &bytes);
		if (!value || bytes != 8 || fdt32_to_cpu(value[0]) != phandle ||
		    fdt32_to_cpu(value[1]) != thermistors[i].channel)
			return -FDT_ERR_BADVALUE;
		ret = fdt_generate_phandle(fdt, &sensor);
		if (ret)
			return ret;
		node = fdt_add_subnode(fdt, 0, thermistors[i].name);
		if (node < 0)
			return node;
		ret = fdt_setprop_u32(fdt, node, "phandle", sensor);
		if (ret)
			return ret;
		ret = fdt_setprop_string(fdt, node, "compatible", "generic-adc-thermal");
		if (ret)
			return ret;
		ret = fdt_setprop_u32(fdt, node, "#thermal-sensor-cells", 0);
		if (ret)
			return ret;
		io[0] = cpu_to_fdt32(phandle);
		io[1] = cpu_to_fdt32(thermistors[i].channel);
		ret = fdt_setprop(fdt, node, "io-channels", io, sizeof(io));
		if (ret)
			return ret;
		ret = fdt_setprop_string(fdt, node, "io-channel-names", "sensor-channel");
		if (ret)
			return ret;
		zone = fdt_path_offset(fdt, zone_path);
		ret = fdt_setprop_u32(fdt, zone, "thermal-sensors", sensor);
		if (ret)
			return ret;
	}
	return 0;
}
