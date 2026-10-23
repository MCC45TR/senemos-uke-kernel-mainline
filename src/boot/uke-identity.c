// SPDX-License-Identifier: GPL-2.0-only
#include <linux/bootconfig.h>
#include <linux/errno.h>
#include <linux/init.h>
#include <linux/of.h>
#include <linux/string.h>

static int __init uke_identity_init(void)
{
#ifdef CONFIG_BOOT_CONFIG
	struct xbc_node *hardware_node = NULL, *product_node = NULL;
	struct device_node *root;
	const char *hardware, *product;
	static char model[] = "POCO Pad X1";
	static struct property property = {
		.name = "model", .length = sizeof(model), .value = model,
	};
	int ret;

	if (!of_machine_is_compatible("xiaomi,uke") ||
	    !of_machine_is_compatible("qcom,sm7675"))
		return 0;
	hardware = xbc_find_value("androidboot.hardware.sku", &hardware_node);
	product = xbc_find_value("androidboot.product.hardware.sku", &product_node);
	/* Accept only the exact scalar SKU observed in stock and Fedora boot data. */
	if ((!hardware && !product) ||
	    (hardware && (!hardware_node || xbc_node_is_array(hardware_node) ||
			 strcmp(hardware, "ukepgl"))) ||
	    (product && (!product_node || xbc_node_is_array(product_node) ||
			strcmp(product, "ukepgl"))))
		return 0;
	root = of_find_node_by_path("/");
	if (!root)
		return -ENODEV;
	/* OF retains the property, so neither it nor its value may be init data. */
	ret = of_update_property(root, &property);
	of_node_put(root);
	return ret;
#else
	return 0;
#endif
}
/* XBC exists until all initcalls finish; update OF before userspace starts. */
arch_initcall(uke_identity_init);
