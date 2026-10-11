// SPDX-License-Identifier: GPL-2.0-only
/*
 * Stock-ABL development path for Uke. Keep the bootloader's selected FDT,
 * RAM, reservations, selectors and unit data. Apply only the reviewed UFS
 * and USB provider overlays before OF scans or creates platform devices.
 * The display geometry is cross-checked against Uke's OEM O82 panel and
 * the owner's DRM mode inventory. The splash address comes from this boot.
 * This is a simplefb handoff candidate, not a panel or power-management port.
 */
#ifdef __KERNEL__
#include <linux/cache.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/libfdt.h>
#include <linux/sizes.h>
#include <asm/memory.h>
#include <asm/processor.h>
#define UKE_INIT __init
void *__init uke_abl_prepare_fdt(void *input, int size, phys_addr_t *physical);
#else
#include <libfdt.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define UKE_INIT
#endif

#define UKE_FDT_CAPACITY (2 * 1024 * 1024)
#define UKE_FB_WIDTH 3200
#define UKE_FB_HEIGHT 2136
#define UKE_FB_STRIDE (UKE_FB_WIDTH * 4)
#define UKE_FB_BYTES (UKE_FB_STRIDE * UKE_FB_HEIGHT)

static int UKE_INIT uke_path_reg(const void *fdt, const char *path,
				unsigned int address, unsigned int bytes)
{
	int node = fdt_path_offset(fdt, path), length;
	const fdt32_t *reg;

	if (node < 0)
		return -FDT_ERR_NOTFOUND;
	reg = fdt_getprop(fdt, node, "reg", &length);
	if (!reg || length < 8 || fdt32_to_cpu(reg[0]) != address ||
	    fdt32_to_cpu(reg[1]) != bytes)
		return -FDT_ERR_BADVALUE;
	return 0;
}

static int UKE_INIT uke_delete_optional(void *fdt, const char *path,
				      const char *property)
{
	int node = fdt_path_offset(fdt, path), ret;

	if (node < 0)
		return node;
	ret = fdt_delprop(fdt, node, property);
	return ret == -FDT_ERR_NOTFOUND ? 0 : ret;
}

static int UKE_INIT uke_reboot_cell(const void *fdt)
{
	int node = fdt_path_offset(fdt, "/soc/reboot_reason"), size, parent;
	int cell = fdt_path_offset(fdt, "/soc/qcom,spmi@c42d000/"
				  "qcom,pmk8550@0/sdam@7100/restart@48");
	const fdt32_t *value;

	if (node < 0 || cell < 0 ||
	    fdt_node_check_compatible(fdt, node, "qcom,reboot-reason"))
		return -FDT_ERR_BADVALUE;
	value = fdt_getprop(fdt, node, "nvmem-cells", &size);
	if (!value || size != 4 ||
	    fdt_node_offset_by_phandle(fdt, fdt32_to_cpu(*value)) != cell ||
	    uke_path_reg(fdt, "/soc/qcom,spmi@c42d000/"
			 "qcom,pmk8550@0/sdam@7100/restart@48", 0x48, 1))
		return -FDT_ERR_BADVALUE;
	value = fdt_getprop(fdt, cell, "bits", &size);
	if (!value || size != 8 || fdt32_to_cpu(value[0]) != 1 ||
	    fdt32_to_cpu(value[1]) != 7)
		return -FDT_ERR_BADVALUE;
	parent = fdt_parent_offset(fdt, cell);
	value = fdt_getprop(fdt, parent, "reg", &size);
	if (!value || size != 4 || fdt32_to_cpu(*value) != 0x7100 ||
	    fdt_node_check_compatible(fdt, parent, "qcom,spmi-sdam"))
		return -FDT_ERR_BADVALUE;
	return 0;
}

