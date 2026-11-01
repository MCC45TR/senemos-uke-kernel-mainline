// SPDX-License-Identifier: GPL-2.0-only
/* Host models only OS/hardware boundaries; production functions are imported. */
#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdatomic.h>
#include <string.h>

#define BIT(n) (1U << (n))
#define GENMASK(h, l) ((~0U << (l)) & (~0U >> (31 - (h))))
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define DIV_ROUND_CLOSEST(a, b) (((a) + (b) / 2) / (b))
#define max(a, b) ((a) > (b) ? (a) : (b))
#define WARN(condition, ...) warn_model(condition)
#define pr_debug(...) ((void)0)
#define pr_err(...) ((void)0)
#define dev_err(...) ((void)0)
#define dev_warn(...) ((void)0)
#define EXPORT_SYMBOL(name)
#define EXPORT_SYMBOL_GPL(name)
#define DEFINE_MUTEX(name) int name
#define DEFINE_SPINLOCK(name) atomic_flag name = ATOMIC_FLAG_INIT
#define spin_lock_irqsave(lock, flags) do { (flags) = 0; model_spin_lock(lock); } while (0)
#define spin_unlock_irqrestore(lock, flags) do { (void)(flags); atomic_flag_clear_explicit(lock, memory_order_release); } while (0)
#define __iomem
#define __maybe_unused
#undef static_assert
#define static_assert(expression) _Static_assert(expression, #expression)
#define EPROBE_DEFER 517
#define READ_ONCE(x) (x)
#define WRITE_ONCE(x, value) ((x) = (value))
#define IS_ERR(x) ((uintptr_t)(x) >= (uintptr_t)-4095)
#define IS_ERR_OR_NULL(x) (!(x) || IS_ERR(x))
#define PTR_ERR(x) ((int)(intptr_t)(x))
#define ERR_PTR(x) ((void *)(intptr_t)(x))
typedef uint32_t u32;
typedef uint64_t resource_size_t;
static void mutex_lock(int *lock) { (void)lock; }
static bool warn_model(bool condition) { return condition; }
static void mutex_unlock(int *lock) { (void)lock; }
static int atomic_read(int *value) { return *value; }
static atomic_int spin_waits;
static void model_spin_lock(atomic_flag *lock)
{
	bool waited = false;
	while (atomic_flag_test_and_set_explicit(lock, memory_order_acquire)) {
		if (!waited) atomic_fetch_add_explicit(&spin_waits, 1, memory_order_relaxed);
		waited = true;
	}
}

struct device;
struct dev_pm_ops {
	int (*runtime_suspend)(struct device *);
	int (*runtime_resume)(struct device *);
	int (*runtime_idle)(struct device *);
	int (*suspend)(struct device *);
	int (*resume)(struct device *);
};
#define RUNTIME_PM_OPS(s, r, i) .runtime_suspend = (s), .runtime_resume = (r), .runtime_idle = (i),
#define SYSTEM_SLEEP_PM_OPS(s, r) .suspend = (s), .resume = (r),
struct device {
	void *data;
	const struct device_driver *driver;
	struct device_node *of_node;
	void *pm_domain;
	int references;
	const struct dev_pm_ops *ops;
	struct { int usage_count, child_count; bool needs_force_resume, smart_suspend; } power;
	bool disabled, suspended;
};
struct clk_hw {
	const struct clk_init_data *init;
	unsigned long rate;
	bool prepared, enabled;
	unsigned int parent;
};
static const char *clk_hw_get_name(struct clk_hw *hw) { return "camera-model"; }
struct clk { int count, enables, disables, error; };
struct regulator {
	int count, voltage, sets, enables, disables;
	int set_error, enable_error, disable_error;
	bool late_disable;
};
struct regmap_config {
	unsigned int reg_bits, reg_stride, val_bits, max_register;
	bool fast_io;
	int (*reg_read)(void *, unsigned int, unsigned int *);
	int (*reg_write)(void *, unsigned int, unsigned int);
};
struct gdsc { bool controller_pm_held; };
#include "rpmh-levels.h"
#include "vdd-level.h"
#include "vdd-class.h"
struct qcom_cc_desc {
	struct clk_vdd_class **clk_regulators;
	size_t num_clk_regulators;
	struct gdsc **gdscs;
	size_t num_gdscs;
	size_t num_resets;
	bool use_rpm, skip_reset_provider;
};

