// SPDX-License-Identifier: GPL-2.0-only

#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <libfdt.h>

#define UKE_INIT
#include "uke-rtc.h"

#define COUNTER_ONLY "qcom,rtc-counter-only"

static _Alignas(8) char tree[4096];
static char before[sizeof(tree)];
static const char rtc_path[] =
	"/soc/qcom,spmi@c42d000/qcom,pmk8550@0/rtc@6100";

static int rtc_node(void)
{
	int node = fdt_path_offset(tree, rtc_path);

	assert(node >= 0);
	return node;
}

static void reset_tree(void)
{
	const char compatible[] = "xiaomi,uke\0qcom,sm7675";
	const fdt32_t reg[] = { cpu_to_fdt32(0x6100), cpu_to_fdt32(0x6200) };
	int soc, bus, pmic, rtc;

	memset(tree, 0, sizeof(tree));
	assert(!fdt_create_empty_tree(tree, sizeof(tree)));
	assert(!fdt_setprop(tree, 0, "compatible", compatible,
			    sizeof(compatible)));
	soc = fdt_add_subnode(tree, 0, "soc");
	assert(soc >= 0);
	bus = fdt_add_subnode(tree, soc, "qcom,spmi@c42d000");
	assert(bus >= 0);
	pmic = fdt_add_subnode(tree, bus, "qcom,pmk8550@0");
	assert(pmic >= 0);
	rtc = fdt_add_subnode(tree, pmic, "rtc@6100");
	assert(rtc >= 0);
	assert(!fdt_setprop_string(tree, rtc, "compatible", "qcom,pmk8350-rtc"));
	assert(!fdt_setprop(tree, rtc_node(), "reg", reg, sizeof(reg)));
}

static void check_rejected(void)
{
	memcpy(before, tree, sizeof(tree));
	assert(uke_rtc_counter_only(tree) == -FDT_ERR_BADVALUE);
	assert(!memcmp(tree, before, sizeof(tree)));
}

int main(void)
{
	const char *const calendar[] = {
		"allow-set-time", "nvmem-cells", "nvmem-cell-names",
		"qcom,uefi-rtc-info", "start-year",
	};
	int size;

	reset_tree();
	assert(!uke_rtc_counter_only(tree));
	assert(fdt_getprop(tree, rtc_node(), COUNTER_ONLY, &size) && !size);
	memcpy(before, tree, sizeof(tree));
	assert(!uke_rtc_counter_only(tree));
	assert(!memcmp(tree, before, sizeof(tree)));

	reset_tree();
	assert(!fdt_pack(tree));
	memcpy(before, tree, fdt_totalsize(tree));
	assert(uke_rtc_counter_only(tree) == -FDT_ERR_NOSPACE);
	assert(!memcmp(tree, before, fdt_totalsize(tree)));

	for (size_t i = 0; i < sizeof(calendar) / sizeof(calendar[0]); ++i) {
		reset_tree();
		assert(!fdt_setprop_empty(tree, rtc_node(), calendar[i]));
		check_rejected();
	}

	reset_tree();
	assert(!fdt_setprop_u32(tree, rtc_node(), COUNTER_ONLY, 1));
	check_rejected();
	reset_tree();
	assert(!fdt_setprop_u32(tree, rtc_node(), "reg", 0x6100));
	check_rejected();
	reset_tree();
	assert(!fdt_setprop_string(tree, rtc_node(), "compatible",
				   "qcom,pm8941-rtc"));
	check_rejected();
	reset_tree();
	assert(!fdt_setprop_string(tree, 0, "compatible", "xiaomi,other"));
	check_rejected();

	puts("Uke RTC DT counter-only admission and refusal cases passed.");
}