static int UKE_INIT uke_legacy_layout(const void *fdt)
{
	static const struct {
		const char *path, *property;
		unsigned int count, values[6];
	} expected[] = {
		{ "/soc", "#address-cells", 1, { 1 } },
		{ "/soc", "#size-cells", 1, { 1 } },
		{ "/soc/mmio-sram@17D09400", "#address-cells", 1, { 2 } },
		{ "/soc/mmio-sram@17D09400", "#size-cells", 1, { 2 } },
		{ "/soc/mmio-sram@17D09400", "reg", 4, { 0, 0x17d09400, 0, 0x400 } },
		{ "/soc/mmio-sram@17D09400", "ranges", 6, { 0, 0, 0, 0x17d09400, 0, 0x400 } },
		{ "/soc/mmio-sram@17D09400/scmi-shmem@0", "reg", 4, { 0, 0x17d09400, 0, 0x400 } },
		{ "/soc/qcom,spmi@c42d000/qcom,pmk8550@0/sdam@7000", "reg", 1, { 0x7000 } },
		{ "/soc/qcom,spmi@c42d000/qcom,pmk8550@0/sdam@7000/smb1510_present@5d", "reg", 2, { 0x5d, 1 } },
		{ "/soc/qcom,spmi@c42d000/qcom,pmk8550@0/sdam@7000/smb1510_present@5d", "bits", 2, { 5, 5 } },
		{ "/soc/qcom,spmi@c42d000/qcom,pmk8550@0/sdam@7000/ufs_dev@ad", "reg", 2, { 0xaf, 1 } },
		{ "/soc/qcom,spmi@c42d000/qcom,pmk8550@0/sdam@7000/ufs_dev@ad", "bits", 2, { 0, 0 } },
	};
	unsigned int i, j;
	int node, size;
	const fdt32_t *value;

	for (i = 0; i < sizeof(expected) / sizeof(expected[0]); i++) {
		node = fdt_path_offset(fdt, expected[i].path);
		if (node < 0)
			return node;
		value = fdt_getprop(fdt, node, expected[i].property, &size);
		if (!value || size != (int)(expected[i].count * sizeof(*value)))
			return -FDT_ERR_BADVALUE;
		for (j = 0; j < expected[i].count; j++)
			if (fdt32_to_cpu(value[j]) != expected[i].values[j])
				return -FDT_ERR_BADVALUE;
	}
	if (fdt_node_check_compatible(fdt, fdt_path_offset(fdt, "/soc/mmio-sram@17D09400"), "mmio-sram") ||
	    fdt_node_check_compatible(fdt, fdt_path_offset(fdt, "/soc/mmio-sram@17D09400/scmi-shmem@0"), "arm,scmi-shmem") ||
	    fdt_node_check_compatible(fdt, fdt_path_offset(fdt, "/soc/qcom,spmi@c42d000/qcom,pmk8550@0/sdam@7000"), "qcom,spmi-sdam"))
		return -FDT_ERR_BADVALUE;
	return 0;
}