static struct regulator regulators[3];
static struct clk iface;
static int get_rail_error = -1, missing_rail = -1, get_clock_error, validation_error;
static int ordinary_gets;
static int reads, writes, operations;
static u32 memory[0x20000 / sizeof(u32)];
static void (*write_hook)(void);
static void *dev_get_drvdata(struct device *dev) { return dev->data; }
static void dev_set_drvdata(struct device *dev, void *data) { dev->data = data; }
static struct regulator *regulator_get_optional(struct device *dev, const char *name)
{
	const char *names[] = { "vdd_mm", "vdd_mx", "vdd_mxc" };
	for (int i = 0; i < 3; i++)
		if (!strcmp(name, names[i])) {
			if (missing_rail == i) return ERR_PTR(-ENODEV);
			return get_rail_error == i ? ERR_PTR(-EPROBE_DEFER) : &regulators[i];
		}
	assert(false);
	return ERR_PTR(-EINVAL);
}
static struct regulator *devm_regulator_get(struct device *dev, const char *name)
{
	static struct regulator dummy;
	struct regulator *regulator = regulator_get_optional(dev, name);
	ordinary_gets++;
	return IS_ERR(regulator) && PTR_ERR(regulator) == -ENODEV ? &dummy : regulator;
}
static int regulator_set_voltage(struct regulator *r, int min_uv, int max_uv)
{
	operations++;
	r->sets++;
	if (r->set_error) return r->set_error;
	r->voltage = min_uv;
	return 0;
}
static int regulator_enable(struct regulator *r)
{
	operations++;
	r->enables++;
	if (r->enable_error) return r->enable_error;
	r->count++;
	return 0;
}
static int regulator_disable(struct regulator *r)
{
	operations++;
	r->disables++;
	assert(r->count > 0);
	if (r->disable_error && !r->late_disable) return r->disable_error;
	r->count--;
	return r->disable_error;
}
static void regulator_put(struct regulator *regulator) { assert(!regulator->count); }
static void clk_put(struct clk *clock) { assert(!clock->count); }
static struct device *get_device(struct device *dev) { dev->references++; return dev; }
static struct clk *clk_get(struct device *dev, const char *name)
{
	assert(!strcmp(name, "iface"));
	return get_clock_error ? ERR_PTR(get_clock_error) : &iface;
}
static int clk_prepare_enable(struct clk *clk)
{
	operations++;
	clk->enables++;
	for (int i = 0; i < 3; i++) assert(regulators[i].count == 1);
	if (clk->error) return clk->error;
	clk->count++;
	return 0;
}
static void clk_disable_unprepare(struct clk *clk)
{
	operations++;
	clk->disables++;
	assert(clk->count == 1);
	clk->count--;
}
static u32 readl(void *address) { reads++; return *(u32 *)address; }
static void writel(u32 value, void *address)
{
	if (write_hook) write_hook();
	writes++;
	*(u32 *)address = value;
}
static int cam_cc_validate_voltage_data(void) { return validation_error; }
static int pm_runtime_force_suspend(struct device *dev);
static int pm_runtime_force_resume(struct device *dev);
#include "vdd-functions.c"
#include "camcc-rails.h"
#include "camcc-config.h"
static struct gdsc domains[8];
static struct gdsc *cam_cc_sm7675_gdscs[] = {
	&domains[0], &domains[1], &domains[2], &domains[3],
	&domains[4], &domains[5], &domains[6], &domains[7],
};
static const struct qcom_cc_desc cam_cc_sm7675_desc = {
	.clk_regulators = cam_cc_sm7675_regulators,
	.num_clk_regulators = ARRAY_SIZE(cam_cc_sm7675_regulators),
	.gdscs = cam_cc_sm7675_gdscs,
	.num_gdscs = ARRAY_SIZE(cam_cc_sm7675_gdscs),
	.num_resets = 2,
};
#include "provider-power.h"

