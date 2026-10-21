// SPDX-License-Identifier: GPL-2.0-only
/* Host boundary stubs; production functions and gdsc layout are imported. */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define CONFIG_QCOM_GDSC 1
#define BIT(n) (1UL << (n))
#define GENMASK_ULL(h, l) (((~0ULL) << (l)) & (~0ULL >> (63 - (h))))
#define container_of(p, t, m) ((t *)((char *)(p) - offsetof(t, m)))
#define WARN(condition, ...) ((void)(condition))
#define GENPD_FLAG_ALWAYS_ON BIT(0)
#define GENPD_FLAG_IRQ_SAFE BIT(1)
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef unsigned long long ktime_t;

struct device;
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
};
struct generic_pm_domain {
	const char *name;
	unsigned int flags;
	bool synced_poweroff;
	int (*power_on)(struct generic_pm_domain *);
	int (*power_off)(struct generic_pm_domain *);
	int (*set_hwmode_dev)(struct generic_pm_domain *, struct device *, bool);
	bool (*get_hwmode_dev)(struct generic_pm_domain *, struct device *);
};
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
	return init_error;
}
#undef assert
#include "gdsc-functions.c"
#include <assert.h>

static void collapse_errors(void)
{
	for (unsigned int on = 0; on < 2; on++) {
		for (unsigned int votable = 0; votable < 2; votable++) {
			struct regmap map = { .fail_write = 1,
				.status = on ? BIT(16) : BIT(15) };
			struct gdsc sc = { .regmap = &map, .pwrsts = PWRSTS_OFF_ON,
				.flags = POLL_CFG_GDSCR | (votable ? VOTABLE : 0) };
			int ret = gdsc_toggle_logic(&sc, on ? GDSC_ON : GDSC_OFF, false);

#ifdef BASELINE
			/* Reproduce the lost write errno, including the votable fast path. */
			assert(ret == 0);
#else
			assert(ret == -EREMOTEIO);
			assert(map.reads == 0);
#endif
			assert(map.writes == 1);
		}
	}
	assert(init_calls == 0);
#ifdef BASELINE
	assert(icc_calls == 3);
#else
	assert(icc_calls == 2);
#endif
	puts("GDSC: collapse-write errno scenarios checked (ON/OFF, votable/plain)");
}

#ifndef BASELINE
#define CAMERA_FLAGS (GDSC_CONTROLLER_PM | POLL_CFG_GDSCR | RETAIN_FF_ENABLE)
#define CAMERA_DOMAIN(device, map) { .controller_dev = (device), .regmap = (map), \
	.pwrsts = PWRSTS_OFF_ON, .flags = CAMERA_FLAGS }

static int no_op(struct device *dev) { return 0; }
static const struct dev_pm_ops pm_ops = { .runtime_resume = no_op, .runtime_suspend = no_op };
static const struct device_driver permanent_driver = { .suppress_bind_attrs = true, .pm = &pm_ops };

static struct device controller(void)
{
	return (struct device) { .driver = &permanent_driver, .enabled = true, .guard = true };
}

static void normal_transitions(void)
{
	struct device dev = controller();
	struct regmap map = { .dev = &dev, .status = BIT(15) };
	struct gdsc sc = CAMERA_DOMAIN(&dev, &map);

	assert(gdsc_pm_validate(&sc, &dev) == 0);
	for (int cycle = 0; cycle < 3; cycle++) {
		assert(gdsc_enable(&sc.pd) == 0);
		assert(dev.active && dev.references == 1 && sc.controller_pm_held);
		assert(gdsc_enable(&sc.pd) == 0);
		assert(dev.gets == cycle + 1 && dev.puts == cycle);
		assert(gdsc_disable(&sc.pd) == 0);
		assert(map.status == BIT(15));
		assert(!dev.active && !dev.references && !sc.controller_pm_held);
		assert(dev.gets == dev.puts);
	}
	/* An OFF request without prior ownership still resumes before MMIO. */
	assert(gdsc_disable(&sc.pd) == 0);
	assert(dev.gets == 4 && dev.puts == 4);
	puts("GDSC: repeated ON/OFF and OFF-only ownership balanced");
}