static int UKE_INIT uke_scope_smmu_clients(void *fdt)
{
	static const char * const paths[] = {
		"/soc/ufshc@1d84000", "/soc/ssusb@a600000",
		"/soc/qcom,gpi-dma@a00000",
		"/soc/qcom,qupv3_0_geni_se@ac0000",
		"/soc/qcom,qupv3_1_geni_se@8c0000",
		"/soc/qcom,gpi-dma@800000",
		"/soc/qcom,wcn6750",
	};
	static const unsigned int sids[] = { 0x60, 0x40, 0xb6, 0xa3, 0x423, 0x436, 0x1400 };
	static const unsigned int masks[] = { 0, 0, 0, 0, 0, 0, 1 };
	int smmu = fdt_path_offset(fdt, "/soc/apps-smmu@15000000");
	unsigned int phandle;
	int node, size, ret;
	unsigned int i;

	if (smmu < 0 || !(phandle = fdt_get_phandle(fdt, smmu)))
		return -FDT_ERR_BADPHANDLE;
	for (i = 0; i < sizeof(paths) / sizeof(paths[0]); i++) {
		const fdt32_t *spec;

		node = fdt_path_offset(fdt, paths[i]);
		if (node < 0)
			return node;
		spec = fdt_getprop(fdt, node, "iommus", &size);
		if (!spec || size != 12 || fdt32_to_cpu(spec[0]) != phandle ||
		    fdt32_to_cpu(spec[1]) != sids[i] || fdt32_to_cpu(spec[2]) != masks[i])
			return -FDT_ERR_BADVALUE;
	}
	for (node = fdt_next_node(fdt, -1, NULL); node >= 0;
	     node = fdt_next_node(fdt, node, NULL)) {
		const fdt32_t *spec = fdt_getprop(fdt, node, "iommus", &size);
		int pos = 0, total, scoped = 0, admitted = 0;

		if (!spec)
			continue;
		if (size <= 0 || size % sizeof(*spec))
			return -FDT_ERR_BADVALUE;
		total = size / (int)sizeof(*spec);
		while (pos < total) {
			const fdt32_t *cells;
			unsigned int count, provider = fdt32_to_cpu(spec[pos++]);
			int length, offset = fdt_node_offset_by_phandle(fdt, provider);

			if (offset < 0)
				return offset;
			cells = fdt_getprop(fdt, offset, "#iommu-cells", &length);
			if (!cells || length != 4)
				return -FDT_ERR_BADVALUE;
			count = fdt32_to_cpu(*cells);
			if (count > (unsigned int)(total - pos))
				return -FDT_ERR_BADVALUE;
			if (provider == phandle)
				scoped = 1;
			pos += count;
		}
		if (!scoped)
			continue;
		for (i = 0; i < sizeof(paths) / sizeof(paths[0]); i++)
			if (node == fdt_path_offset(fdt, paths[i]))
				admitted = 1;
		/* Disabled clients cannot reclaim firmware display streams or DMA
		 * through this provider outside its seven reviewed consumers.
		 */
		if (!admitted) {
			ret = fdt_setprop_string(fdt, node, "status", "disabled");
			if (ret)
				return ret;
		}
	}
	return node == -FDT_ERR_NOTFOUND ? 0 : node;
}

static int UKE_INIT uke_backlight_bus(const void *fdt)
{
	const char *bus = "/soc/qcom,qupv3_1_geni_se@8c0000/i2c@890000";
	int node = fdt_path_offset(fdt, bus), size, i;
	int dma = fdt_path_offset(fdt, "/soc/qcom,gpi-dma@800000");
	int ktz = fdt_path_offset(fdt, "/soc/qcom,qupv3_1_geni_se@8c0000/i2c@890000/ktz8866@11");
	const fdt32_t *value;
	unsigned int phandle;
	static const unsigned int route[] = { 0, 4, 3, 64, 0, 1, 4, 3, 64, 0 };
	static const char * const dma_props[] = {
		"#dma-cells", "qcom,max-num-gpii", "qcom,gpii-mask", "qcom,gpi-ee-offset",
	};
	static const unsigned int dma_values[] = { 5, 12, 0x1e, 0x10000 };

	if (node < 0 || dma < 0 || ktz < 0 || !(phandle = fdt_get_phandle(fdt, dma)) ||
	    fdt_node_check_compatible(fdt, node, "qcom,i2c-geni") ||
	    fdt_node_check_compatible(fdt, dma, "qcom,gpi-dma") ||
	    fdt_node_check_compatible(fdt, ktz, "ktz,ktz8866") ||
	    uke_path_reg(fdt, bus, 0x890000, 0x4000) ||
	    uke_path_reg(fdt, "/soc/qcom,qupv3_1_geni_se@8c0000", 0x8c0000, 0x2000) ||
	    uke_path_reg(fdt, "/soc/qcom,gpi-dma@800000", 0x800000, 0x60000))
		return -FDT_ERR_BADVALUE;
	value = fdt_getprop(fdt, ktz, "reg", &size);
	if (!value || size != 4 || fdt32_to_cpu(*value) != 0x11)
		return -FDT_ERR_BADVALUE;
	ktz = fdt_path_offset(fdt, "/soc/qcom,qupv3_0_geni_se@ac0000/i2c@a80000/ktz8866@11");
	if (ktz < 0 || fdt_node_check_compatible(fdt, ktz, "ktz,ktz8866"))
		return -FDT_ERR_BADVALUE;
	value = fdt_getprop(fdt, ktz, "reg", &size);
	if (!value || size != 4 || fdt32_to_cpu(*value) != 0x11)
		return -FDT_ERR_BADVALUE;
	for (i = 0; i < 4; i++) {
		value = fdt_getprop(fdt, dma, dma_props[i], &size);
		if (!value || size != 4 || fdt32_to_cpu(*value) != dma_values[i])
			return -FDT_ERR_BADVALUE;
	}
	value = fdt_getprop(fdt, node, "dmas", &size);
	if (!value || size != (int)(12 * sizeof(*value)))
		return -FDT_ERR_BADVALUE;
	for (i = 0; i < 2; i++) {
		int j;
		if (fdt32_to_cpu(value[i * 6]) != phandle)
			return -FDT_ERR_BADVALUE;
		for (j = 0; j < 5; j++)
			if (fdt32_to_cpu(value[i * 6 + j + 1]) != route[i * 5 + j])
				return -FDT_ERR_BADVALUE;
	}
	value = fdt_getprop(fdt, node, "qcom,clk-freq-out", &size);
	if (!value || size != 4 || fdt32_to_cpu(*value) != 400000)
		return -FDT_ERR_BADVALUE;
	return 0;
}

