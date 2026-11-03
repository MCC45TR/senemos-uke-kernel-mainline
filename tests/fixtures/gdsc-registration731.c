// SPDX-License-Identifier: GPL-2.0-only
/* Derived from the inactive 23 October camera fault fixture.
 * The complete Linux 7.3.1 GDSC functions and layout are imported.
 * These boundaries model registration ownership, not electrical power.
 */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CONFIG_QCOM_GDSC 1
#define BIT(n) (1UL << (n))
#define GENMASK_ULL(h, l) (((~0ULL) << (l)) & (~0ULL >> (63 - (h))))
#define container_of(p, t, m) ((t *)((char *)(p) - offsetof(t, m)))
#define WARN(condition, ...) ((void)(condition))
#define GENPD_FLAG_ALWAYS_ON BIT(0)
#define GENPD_FLAG_IRQ_SAFE BIT(1)
#define GFP_KERNEL 0
#define IS_ERR(p) ((uintptr_t)(p) >= (uintptr_t)-4095)
#define IS_ERR_OR_NULL(p) (!(p) || IS_ERR(p))
#define PTR_ERR(p) ((intptr_t)(p))
#define ERR_PTR(e) ((void *)(intptr_t)(e))
#define EXPORT_SYMBOL_GPL(name)
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef unsigned long long ktime_t;

struct device;
struct dev_pm_domain { int unused; };
struct dev_pm_ops {
	int (*runtime_resume)(struct device *);
	int (*runtime_suspend)(struct device *);
};
struct device_driver {
	void *owner;
	bool suppress_bind_attrs;
	const struct dev_pm_ops *pm;
};
struct device {
	const struct device_driver *driver;
	bool enabled, active, guard;
	int references, get_error, gets, puts;
	struct dev_pm_domain *pm_domain;
	void *of_node;
};
struct generic_pm_domain {
	struct dev_pm_domain domain;
	const char *name;
	unsigned int flags;
	bool synced_poweroff;
	int (*power_on)(struct generic_pm_domain *);
	int (*power_off)(struct generic_pm_domain *);
	int (*set_hwmode_dev)(struct generic_pm_domain *, struct device *, bool);
	bool (*get_hwmode_dev)(struct generic_pm_domain *, struct device *);
	bool initialized;
	int parents, children;
};
struct dev_pm_domain_list { int num_pds; struct device **pd_devs; };
struct genpd_onecell_data { size_t num_domains; struct generic_pm_domain **domains; };
struct reset_controller_dev;
struct reset_ops {
	int (*assert)(struct reset_controller_dev *, unsigned int);
	int (*deassert)(struct reset_controller_dev *, unsigned int);
};
struct reset_controller_dev { const struct reset_ops *ops; };
struct regulator { int enables, disables, enable_error, disable_error; };
struct icc_path { int unused; };
struct regmap {
	struct device *dev;
	u32 value, status;
	int reads, writes, fail_write, read_error;
	bool stuck;
};
#include "gdsc-header.h"

static int icc_error, icc_calls, init_error, init_calls;
static bool registration_test, published;
static int registered, removed, linked, init_fail_at, link_fail_at, provider_error;
static int registration_inits, registration_links, allocation_fail_at, allocations;
static void *allocated[2];
static ktime_t ticks;
static void udelay(unsigned int us) { (void)us; }
static ktime_t ktime_get(void) { return ticks += 1000; }
static ktime_t ktime_us_delta(ktime_t now, ktime_t then) { return now - then; }
static bool pm_runtime_enabled(struct device *dev) { return dev->enabled; }
static bool pm_runtime_active(struct device *dev) { return dev->active; }
static int pm_runtime_resume_and_get(struct device *dev)
{
	dev->gets++;
	if (dev->get_error)
		return dev->get_error;
	assert(dev->enabled);
	dev->active = true;
	dev->references++;
	return 0;
}
static int pm_runtime_put(struct device *dev)
{
	assert(dev->references > 0);
	dev->references--;
	dev->puts++;
	if (!dev->references)
		dev->active = false;
	return 0;
}
static void check_access(struct regmap *map)
{
	if (map->dev && map->dev->guard)
		assert(map->dev->enabled && map->dev->active && map->dev->references > 0);
}
static int regmap_update_bits(struct regmap *map, unsigned int reg, u32 mask, u32 val)
{
	check_access(map);
	map->writes++;
	if (map->writes == map->fail_write)
		return -EREMOTEIO;
	map->value = (map->value & ~mask) | (val & mask);
	if ((mask & BIT(0)) && !map->stuck)
		map->status = (val & BIT(0)) ? BIT(15) : BIT(16);
	return 0;
}
static int regmap_read(struct regmap *map, unsigned int reg, u32 *val)
{
	check_access(map);
	map->reads++;
	*val = 0;
	if (map->read_error)
		return map->read_error;
	*val = reg == 4 ? map->status : map->value;
	return 0;
}
static int regulator_enable(struct regulator *supply)
{
	supply->enables++;
	return supply->enable_error;
}
static int regulator_disable(struct regulator *supply)
{
	supply->disables++;
	return supply->disable_error;
}
static int icc_set_bw(struct icc_path *path, int average, int peak)
{
	icc_calls++;
	return icc_error;
}
static int pm_genpd_init(struct generic_pm_domain *pd, void *governor, bool off)
{
	init_calls++;
	if (registration_test) {
		if (++registration_inits == init_fail_at)
			return -ENOMEM;
		assert(!pd->initialized);
		pd->initialized = true;
		registered++;
	}
	return init_error;
}
static int pm_genpd_remove(struct generic_pm_domain *pd)
{
	assert(pd->initialized && !pd->parents && !pd->children);
	pd->initialized = false;
	registered--;
	removed++;
	return 0;
}
static struct generic_pm_domain *pd_to_genpd(struct dev_pm_domain *pd)
{
	return container_of(pd, struct generic_pm_domain, domain);
}
static int pm_genpd_add_subdomain(struct generic_pm_domain *parent,
				struct generic_pm_domain *child)
{
	assert(parent->initialized && child->initialized);
	if (++registration_links == link_fail_at)
		return -EIO;
	parent->children++;
	child->parents++;
	linked++;
	return 0;
}
static int pm_genpd_remove_subdomain(struct generic_pm_domain *parent,
				   struct generic_pm_domain *child)
{
	assert(parent->children > 0 && child->parents > 0);
	parent->children--;
	child->parents--;
	linked--;
	return 0;
}
static void *devm_kcalloc(struct device *dev, size_t n, size_t size, int flags)
{
	if (++allocations == allocation_fail_at)
		return NULL;
	assert(allocations <= 2);
	return allocated[allocations - 1] = calloc(n, size);
}
static void *devm_kzalloc(struct device *dev, size_t size, int flags)
{
	return devm_kcalloc(dev, 1, size, flags);
}
static struct icc_path *devm_of_icc_get_by_index(struct device *dev, unsigned int index)
{
	return ERR_PTR(-ENODEV);
}
static struct regulator *devm_regulator_get_optional(struct device *dev, const char *name)
{
	return ERR_PTR(-ENODEV);
}
static int of_genpd_add_provider_onecell(void *node, struct genpd_onecell_data *data)
{
	assert(!published);
	if (provider_error)
		return provider_error;
	published = true;
	return 0;
}
static void of_genpd_del_provider(void *node)
{
	assert(published);
	published = false;
}
#undef assert
#include "gdsc-functions.c"
#include <assert.h>

