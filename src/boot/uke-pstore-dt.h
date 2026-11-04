/* SPDX-License-Identifier: MIT
 * Uke's admitted OEM 4 MiB reservation; never changes its address or extent.
 * Called only inside the exact-board ABL transform, on its private FDT copy.
 */
#ifndef UKE_PSTORE_DT_H
#define UKE_PSTORE_DT_H
static int UKE_INIT uke_pstore_u32(const void *fdt, int node,
				 const char *name, unsigned int wanted)
{
	int length;
	const fdt32_t *value = fdt_getprop(fdt, node, name, &length);
	return value && length == 4 && fdt32_to_cpu(*value) == wanted;
}

static int UKE_INIT uke_pstore_graph(void *fdt)
{
	const char *path = "/reserved-memory/ramoops_region";
	const fdt32_t *reg;
	int node, length, ret, converted;

	node = fdt_path_offset(fdt, path);
	if (node < 0 || fdt_node_check_compatible(fdt, node, "ramoops"))
		return -FDT_ERR_BADVALUE;
	reg = fdt_getprop(fdt, node, "reg", &length);
	if (!reg || length != 16 || fdt32_to_cpu(reg[0]) ||
	    fdt32_to_cpu(reg[1]) != 0xa7000000 || fdt32_to_cpu(reg[2]) ||
	    fdt32_to_cpu(reg[3]) != 0x400000 ||
	    !uke_pstore_u32(fdt, node, "mem-type", 2) ||
	    !uke_pstore_u32(fdt, node, "console-size", 0x200000) ||
	    fdt_getprop(fdt, node, "ftrace-size", NULL) ||
	    fdt_getprop(fdt, node, "ecc-size", NULL) ||
	    fdt_getprop(fdt, node, "status", NULL))
		return -FDT_ERR_BADVALUE;
	converted = uke_pstore_u32(fdt, node, "record-size", 0x100000) &&
		uke_pstore_u32(fdt, node, "pmsg-size", 0x100000) &&
		uke_pstore_u32(fdt, node, "max-reason", 2);
	if (converted)
		return 0;
	if (fdt_getprop(fdt, node, "record-size", NULL) ||
	    fdt_getprop(fdt, node, "max-reason", NULL) ||
	    !uke_pstore_u32(fdt, node, "pmsg-size", 0x200000))
		return -FDT_ERR_BADVALUE;
	/* Keep 2 MiB console, reserve 1 MiB panic/oops and 1 MiB pmsg. */
	ret = fdt_setprop_u32(fdt, node, "record-size", 0x100000);
	if (ret)
		return ret;
	ret = fdt_setprop_u32(fdt, node, "max-reason", 2);
	if (ret)
		return ret;
	return fdt_setprop_u32(fdt, node, "pmsg-size", 0x100000);
}
#endif