static int UKE_INIT uke_scope_second_qup(void *fdt)
{
	static const char * const parents[] = {
		"/soc/qcom,qupv3_1_geni_se@8c0000",
		"/soc/qcom,qupv3_1_geni_se@8c0000/i2c@890000",
	};
	static const char * const admitted[] = { "i2c@890000", "ktz8866@11" };
	int i, parent, child, ret;

	for (i = 0; i < 2; i++) {
		parent = fdt_path_offset(fdt, parents[i]);
		if (parent < 0)
			return parent;
		fdt_for_each_subnode(child, fdt, parent) {
			if (!strcmp(fdt_get_name(fdt, child, NULL), admitted[i]))
				continue;
			ret = fdt_setprop_string(fdt, child, "status", "disabled");
			if (ret)
				return ret;
		}
		if (child != -FDT_ERR_NOTFOUND)
			return child;
	}
	return 0;
}

static int UKE_INIT uke_pair_backlights(void *fdt)
{
	const char *secondary = "/soc/qcom,qupv3_1_geni_se@8c0000/i2c@890000/ktz8866@11";
	const char *primary = "/soc/qcom,qupv3_0_geni_se@ac0000/i2c@a80000/ktz8866@11";
	int node = fdt_path_offset(fdt, secondary), ret;
	unsigned int phandle;

	if (node < 0)
		return node;
	phandle = fdt_get_phandle(fdt, node);
	if (!phandle) {
		ret = fdt_generate_phandle(fdt, &phandle);
		if (ret)
			return ret;
		ret = fdt_setprop_u32(fdt, node, "phandle", phandle);
		if (ret)
			return ret;
	}
	ret = fdt_setprop_string(fdt, node, "compatible", "xiaomi,uke-ktz8866-secondary");
	if (ret)
		return ret;
	node = fdt_path_offset(fdt, primary);
	if (node < 0)
		return node;
	ret = fdt_setprop_string(fdt, node, "compatible", "xiaomi,uke-ktz8866-primary");
	if (ret)
		return ret;
	return fdt_setprop_u32(fdt, node, "xiaomi,secondary", phandle);
}