static void registration_failures(void)
{
	const int link_counts[] = { 0, 3, 3, 6, 2, 3, 5 };
	int cases = 0;
	for (int topology = 0; topology < 7; topology++) {
		for (int failure = 0; failure < 13; failure++) {
			struct generic_pm_domain parent[2] = {
				{ .initialized = true }, { .initialized = true },
			};
			struct device parent_dev[2] = {
				{ .pm_domain = &parent[0].domain },
				{ .pm_domain = &parent[1].domain },
			};
			struct device *parents[] = { &parent_dev[0], &parent_dev[1] };
			struct dev_pm_domain_list list = { .num_pds = 2, .pd_devs = parents };
			struct device dev = {
				.pm_domain = topology == 2 || topology == 5 ? &parent[0].domain : NULL,
			};
			struct regmap map = { .status = BIT(15) };
			struct gdsc domains[3] = {
				{ .pwrsts = PWRSTS_OFF_ON, .flags = POLL_CFG_GDSCR },
				{ .pwrsts = PWRSTS_OFF_ON, .flags = POLL_CFG_GDSCR },
				{ .pwrsts = PWRSTS_OFF_ON, .flags = POLL_CFG_GDSCR },
			};
			struct gdsc *sparse[] = { &domains[0], NULL, &domains[1], &domains[2], NULL };
			struct gdsc_desc desc = { .dev = &dev, .scs = sparse, .num = 5,
				.pd_list = topology == 3 || topology >= 5 ? &list : NULL };
			int ret;

			registration_test = true;
			registered = removed = linked = registration_inits = registration_links = 0;
			allocations = init_error = 0;
			allocation_fail_at = failure == 1 ? 1 : failure == 2 ? 2 : 0;
			init_fail_at = failure >= 3 && failure <= 5 ? failure - 2 : 0;
			link_fail_at = failure >= 6 && failure <= 11 ? failure - 5 : 0;
			provider_error = failure == 12 ? -EEXIST : 0;
			memset(allocated, 0, sizeof(allocated));
			for (int i = 0; i < 3; i++)
				if (topology == 1) domains[i].parent = &parent[0];
			if (topology == 4) {
				domains[1].parent = &domains[0].pd;
				domains[2].parent = &domains[1].pd;
			}
			if (topology == 6) domains[0].parent = &parent[0];

			ret = gdsc_register(&desc, NULL, &map);
			if (failure == 0 || (link_fail_at > link_counts[topology])) {
				assert(!ret && published && registered == 3);
				gdsc_unregister(&desc);
			} else {
				assert(ret == (allocation_fail_at || init_fail_at ? -ENOMEM :
					      link_fail_at ? -EIO : -EEXIST));
#ifdef BASELINE
				assert(registered == (init_fail_at ? init_fail_at - 1 :
						      allocation_fail_at ? 0 : 3));
				/* The old provider-failure path also leaves its parent links. */
				if (failure == 12) {
					assert(linked == link_counts[topology]);
					gdsc_pm_subdomain_remove(&desc, desc.num);
				}
#else
				assert(!registered);
#endif
			}
			assert(!published && !linked && !parent[0].children && !parent[1].children);
			for (int i = 0; i < 2; i++) free(allocated[i]);
			cases++;
		}
	}
	registration_test = false;
	init_calls = 0;
	printf("GDSC: %d sparse registration cases, seven parent topologies, all allocation/init/link/provider failures and teardown checked\n", cases);
}

int main(void)
{
	registration_failures();
	return 0;
}