static void pm_runtime_disable(struct device *dev) { dev->disabled = true; }
static void pm_runtime_enable(struct device *dev) { dev->disabled = false; }
static bool pm_runtime_status_suspended(struct device *dev) { return dev->suspended; }
static bool pm_runtime_need_not_resume(struct device *dev)
{
	return dev->power.usage_count <= 1 && !dev->power.child_count;
}
static int pm_runtime_set_suspended(struct device *dev) { dev->suspended = true; return 0; }
static bool dev_pm_smart_suspend(struct device *dev) { return dev->power.smart_suspend; }
static void dev_pm_enable_wake_irq_check(struct device *dev, bool system) {}
static void dev_pm_disable_wake_irq_check(struct device *dev, bool system) {}
static void dev_pm_enable_wake_irq_complete(struct device *dev) {}
static void pm_runtime_mark_last_busy(struct device *dev) {}
#define GET_CALLBACK(dev, name) ((dev)->ops->name)
#include "force-pm.c"

static void reset(struct device *dev)
{
	/* A new isolated host test, never a production recovery/reset API. */
	memset(&cam_cc_power, 0, sizeof(cam_cc_power));
	memset(regulators, 0, sizeof(regulators));
	memset(domains, 0, sizeof(domains));
	memset(memory, 0, sizeof(memory));
	iface = (struct clk) { 0 };
	*dev = (struct device) { .ops = &cam_cc_power_pm_ops, .suspended = true };
	get_rail_error = -1;
	missing_rail = -1;
	ordinary_gets = 0;
	get_clock_error = validation_error = reads = writes = operations = 0;
	for (int i = 0; i < 3; i++) {
		struct clk_vdd_class *rail = cam_cc_sm7675_regulators[i];
		memset(rail->level_votes, 0, rail->num_levels * sizeof(int));
		rail->regulator[0] = NULL;
		rail->cur_level = rail->num_levels;
	}
}

static void start(struct device *dev)
{
	reset(dev);
	assert(cam_cc_power_init(dev, memory, sizeof(memory)) == 0);
	assert(cam_cc_power_regmap_config.reg_read == cam_cc_power_read);
	assert(cam_cc_power_regmap_config.reg_write == cam_cc_power_write);
}

static void active(struct device *dev)
{
	assert(dev->ops->runtime_resume(dev) == 0);
	dev->suspended = false;
	assert(cam_cc_power.votes == 7 && cam_cc_power.iface_on && iface.count == 1);
}

static void blocked_access(int error)
{
	unsigned int value = 0xfeed;
	int before = reads + writes;
	assert(cam_cc_power_read(&cam_cc_power, 0, &value) == error);
	assert(value == 0xfeed);
	assert(cam_cc_power_write(&cam_cc_power, 0, 3) == error);
	assert(reads + writes == before);
}

static void cycles(void)
{
	struct device dev;
	start(&dev);
	blocked_access(-EHOSTDOWN);
	for (int cycle = 0; cycle < 3; cycle++) {
		active(&dev);
		int before = operations;
		assert(dev.ops->runtime_resume(&dev) == 0 && operations == before);
		unsigned int value;
		assert(cam_cc_power_write(&cam_cc_power, 0, cycle + 42) == 0);
		assert(cam_cc_power_read(&cam_cc_power, 0, &value) == 0 && value == (unsigned int)cycle + 42);
		unsigned int last = cam_cc_power_regmap_config.max_register;
		assert(cam_cc_power_write(&cam_cc_power, last, 91) == 0);
		assert(cam_cc_power_read(&cam_cc_power, last, &value) == 0 && value == 91);
		assert(cam_cc_power_write(&cam_cc_power, last + 4, 7) == -EINVAL);
		assert(dev.ops->runtime_suspend(&dev) == 0);
		assert(!cam_cc_power.votes && !cam_cc_power.iface_on && !iface.count);
		for (int i = 0; i < 3; i++) {
			assert(regulators[i].count == 0);
			assert(cam_cc_sm7675_regulators[i]->level_votes[VDD_MIN] == 0);
		}
		before = operations;
		assert(dev.ops->runtime_suspend(&dev) == 0 && operations == before);
		blocked_access(-EHOSTDOWN);
	}
	assert(iface.enables == 3 && iface.disables == 3);
	puts("CAMCC provider: cycles, ordering, duplicate callbacks and MMIO gates pass");
}