static int UKE_INIT uke_wifi_graph(const void *fdt)
{
	static const char * const supplies[] = { "vdd-cx-mx-supply", "vdd-1.8-xo-supply", "vdd-1.3-rfa-supply" };
	static const char * const resources[] = { "smpb3", "smpb1", "smpb2" };
	static const unsigned int initial_uv[] = { 984000, 1856000, 1256000 };
	int wifi = fdt_path_offset(fdt, "/soc/qcom,wcn6750");
	int wpss = fdt_path_offset(fdt, "/soc/remoteproc-wpss@9bb00000");
	int msa = fdt_path_offset(fdt, "/reserved-memory/wlan_msa_region@a6400000");
	const fdt32_t *cells;
	int size, i, target, parent;

	if (wifi < 0 || wpss < 0 || msa < 0 ||
	    fdt_node_check_compatible(fdt, wifi, "qcom,wcn6750") ||
	    fdt_node_check_compatible(fdt, wpss, "qcom,cliffs-wpss-pas") ||
	    uke_path_reg(fdt, "/soc/remoteproc-wpss@9bb00000", 0x9bb00000, 0x10000))
		return -FDT_ERR_BADVALUE;
	cells = fdt_getprop(fdt, wifi, "qcom,rproc-handle", &size);
	if (!cells || size != 4 || fdt_node_offset_by_phandle(fdt, fdt32_to_cpu(*cells)) != wpss)
		return -FDT_ERR_BADPHANDLE;
	cells = fdt_getprop(fdt, wifi, "qcom,wlan-msa-fixed-region", &size);
	if (!cells || size != 4 || fdt_node_offset_by_phandle(fdt, fdt32_to_cpu(*cells)) != msa)
		return -FDT_ERR_BADPHANDLE;
	cells = fdt_getprop(fdt, msa, "reg", &size);
	if (!cells || size != 16 || fdt32_to_cpu(cells[0]) ||
	    fdt32_to_cpu(cells[1]) != 0xa6400000 || fdt32_to_cpu(cells[2]) ||
	    fdt32_to_cpu(cells[3]) != 0xc00000 || !fdt_getprop(fdt, msa, "no-map", NULL))
		return -FDT_ERR_BADVALUE;
	cells = fdt_getprop(fdt, wifi, "reg", &size);
	if (!cells || size != 16 || fdt32_to_cpu(cells[0]) != 0x17110040 ||
	    fdt32_to_cpu(cells[1]) || fdt32_to_cpu(cells[2]) != 0xc0000000 ||
	    fdt32_to_cpu(cells[3]) != 0x10000)
		return -FDT_ERR_BADVALUE;
	cells = fdt_getprop(fdt, wifi, "interrupts", &size);
	if (!cells || size != 32 * 3 * 4)
		return -FDT_ERR_BADVALUE;
	for (i = 0; i < 32; i++)
		if (fdt32_to_cpu(cells[i * 3]) || fdt32_to_cpu(cells[i * 3 + 1]) != 768U + (unsigned int)i ||
		    fdt32_to_cpu(cells[i * 3 + 2]) != 1)
			return -FDT_ERR_BADVALUE;
	for (i = 0; i < 3; i++) {
		const char *resource;

		cells = fdt_getprop(fdt, wifi, supplies[i], &size);
		if (!cells || size != 4)
			return -FDT_ERR_BADPHANDLE;
		target = fdt_node_offset_by_phandle(fdt, fdt32_to_cpu(*cells));
		parent = fdt_parent_offset(fdt, target);
		resource = fdt_getprop(fdt, parent, "qcom,resource-name", &size);
		if (!resource || size != (int)strlen(resources[i]) + 1 ||
		    strcmp(resource, resources[i]))
			return -FDT_ERR_BADVALUE;
		cells = fdt_getprop(fdt, target, "qcom,init-voltage", &size);
		if (!cells || size != 4 || fdt32_to_cpu(*cells) != initial_uv[i])
			return -FDT_ERR_BADVALUE;
	}
	return 0;
}

