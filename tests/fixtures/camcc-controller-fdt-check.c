/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual conversion, synthetic graph and private-data placeholder only. */
#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <libfdt.h>
#define ARRAY_SIZE(x) (sizeof(x) / sizeof((x)[0]))
#define UKE_INIT
#include "uke-camcc-dt.h"
static _Alignas(8) char tree[65536], before[65536];
static const char camera_path[] = "/soc/clock-controller@ade0000";
static int camera(void) { int n = fdt_path_offset(tree, camera_path); assert(n >= 0); return n; }
static int addpath(const char *path)
{
	char component[128];
	int parent = 0;
	const char *part = path + 1;

	while (*part) {
		const char *end = strchr(part, '/');
		size_t bytes = end ? (size_t)(end - part) : strlen(part);
		assert(bytes && bytes < sizeof(component));
		memcpy(component, part, bytes); component[bytes] = 0;
		int node = fdt_subnode_offset(tree, parent, component);
		if (node == -FDT_ERR_NOTFOUND) node = fdt_add_subnode(tree, parent, component);
		assert(node >= 0); parent = node;
		if (!end) break;
		part = end + 1;
	}
	return parent;
}
static void reset(void)
{
	assert(!fdt_create_empty_tree(tree, sizeof(tree)));
	const char root[] = "xiaomi,uke\0qcom,sm7675";
	assert(!fdt_setprop(tree, 0, "compatible", root, sizeof(root)));
	int intc = addpath("/interrupt-controller");
	assert(!fdt_setprop_string(tree, intc, "compatible", "arm,gic-v3"));
	assert(!fdt_setprop_u32(tree, intc, "phandle", 31));
	assert(!fdt_setprop_u32(tree, intc, "#interrupt-cells", 3));
	assert(!fdt_setprop(tree, intc, "interrupt-controller", NULL, 0));
	assert(!fdt_setprop_u32(tree, 0, "interrupt-parent", 31));
	int soc = addpath("/soc");
	assert(!fdt_setprop_u32(tree, soc, "#address-cells", 1));
	assert(!fdt_setprop_u32(tree, soc, "#size-cells", 1));
	for (unsigned int i = 0; i < 3; i++) {
		const char *names[] = {"/clocks/rpmh", "/clocks/sleep", "/clocks/gcc"};
		int n = addpath(names[i]);
		assert(!fdt_setprop_u32(tree, n, "phandle", 11 + i));
		assert(!fdt_setprop_u32(tree, n, "#clock-cells", i == 1 ? 0 : 1));
	}
	addpath(camera_path);
	assert(!fdt_setprop_string(tree, camera(), "compatible", "qcom,cliffs-camcc"));
	assert(!fdt_setprop_u32(tree, camera(), "phandle", 21));
	assert(!fdt_setprop_u32(tree, camera(), "#clock-cells", 1));
	assert(!fdt_setprop_u32(tree, camera(), "#reset-cells", 1));
	const fdt32_t reg[] = {cpu_to_fdt32(0xade0000), cpu_to_fdt32(0x20000)};
	assert(!fdt_setprop(tree, camera(), "reg", reg, sizeof(reg)));
	const fdt32_t clocks[] = {cpu_to_fdt32(11), 0, cpu_to_fdt32(11), cpu_to_fdt32(1), cpu_to_fdt32(12), cpu_to_fdt32(13), cpu_to_fdt32(10)};
	const char names[] = "bi_tcxo\0bi_tcxo_ao\0sleep_clk\0iface";
	assert(!fdt_setprop(tree, camera(), "clocks", clocks, sizeof(clocks)));
	assert(!fdt_setprop(tree, camera(), "clock-names", names, sizeof(names)));
	for (unsigned int i = 0; i < ARRAY_SIZE(uke_camcc_legacy); i++) {
		int n = addpath(uke_camcc_legacy[i].path);
		assert(!fdt_setprop_string(tree, n, "compatible", uke_camcc_legacy[i].compatible));
	}
	int crmc = fdt_path_offset(tree, "/soc/syscon@adda000");
	const fdt32_t crmc_reg[] = {cpu_to_fdt32(0xadda000), cpu_to_fdt32(0x2000)};
	assert(!fdt_setprop(tree, crmc, "reg", crmc_reg, sizeof(crmc_reg)));
	crmc = fdt_path_offset(tree, "/soc/syscon@adda000");
	assert(!fdt_setprop_u32(tree, crmc, "phandle", 22));
	assert(!fdt_setprop_u32(tree, camera(), "qcom,cam_crm-crmc", 22));
	int crm = fdt_path_offset(tree, "/soc/crm@add7000");
	const fdt32_t crm_reg[] = {
		cpu_to_fdt32(0xadd7000), cpu_to_fdt32(0x2000),
		cpu_to_fdt32(0xadd9800), cpu_to_fdt32(0x800),
		cpu_to_fdt32(0xadda000), cpu_to_fdt32(0x2000),
		cpu_to_fdt32(0xadd9000), cpu_to_fdt32(0x800),
	};
	const char crm_names[] = "base\0crm_b\0crm_c\0crm_v";
	const fdt32_t hw[] = {0, cpu_to_fdt32(1), cpu_to_fdt32(2)};
	const fdt32_t irq[] = {0, cpu_to_fdt32(121), cpu_to_fdt32(1)};
#define CRM_SET(call) do { crm = fdt_path_offset(tree, "/soc/crm@add7000"); assert(!(call)); } while (0)
	CRM_SET(fdt_setprop(tree, crm, "reg", crm_reg, sizeof(crm_reg)));
	CRM_SET(fdt_setprop(tree, crm, "reg-names", crm_names, sizeof(crm_names)));
	CRM_SET(fdt_setprop(tree, crm, "qcom,hw-drv-ids", hw, sizeof(hw)));
	CRM_SET(fdt_setprop_u32(tree, crm, "qcom,sw-drv-ids", 0));
	CRM_SET(fdt_setprop(tree, crm, "interrupts", irq, sizeof(irq)));
#undef CRM_SET
	const fdt32_t consumer[] = {cpu_to_fdt32(21), cpu_to_fdt32(71)};
	int rsc = fdt_path_offset(tree, "/soc/rsc@add4000");
	assert(!fdt_setprop(tree, rsc, "clocks", consumer, sizeof(consumer)));
	int other = addpath("/unrelated/rtc");
	assert(!fdt_setprop_string(tree, other, "status", "okay"));
	assert(!fdt_setprop_string(tree, other, "synthetic-private-placeholder", "unchanged"));
}
static void refused(void)
{
	memcpy(before, tree, sizeof(tree));
	assert(uke_camcc_controller_graph(tree) < 0);
	assert(!memcmp(before, tree, sizeof(tree)));
}
int main(void)
{
	reset(); assert(!uke_camcc_controller_graph(tree));
	assert(!fdt_node_check_compatible(tree, camera(), "qcom,sm7675-camcc"));
	int size;
	const fdt32_t *clocks = fdt_getprop(tree, camera(), "clocks", &size);
	const unsigned int expected[] = {13, 10, 11, 0, 11, 1, 12};
	assert(clocks && size == 28);
	for (unsigned int i = 0; i < ARRAY_SIZE(expected); i++) assert(fdt32_to_cpu(clocks[i]) == expected[i]);
	const fdt32_t *reg = fdt_getprop(tree, camera(), "reg", &size);
	assert(reg && size == 24 && fdt32_to_cpu(reg[2]) == 0xadd7000 && fdt32_to_cpu(reg[3]) == 0x2000);
	assert(fdt32_to_cpu(reg[4]) == 0xadda000 && fdt32_to_cpu(reg[5]) == 0x2000);
	const fdt32_t *irq = fdt_getprop(tree, camera(), "interrupts", &size);
	assert(irq && size == 12 && !fdt32_to_cpu(irq[0]) &&
	       fdt32_to_cpu(irq[1]) == 121 && fdt32_to_cpu(irq[2]) == 1);
	assert(!strcmp(fdt_getprop(tree, camera(), "interrupt-names", NULL), "crm"));
	assert(fdt32_to_cpu(*(const fdt32_t *)fdt_getprop(tree, camera(), "interrupt-parent", NULL)) == 31);
	for (unsigned int i = 0; i < ARRAY_SIZE(uke_camcc_legacy); i++) {
		int n = fdt_path_offset(tree, uke_camcc_legacy[i].path);
		const char *status = fdt_getprop(tree, n, "status", &size);
		assert(status && size == 9 && !strcmp(status, "disabled"));
	}
	int other = fdt_path_offset(tree, "/unrelated/rtc");
	assert(!strcmp(fdt_getprop(tree, other, "status", NULL), "okay"));
	assert(!strcmp(fdt_getprop(tree, other, "synthetic-private-placeholder", NULL), "unchanged"));
	memcpy(before, tree, sizeof(tree)); assert(!uke_camcc_controller_graph(tree)); assert(!memcmp(before, tree, sizeof(tree)));
	/* Upgrade the accepted two-region native layout, without the old phandle. */
	const fdt32_t previous_reg[] = {cpu_to_fdt32(0xade0000), cpu_to_fdt32(0x20000), cpu_to_fdt32(0xadd7000), cpu_to_fdt32(0x2000)};
	const char previous_names[] = "cc_base\0crm";
	assert(!fdt_setprop(tree, camera(), "reg", previous_reg, sizeof(previous_reg)));
	assert(!fdt_setprop(tree, camera(), "reg-names", previous_names, sizeof(previous_names)));
	assert(!fdt_delprop(tree, camera(), "interrupts"));
	assert(!fdt_delprop(tree, camera(), "interrupt-names"));
	assert(!uke_camcc_controller_graph(tree));
	reg = fdt_getprop(tree, camera(), "reg", &size); assert(reg && size == 24);
	reset(); assert(!fdt_setprop_string(tree, 0, "compatible", "xiaomi,other")); refused();
	reset(); assert(!fdt_setprop_u32(tree, camera(), "reg", 0xade0004)); refused();
	reset(); assert(!fdt_setprop_u32(tree, camera(), "protected-clocks", 0)); refused();
	reset(); assert(!fdt_setprop_u32(tree, camera(), "power-domains", 11)); refused();
	reset(); assert(!fdt_setprop_u32(tree, camera(), "#clock-cells", 2)); refused();
	reset(); assert(!fdt_setprop_u32(tree, camera(), "#reset-cells", 2)); refused();
	reset(); assert(!fdt_setprop_string(tree, camera(), "clock-names", "iface")); refused();
	reset(); assert(!fdt_setprop_string(tree, fdt_path_offset(tree, uke_camcc_legacy[0].path), "compatible", "qcom,other")); refused();
	reset(); assert(!fdt_del_node(tree, fdt_path_offset(tree, uke_camcc_legacy[0].path))); refused();
	reset(); other = addpath("/unrelated/clock-consumer");
	const fdt32_t unknown[] = {cpu_to_fdt32(21), cpu_to_fdt32(71)};
	assert(!fdt_setprop(tree, other, "clocks", unknown, sizeof(unknown))); refused();
	reset(); other = addpath("/unrelated/broken-clock-tuple");
	assert(!fdt_setprop_u32(tree, other, "clocks", 11)); refused();
	reset(); assert(!fdt_setprop_u32(tree, fdt_path_offset(tree, "/soc/crm@add7000"), "qcom,sw-drv-ids", 1)); refused();
	reset(); assert(!fdt_setprop_u32(tree, fdt_path_offset(tree, "/soc/crm@add7000"), "qcom,hw-drv-ids", 0)); refused();
	reset(); assert(!fdt_setprop_u32(tree, fdt_path_offset(tree, "/soc/crm@add7000"), "reg", 0xadda000)); refused();
	reset(); assert(!fdt_setprop_u32(tree, fdt_path_offset(tree, "/soc/syscon@adda000"), "reg", 0xaddb000)); refused();
	reset(); assert(!fdt_setprop_u32(tree, camera(), "qcom,cam_crm-crmc", 21)); refused();
	reset(); assert(!fdt_setprop_u32(tree, fdt_path_offset(tree, "/soc/crm@add7000"), "interrupts", 121)); refused();
	const fdt32_t wrong_irq[] = {0, cpu_to_fdt32(122), cpu_to_fdt32(1)};
	reset(); assert(!fdt_setprop(tree, fdt_path_offset(tree, "/soc/crm@add7000"), "interrupts", wrong_irq, sizeof(wrong_irq))); refused();
	const fdt32_t wrong_edge[] = {0, cpu_to_fdt32(121), cpu_to_fdt32(4)};
	reset(); assert(!fdt_setprop(tree, fdt_path_offset(tree, "/soc/crm@add7000"), "interrupts", wrong_edge, sizeof(wrong_edge))); refused();
	reset(); assert(!fdt_setprop_u32(tree, 0, "interrupt-parent", 21)); refused();
	reset(); assert(!fdt_setprop_u32(tree, fdt_path_offset(tree, "/interrupt-controller"), "#interrupt-cells", 2)); refused();
	reset(); assert(!fdt_setprop_u32(tree, camera(), "interrupts-extended", 31)); refused();
	reset(); assert(!fdt_setprop_string(tree, camera(), "interrupt-names", "foreign")); refused();
	reset(); other = addpath("/unrelated/foreign-crmc-consumer");
	assert(!fdt_setprop_u32(tree, other, "qcom,cam_crm-crmc", 22)); refused();
	puts("Actual CAMCC FDT: exact CFG/CRMC and GIC SPI121 rising IRQ, legacy syscon containment, previous-native upgrade, unrelated data and idempotence pass; malformed/foreign/unknown graphs refuse before mutation; synthetic FDT only");
	return 0;
}