static void transition_errors(void)
{
	for (int failure = 0; failure < 5; failure++) {
		struct device dev = controller();
		struct regmap map = { .dev = &dev, .status = BIT(15) };
		struct gdsc sc = CAMERA_DOMAIN(&dev, &map);
		int expected = -EREMOTEIO;

		if (failure == 0) map.fail_write = 1; /* collapse write */
		if (failure == 1) map.fail_write = 2; /* retain-FF write */
		if (failure == 2) map.read_error = expected = -ENXIO;
		if (failure == 3) map.stuck = true, expected = -ETIMEDOUT;
		if (failure == 4) dev.get_error = expected = -EAGAIN;
		assert(gdsc_enable(&sc.pd) == expected);
		assert(dev.puts == 0);
		if (failure == 4) {
			assert(!sc.controller_pm_held && !dev.references);
			assert(!map.reads && !map.writes);
		} else {
			assert(sc.controller_pm_held && dev.references == 1);
		}
		map.fail_write = map.read_error = dev.get_error = 0;
		map.stuck = false;
		assert(gdsc_enable(&sc.pd) == 0);
		assert(dev.references == 1 && dev.gets == (failure == 4 ? 2 : 1));
		assert(gdsc_disable(&sc.pd) == 0);
		assert(dev.puts == 1 && !dev.references);
	}
	for (int failure = 0; failure < 3; failure++) {
		struct device dev = controller();
		struct regmap map = { .dev = &dev, .status = BIT(15) };
		struct gdsc sc = CAMERA_DOMAIN(&dev, &map);
		int expected = -EREMOTEIO;

		assert(gdsc_enable(&sc.pd) == 0);
		if (failure == 0) map.fail_write = map.writes + 1;
		if (failure == 1) map.read_error = expected = -ENXIO;
		if (failure == 2) map.stuck = true, expected = -ETIMEDOUT;
		assert(gdsc_disable(&sc.pd) == expected);
		assert(dev.references == 1 && sc.controller_pm_held && !dev.puts);
		map.fail_write = map.read_error = 0;
		map.stuck = false;
		assert(gdsc_disable(&sc.pd) == 0);
		assert(dev.gets == 1 && dev.puts == 1 && !dev.references);
	}
	puts("GDSC: resume, collapse, retain, status-read and timeout failures preserve ownership");
}

static void inactive_controller(void)
{
	struct device dev = controller();
	struct regmap map = { .dev = &dev, .status = BIT(15) };
	struct gdsc sc = CAMERA_DOMAIN(&dev, &map);

	dev.enabled = false;
	assert(gdsc_enable(&sc.pd) == -EACCES);
	assert(gdsc_disable(&sc.pd) == -EACCES);
	assert(!dev.gets && !map.reads && !map.writes);
	dev.enabled = true;
	assert(gdsc_enable(&sc.pd) == 0);
	int writes = map.writes, reads = map.reads;
	dev.active = false; /* Model forced suspend despite an owned usage reference. */
	assert(gdsc_enable(&sc.pd) == -EHOSTDOWN);
	assert(gdsc_disable(&sc.pd) == -EHOSTDOWN);
	assert(map.writes == writes && map.reads == reads && dev.references == 1);
	dev.active = true;
	dev.enabled = false;
	assert(gdsc_disable(&sc.pd) == -EACCES);
	assert(map.writes == writes && map.reads == reads && dev.references == 1);
	dev.enabled = true;
	assert(gdsc_disable(&sc.pd) == 0);
	puts("GDSC: disabled/forced-inactive controllers refuse MMIO without losing the reference");
}

static void initial_state(void)
{
	for (int on = 0; on < 2; on++) {
		for (int failure = 0; failure < 5; failure++) {
			struct device dev = controller();
			struct regmap map = { .dev = &dev, .status = on ? BIT(16) : BIT(15) };
			struct gdsc sc = CAMERA_DOMAIN(&dev, &map);
			int expected = 0;

			init_error = init_calls = 0;
			if (failure == 1) map.fail_write = 1, expected = -EREMOTEIO;
			if (failure == 2) map.read_error = expected = -ENXIO;
			if (failure == 3) init_error = expected = -ENOMEM;
			if (failure == 4) dev.get_error = expected = -EAGAIN;
			assert(gdsc_init(&sc) == expected);
			if (failure == 4) {
				assert(!map.reads && !map.writes && !sc.controller_pm_held);
				assert(!dev.references && !init_calls);
				continue;
			}
			if (!failure && !on) {
				assert(!sc.controller_pm_held && !dev.references && dev.puts == 1);
			} else {
				assert(sc.controller_pm_held && dev.references == 1 && !dev.puts);
				assert(gdsc_pm_validate(&sc, &dev) == -EBUSY);
			}
			assert(init_calls == (!failure || failure == 3));
			map.fail_write = map.read_error = init_error = 0;
			assert(gdsc_disable(&sc.pd) == 0);
			assert(!dev.references && !sc.controller_pm_held);
		}
	}
	/* Boot-ON retain failure must not be hidden by successful genpd init. */
	struct device dev = controller();
	struct regmap map = { .dev = &dev, .status = BIT(16), .fail_write = 2 };
	struct gdsc sc = CAMERA_DOMAIN(&dev, &map);
	init_calls = 0;
	assert(gdsc_init(&sc) == -EREMOTEIO);
	assert(!init_calls && dev.references == 1 && !dev.puts);
	map.fail_write = 0;
	assert(gdsc_disable(&sc.pd) == 0);
	puts("GDSC: boot ON/OFF, init errors and retain failure checked");
}