static int UKE_INIT uke_framebuffer(void *fdt)
{
	const fdt32_t *reg;
	fdt32_t framebuffer_reg[4];
	uint64_t address, length;
	char name[48], path[64];
	int splash, chosen, node, size, ret;

	splash = fdt_path_offset(fdt, "/reserved-memory/splash_region");
	if (splash < 0)
		return splash;
	reg = fdt_getprop(fdt, splash, "reg", &size);
	if (!reg || size != 16)
		return -FDT_ERR_BADVALUE;
	address = ((uint64_t)fdt32_to_cpu(reg[0]) << 32) | fdt32_to_cpu(reg[1]);
	length = ((uint64_t)fdt32_to_cpu(reg[2]) << 32) | fdt32_to_cpu(reg[3]);
	if (!address || (address & 4095) || length < UKE_FB_BYTES ||
	    length > 128 * 1024 * 1024 || address + length < address ||
	    fdt_getprop(fdt, splash, "reusable", NULL))
		return -FDT_ERR_BADVALUE;
	memcpy(framebuffer_reg, reg, 16);
	framebuffer_reg[2] = cpu_to_fdt32(0);
	framebuffer_reg[3] = cpu_to_fdt32(UKE_FB_BYTES);
	ret = fdt_setprop(fdt, splash, "no-map", NULL, 0);
	if (ret)
		return ret;
	chosen = fdt_path_offset(fdt, "/chosen");
	if (chosen < 0)
		return chosen;
	ret = fdt_setprop_u32(fdt, chosen, "#address-cells", 2);
	if (ret)
		return ret;
	ret = fdt_setprop_u32(fdt, chosen, "#size-cells", 2);
	if (ret)
		return ret;
	ret = fdt_setprop(fdt, chosen, "ranges", NULL, 0);
	if (ret)
		return ret;
	snprintf(name, sizeof(name), "framebuffer@%llx", (unsigned long long)address);
	node = fdt_subnode_offset(fdt, chosen, name);
	if (node == -FDT_ERR_NOTFOUND)
		node = fdt_add_subnode(fdt, chosen, name);
	if (node < 0)
		return node;
#define UKE_FB_SET(call) do { ret = (call); if (ret) return ret; } while (0)
	UKE_FB_SET(fdt_setprop_string(fdt, node, "compatible", "simple-framebuffer"));
	UKE_FB_SET(fdt_setprop(fdt, node, "reg", framebuffer_reg, sizeof(framebuffer_reg)));
	UKE_FB_SET(fdt_setprop_u32(fdt, node, "width", UKE_FB_WIDTH));
	UKE_FB_SET(fdt_setprop_u32(fdt, node, "height", UKE_FB_HEIGHT));
	UKE_FB_SET(fdt_setprop_u32(fdt, node, "stride", UKE_FB_STRIDE));
	UKE_FB_SET(fdt_setprop_string(fdt, node, "format", "a8r8g8b8"));
	UKE_FB_SET(fdt_setprop_string(fdt, node, "status", "okay"));
	snprintf(path, sizeof(path), "/chosen/%s", name);
	chosen = fdt_path_offset(fdt, "/chosen");
	UKE_FB_SET(fdt_setprop_string(fdt, chosen, "stdout-path", path));
#undef UKE_FB_SET
	return 0;
}

/* 0: foreign DT left untouched; 1: admitted graph; negative: reject Uke boot.
 * Overlay buffers are private writable copies: libfdt consumes them. Never
 * write to the incoming bootloader FDT, including on partial overlay failure.
 */
