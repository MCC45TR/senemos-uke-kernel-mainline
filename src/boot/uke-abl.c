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