static void voltage_errors(void)
{
	struct device dev;
	for (int rail = 0; rail < 3; rail++) {
		for (int stage = 0; stage < 2; stage++) {
			start(&dev);
			if (!stage) regulators[rail].set_error = -EAGAIN;
			else regulators[rail].enable_error = -EBUSY;
			assert(dev.ops->runtime_resume(&dev) == -EIO);
			assert(cam_cc_power.primary_error == (stage ? -EBUSY : -EAGAIN));
			assert(cam_cc_power.uncertain_rails == BIT(rail));
			assert(cam_cc_power.votes == BIT(rail) - 1 && !iface.count);
			assert(cam_cc_sm7675_regulators[rail]->level_votes[VDD_MIN] == 0);
			int before = operations;
			assert(dev.ops->runtime_resume(&dev) == -EIO);
			assert(dev.ops->runtime_suspend(&dev) == -EIO && operations == before);
			blocked_access(-EIO);
		}
	}
	puts("CAMCC provider: every voltage/enable failure latches uncertainty without retry");
}

static void clock_rollback(void)
{
	struct device dev;
	start(&dev);
	iface.error = -EAGAIN;
	assert(dev.ops->runtime_resume(&dev) == -EAGAIN);
	assert(!cam_cc_power.fault && !cam_cc_power.votes && !iface.count);
	for (int i = 0; i < 3; i++) assert(!regulators[i].count);
	iface.error = 0;
	active(&dev);
	assert(dev.ops->runtime_suspend(&dev) == 0);
	for (int rail = 0; rail < 3; rail++) {
		start(&dev);
		iface.error = -EAGAIN;
		regulators[rail].disable_error = -EREMOTEIO;
		assert(dev.ops->runtime_resume(&dev) == -EIO);
		assert(cam_cc_power.primary_error == -EAGAIN && cam_cc_power.rollback_error == -EREMOTEIO);
		assert(cam_cc_power.uncertain_rails == BIT(rail));
		assert(cam_cc_power.votes == BIT(rail + 1) - 1);
		int before = operations;
		assert(dev.ops->runtime_resume(&dev) == -EIO && operations == before);
		blocked_access(-EIO);
	}
	puts("CAMCC provider: clean clock rollback retries; failed rollback preserves both errors");
}

static void disable_errors(void)
{
	struct device dev;
	for (int rail = 0; rail < 3; rail++) {
		for (int late = 0; late < 2; late++) {
			start(&dev);
			active(&dev);
			regulators[rail].disable_error = -EBUSY;
			regulators[rail].late_disable = late;
			assert(dev.ops->runtime_suspend(&dev) == -EIO);
			assert(cam_cc_power.primary_error == -EBUSY && !cam_cc_power.iface_on);
			assert(cam_cc_power.votes == BIT(rail + 1) - 1);
			assert(cam_cc_sm7675_regulators[rail]->level_votes[VDD_MIN] == 1);
			assert(regulators[rail].count == (late ? 0 : 1));
			int before = operations;
			assert(dev.ops->runtime_suspend(&dev) == -EIO);
			assert(dev.ops->runtime_resume(&dev) == -EIO && operations == before);
			blocked_access(-EIO);
		}
	}
	puts("CAMCC provider: early/late disable errors never assume the backend counter is unchanged");
}

static void forced_suspend(void)
{
	struct device dev;
	for (int guard = 0; guard < 10; guard++) {
		start(&dev);
		active(&dev);
		if (guard == 0) dev.power.usage_count = 1;
		else if (guard == 1) dev.power.child_count = 1;
		else domains[guard - 2].controller_pm_held = true;
		int before = operations;
		assert(dev.ops->suspend(&dev) == -EBUSY);
		assert(!dev.disabled && !dev.suspended && operations == before);
		assert(cam_cc_power.votes == 7 && cam_cc_power.iface_on);
	}
	start(&dev);
	active(&dev);
	assert(dev.ops->suspend(&dev) == 0);
	assert(dev.disabled && dev.suspended && !iface.count && !cam_cc_power.votes);
	blocked_access(-EHOSTDOWN);
	assert(dev.ops->resume(&dev) == 0 && !dev.disabled);
	active(&dev);
	regulators[1].disable_error = -EAGAIN;
	assert(dev.ops->suspend(&dev) == -EIO);
	assert(!dev.disabled && !dev.suspended);
	/* force_suspend calls the driver directly: MMIO must guard the local fault. */
	blocked_access(-EIO);
	int before = operations;
	assert(dev.ops->runtime_resume(&dev) == -EIO && operations == before);
	puts("CAMCC provider: actual forced-PM functions honor usage/children/eight GDSC guards and fatal MMIO gate");
}