static void refused_contracts(void)
{
	unsigned int flags[] = { VOTABLE, CLAMP_IO, HW_CTRL, SW_RESET, AON_RESET,
		ALWAYS_ON, NO_RET_PERIPH, HW_CTRL_TRIGGER };
	struct device dev = controller();
	struct regmap map = { .dev = &dev };
	for (size_t i = 0; i < sizeof(flags) / sizeof(flags[0]); i++) {
		struct gdsc sc = { .controller_dev = &dev, .regmap = &map,
			.pwrsts = PWRSTS_OFF_ON, .flags = CAMERA_FLAGS | flags[i] };
		assert(gdsc_pm_validate(&sc, &dev) == -EINVAL);
	}
	struct gdsc sc = CAMERA_DOMAIN(&dev, &map);
	struct device_driver driver = permanent_driver;
	dev.driver = NULL;
	assert(gdsc_pm_validate(&sc, &dev) == -EINVAL);
	dev.driver = &driver;
	driver.owner = &dev;
	assert(gdsc_pm_validate(&sc, &dev) == -EINVAL);
	driver.owner = NULL;
	driver.suppress_bind_attrs = false;
	assert(gdsc_pm_validate(&sc, &dev) == -EINVAL);
	driver = permanent_driver;
	driver.pm = NULL;
	assert(gdsc_pm_validate(&sc, &dev) == -EINVAL);
	driver = permanent_driver;
	dev.enabled = false;
	assert(gdsc_pm_validate(&sc, &dev) == -EACCES);
	dev.enabled = true;
	sc.pd.flags = GENPD_FLAG_IRQ_SAFE;
	assert(gdsc_pm_validate(&sc, &dev) == -EINVAL);
	sc.pd.flags = 0;
	sc.needs_icc = true;
	assert(gdsc_pm_validate(&sc, &dev) == -EINVAL);
	sc.needs_icc = false;
	sc.supply = "not-supported";
	assert(gdsc_pm_validate(&sc, &dev) == -EINVAL);
	sc.supply = NULL;
	sc.cxc_count = 1;
	assert(gdsc_pm_validate(&sc, &dev) == -EINVAL);
	sc.cxc_count = 0;
	sc.reset_count = 1;
	assert(gdsc_pm_validate(&sc, &dev) == -EINVAL);
	sc.reset_count = 0;
	assert(gdsc_pm_validate(&sc, &dev) == 0);
	struct gdsc retention = { .pwrsts = PWRSTS_RET_ON, .flags = CAMERA_FLAGS };
	assert(gdsc_pm_validate(&retention, &dev) == -EINVAL);
	assert(!dev.gets && !map.reads && !map.writes);
	puts("GDSC: unsupported driver/domain contracts refused before MMIO");
}

static void shared_controller(void)
{
	struct device dev = controller();
	struct regmap maps[8] = { 0 };
	struct gdsc domains[8] = {
		CAMERA_DOMAIN(&dev, NULL), CAMERA_DOMAIN(&dev, NULL),
		CAMERA_DOMAIN(&dev, NULL), CAMERA_DOMAIN(&dev, NULL),
		CAMERA_DOMAIN(&dev, NULL), CAMERA_DOMAIN(&dev, NULL),
		CAMERA_DOMAIN(&dev, NULL), CAMERA_DOMAIN(&dev, NULL),
	};

	for (int i = 0; i < 8; i++) {
		maps[i].dev = &dev;
		maps[i].status = BIT(15);
		domains[i].regmap = &maps[i];
		assert(gdsc_enable(&domains[i].pd) == 0);
	}
	assert(dev.references == 8 && dev.gets == 8);
	maps[3].fail_write = maps[3].writes + 1;
	assert(gdsc_disable(&domains[3].pd) == -EREMOTEIO);
	assert(dev.references == 8);
	maps[3].fail_write = 0;
	for (int i = 0; i < 8; i++)
		if (i != 3) assert(gdsc_disable(&domains[i].pd) == 0);
	assert(dev.references == 1 && dev.active);
	assert(gdsc_disable(&domains[3].pd) == 0);
	assert(!dev.references && !dev.active && dev.puts == 8);
	puts("GDSC: eight owners retain the controller until the last verified OFF");
}

static void legacy_domain(void)
{
	struct device dev = controller();
	struct regmap map = { .dev = &dev, .status = BIT(15) };
	struct gdsc sc = { .regmap = &map, .pwrsts = PWRSTS_OFF_ON, .flags = POLL_CFG_GDSCR };

	dev.guard = dev.enabled = false;
	assert(gdsc_pm_validate(&sc, &dev) == 0);
	assert(gdsc_init(&sc) == 0);
	assert(gdsc_enable(&sc.pd) == 0);
	assert(gdsc_disable(&sc.pd) == 0);
	assert(!dev.gets && !dev.puts && !dev.references);
	puts("GDSC: existing domains make no new controller-PM calls");
}
#endif

int main(void)
{
	collapse_errors();
#ifndef BASELINE
	normal_transitions();
	transition_errors();
	inactive_controller();
	initial_state();
	refused_contracts();
	shared_controller();
	legacy_domain();
#endif
	return 0;
}
