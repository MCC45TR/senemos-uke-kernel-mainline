/* SPDX-License-Identifier: GPL-2.0-only */
/* Preserve OEM emergency trips while replacing unavailable vendor CPU pause. */
static int UKE_INIT uke_cpu_thermal(void *fdt)
{
	static const struct { const char *zone; unsigned int cpu; } routes[] = {
		{ "cpu-0-1-0", 1 }, { "cpu-0-2-0", 2 },
		{ "cpu-1-0-0", 3 }, { "cpu-1-0-1", 3 },
		{ "cpu-1-1-0", 4 }, { "cpu-1-1-1", 4 },
		{ "cpu-1-2-0", 5 }, { "cpu-1-2-1", 5 },
		{ "cpu-1-3-0", 6 }, { "cpu-1-3-1", 6 },
		{ "cpu-2-0-0", 7 }, { "cpu-2-0-1", 7 }, { "cpu-2-0-2", 7 },
	};
	unsigned int i;

	for (i = 0; i < sizeof(routes) / sizeof(routes[0]); i++) {
		char path[112];
		int map, trip, pause, cpu, size, ret;
		unsigned int target, cpu_phandle;
		const fdt32_t *value;
		fdt32_t cooling[3];

		snprintf(path, sizeof(path), "/cpus/cpu@%x", routes[i].cpu * 0x100);
		cpu = fdt_path_offset(fdt, path);
		if (cpu < 0 || !(cpu_phandle = fdt_get_phandle(fdt, cpu)))
			return -FDT_ERR_BADVALUE;
		snprintf(path, sizeof(path), "/thermal-zones/%s/cooling-maps", routes[i].zone);
		map = fdt_first_subnode(fdt, fdt_path_offset(fdt, path));
		if (map < 0 || fdt_next_subnode(fdt, map) != -FDT_ERR_NOTFOUND)
			return -FDT_ERR_BADVALUE;
		value = fdt_getprop(fdt, map, "trip", &size);
		if (!value || size != 4)
			return -FDT_ERR_BADVALUE;
		trip = fdt_node_offset_by_phandle(fdt, fdt32_to_cpu(*value));
		value = fdt_getprop(fdt, trip, "temperature", &size);
		if (!value || size != 4 || fdt32_to_cpu(*value) != 110000)
			return -FDT_ERR_BADVALUE;
		value = fdt_getprop(fdt, trip, "hysteresis", &size);
		if (!value || size != 4 || fdt32_to_cpu(*value) != (routes[i].cpu < 3 ? 8000 : 10000))
			return -FDT_ERR_BADVALUE;
		if (fdt_stringlist_count(fdt, trip, "type") != 1 ||
		    fdt_stringlist_search(fdt, trip, "type", "passive") != 0)
			return -FDT_ERR_BADVALUE;
		value = fdt_getprop(fdt, map, "cooling-device", &size);
		if (!value || size != 12 || fdt32_to_cpu(value[1]) != 1 || fdt32_to_cpu(value[2]) != 1)
			return -FDT_ERR_BADVALUE;
		pause = fdt_node_offset_by_phandle(fdt, fdt32_to_cpu(*value));
		snprintf(path, sizeof(path), "/soc/qcom,cpu-pause/cpu%u-pause", routes[i].cpu);
		if (pause < 0 || pause != fdt_path_offset(fdt, path))
			return -FDT_ERR_BADVALUE;
		value = fdt_getprop(fdt, pause, "qcom,cpus", &size);
		if (!value || size != 4 || fdt32_to_cpu(*value) != cpu_phandle)
			return -FDT_ERR_BADVALUE;

		/* cpufreq cooling is registered once per shared policy. */
		target = routes[i].cpu < 3 ? 0 : routes[i].cpu < 7 ? 3 : 7;
		snprintf(path, sizeof(path), "/cpus/cpu@%x", target * 0x100);
		cpu = fdt_path_offset(fdt, path);
		value = fdt_getprop(fdt, cpu, "#cooling-cells", &size);
		if (!value || size != 4 || fdt32_to_cpu(*value) != 2 ||
		    !(target = fdt_get_phandle(fdt, cpu)))
			return -FDT_ERR_BADVALUE;
		cooling[0] = cpu_to_fdt32(target);
		cooling[1] = cooling[2] = cpu_to_fdt32(0xffffffffU); /* THERMAL_NO_LIMIT */
		ret = fdt_setprop(fdt, map, "cooling-device", cooling, sizeof(cooling));
		if (ret)
			return ret;
	}
	return 0;
}