static void initialization(void)
{
	struct device dev;
	reset(&dev);
	assert(cam_cc_power_init(&dev, NULL, sizeof(memory)) == -EINVAL);
	assert(cam_cc_power_init(&dev, ERR_PTR(-ENOMEM), sizeof(memory)) == -ENOMEM);
	assert(cam_cc_power_init(&dev, memory, 4) == -EINVAL);
	unsigned int required = cam_cc_sm7675_regmap_config.max_register + sizeof(u32);
	assert(cam_cc_power_init(&dev, memory, required - 1) == -EINVAL);
	validation_error = -ERANGE;
	assert(cam_cc_power_init(&dev, memory, sizeof(memory)) == -ERANGE);
	assert(!dev.data && !operations);
	validation_error = 0;
	get_clock_error = -EPROBE_DEFER;
	assert(cam_cc_power_init(&dev, memory, sizeof(memory)) == -EPROBE_DEFER);
	get_clock_error = 0;
	for (int i = 0; i < 3; i++) {
		get_rail_error = i;
		assert(cam_cc_power_init(&dev, memory, sizeof(memory)) == -EPROBE_DEFER);
		assert(!dev.data && !cam_cc_power.dev && !operations);
		for (int j = 0; j < 3; j++) assert(!cam_cc_sm7675_regulators[j]->regulator[0]);
	}
	get_rail_error = -1;
	for (int i = 0; i < 3; i++) {
		missing_rail = i;
		assert(cam_cc_power_init(&dev, memory, sizeof(memory)) == -ENODEV);
		assert(!dev.data && !operations && !ordinary_gets);
		for (int j = 0; j < 3; j++) assert(!cam_cc_sm7675_regulators[j]->regulator[0]);
	}
	missing_rail = -1;
	assert(cam_cc_power_init(&dev, memory, required) == 0);
	assert(cam_cc_power_init(&dev, memory, sizeof(memory)) == -EBUSY);
	unsigned int value;
	assert(cam_cc_power_read(&cam_cc_power, 1, &value) == -EINVAL);
	assert(cam_cc_power_read(&cam_cc_power, sizeof(memory), &value) == -EINVAL);
	assert(cam_cc_power_read(NULL, 0, &value) == -EINVAL);
	assert(cam_cc_power_read(&cam_cc_power, 0, NULL) == -EINVAL);
	assert(cam_cc_power_write(NULL, 0, 1) == -EINVAL);
	assert(!reads && !writes && !operations);
	puts("CAMCC provider: initialization, deferred suppliers, duplicate owner and MMIO bounds pass");
}

static void independent_votes(void)
{
	struct device dev;
	start(&dev);
	struct clk_vdd_class_data other = { .vdd_class = &cam_cc_mm };
	assert(clk_vote_vdd_level(&other, VDD_NOMINAL) == 0);
	active(&dev);
	assert(dev.ops->runtime_suspend(&dev) == 0);
	assert(!cam_cc_power.votes && regulators[0].count == 1);
	assert(cam_cc_mm.level_votes[VDD_NOMINAL] == 1 && cam_cc_mm.level_votes[VDD_MIN] == 0);
	assert(regulators[0].voltage == RPMH_REGULATOR_LEVEL_NOM);
	assert(clk_unvote_vdd_level(&other, VDD_NOMINAL) == 0);
	assert(!regulators[0].count);
	start(&dev);
	cam_cc_power.votes = 1;
	assert(dev.ops->runtime_resume(&dev) == -EIO && cam_cc_power.primary_error == -EUCLEAN);
	assert(!operations);
	start(&dev);
	active(&dev);
	cam_cc_power.iface_on = false;
	int before = operations;
	assert(dev.ops->runtime_suspend(&dev) == -EIO && operations == before);
	dev.data = NULL;
	assert(dev.ops->runtime_suspend(&dev) == -ENODEV);
	assert(dev.ops->runtime_resume(&dev) == -ENODEV && operations == before);
	puts("CAMCC provider: independent voltage votes survive; corrupt/foreign ownership is refused");
}

int main(void)
{
	initialization();
	cycles();
	voltage_errors();
	clock_rollback();
	disable_errors();
	forced_suspend();
	independent_votes();
	return 0;
}