#ifdef __KERNEL__
static
#endif
int UKE_INIT uke_abl_transform(void *output, size_t capacity,
			      const void *input, size_t input_bytes,
			      void *ufs_overlay, size_t ufs_bytes,
			      void *usb_overlay, size_t usb_bytes)
{
	static const char model[] = "Qualcomm Technologies, Inc. Uke based on SM8635";
	const char *value;
	const fdt32_t *board;
	int size, ret;

	if (!input || input_bytes < sizeof(struct fdt_header) || input_bytes > UKE_FDT_CAPACITY ||
	    fdt_check_full(input, input_bytes))
		return -FDT_ERR_BADSTRUCTURE;
	value = fdt_getprop(input, 0, "model", &size);
	if (!value || size != (int)sizeof(model) || memcmp(value, model, sizeof(model)))
		return 0;
	board = fdt_getprop(input, 0, "qcom,board-id", &size);
	if (!board || size != 8 || fdt32_to_cpu(board[0]) != 8 ||
	    fdt32_to_cpu(board[1]) != 0 ||
	    fdt_node_check_compatible(input, 0, "qcom,cliffs-mtp") ||
	    capacity > UKE_FDT_CAPACITY || capacity <= input_bytes ||
	    uke_path_reg(input, "/soc/ufshc@1d84000", 0x1d84000, 0x3000) ||
	    uke_path_reg(input, "/soc/ufsphy_mem@1d80000", 0x1d80000, 0x2000) ||
	    uke_reboot_cell(input) || uke_wifi_graph(input) || uke_legacy_layout(input) ||
	    uke_backlight_bus(input) ||
	    !ufs_overlay || !usb_overlay ||
	    ufs_bytes < sizeof(struct fdt_header) || usb_bytes < sizeof(struct fdt_header) ||
	    fdt_check_full(ufs_overlay, ufs_bytes) ||
	    fdt_check_full(usb_overlay, usb_bytes))
		return -FDT_ERR_BADVALUE;
	ret = fdt_open_into(input, output, capacity);
	if (ret)
		return ret;
	ret = fdt_overlay_apply(output, ufs_overlay);
	if (ret)
		return ret;
	ret = fdt_overlay_apply(output, usb_overlay);
	if (ret)
		return ret;
	/* OEM zero-width bits means the whole byte; upstream rejects bits=<0 0>. */
	ret = uke_delete_optional(output, "/soc/qcom,spmi@c42d000/qcom,pmk8550@0/sdam@7000/ufs_dev@ad", "bits");
	if (ret)
		return ret;
	ret = uke_delete_optional(output, "/soc/ufshc@1d84000", "msi-parent");
	if (ret)
		return ret;
	ret = uke_delete_optional(output, "/soc/ufshc@1d84000", "shared-ice-cfg");
	if (ret)
		return ret;
	ret = uke_delete_optional(output, "/soc/ssusb@a600000", "interrupts-extended");
	if (ret)
		return ret;
	ret = uke_delete_optional(output, "/soc/ssusb@a600000", "extcon");
	if (ret)
		return ret;
	ret = uke_delete_optional(output, "/soc/ssusb@a600000", "usb-role-switch");
	if (ret)
		return ret;
	ret = uke_scope_second_qup(output);
	if (ret)
		return ret;
	ret = uke_pair_backlights(output);
	if (ret)
		return ret;
	ret = uke_scope_smmu_clients(output);
	if (ret)
		return ret;
	ret = uke_framebuffer(output);
	if (ret)
		return ret;
	ret = fdt_pack(output);
	return ret ? ret : 1;
}

#ifdef __KERNEL__
/* Persistent kernel-owned storage: OF and /sys/firmware/fdt retain pointers
 * after free_initmem(). The original bootloader allocation stays reserved.
 */
static unsigned char uke_fdt[UKE_FDT_CAPACITY] __ro_after_init __aligned(8);
#include "uke-abl-overlays.h"

void *__init uke_abl_prepare_fdt(void *input, int size, phys_addr_t *physical)
{
	int ret;

	if (!input || size <= 0)
		return input;
	ret = uke_abl_transform(uke_fdt, sizeof(uke_fdt), input, size,
			      uke_ufs_overlay, sizeof(uke_ufs_overlay),
			      uke_usb_overlay, sizeof(uke_usb_overlay));
	if (ret < 0) {
		pr_crit("Uke ABL DT adaptation rejected (%d); refusing incomplete board graph\n", ret);
		while (true)
			cpu_relax();
	}
	if (!ret)
		return input;
	*physical = __pa_symbol(uke_fdt);
	pr_info("Uke ABL DT: selected RAM preserved; UFS, USB peripheral and simplefb prepared\n");
	return uke_fdt;
}
#endif
