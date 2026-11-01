// SPDX-License-Identifier: GPL-2.0-only
/* Reuse power boundaries; import the actual native/reset/clock-vote functions. */
#define main power_contract_main
#include "camcc-provider-check.c"
#undef main
#include <pthread.h>
#include <sched.h>

#define IORESOURCE_MEM 1
#define OF_DYNAMIC 1
#define PROBE_FORCE_SYNCHRONOUS 0
#define MODULE_DESCRIPTION(value)
#define MODULE_LICENSE(value)
#define builtin_platform_driver(driver)
#define container_of(p, t, m) ((t *)((char *)(p) - offsetof(t, m)))
typedef uint8_t u8;
struct device_node { bool dynamic, power_domains; };
struct of_device_id { const char *compatible; };
struct device_driver {
	void *owner;
	const char *name;
	const struct of_device_id *of_match_table;
	const struct dev_pm_ops *pm;
	void (*sync_state)(struct device *);
	bool suppress_bind_attrs;
	int probe_type;
};
struct resource { resource_size_t start, end; };
struct platform_device { struct device dev; struct resource resource; };
struct platform_driver {
	int (*probe)(struct platform_device *);
	void (*remove)(struct platform_device *);
	void (*shutdown)(struct platform_device *);
	struct device_driver driver;
};
struct regmap { const struct regmap_config *config; void *context; };
struct reset_controller_dev;
struct reset_control_ops {
	int (*assert)(struct reset_controller_dev *, unsigned long);
	int (*deassert)(struct reset_controller_dev *, unsigned long);
	int (*reset)(struct reset_controller_dev *, unsigned long);
};
struct reset_controller_dev {
	struct device *dev;
	struct device_node *of_node;
	const struct reset_control_ops *ops;
	unsigned int nr_resets;
};
struct qcom_reset_map { unsigned int reg, bit, bitmask, udelay; };
struct qcom_reset_controller {
	struct reset_controller_dev rcdev;
	struct regmap *regmap;
	const struct qcom_reset_map *reset_map;
};
static struct qcom_reset_controller *to_qcom_reset_controller(struct reset_controller_dev *rcdev)
{
	return container_of(rcdev, struct qcom_reset_controller, rcdev);
}
struct clk_ops {
	int (*prepare)(struct clk_hw *);
	void (*unprepare)(struct clk_hw *);
	int (*enable)(struct clk_hw *);
	void (*disable)(struct clk_hw *);
	int (*is_enabled)(struct clk_hw *);
	int (*pre_rate_change)(struct clk_hw *, unsigned long, unsigned long);
	int (*post_rate_change)(struct clk_hw *, unsigned long, unsigned long);
	int (*set_rate)(struct clk_hw *, unsigned long, unsigned long);
	unsigned long (*recalc_rate)(struct clk_hw *, unsigned long);
	int (*set_parent)(struct clk_hw *, u8);
	u8 (*get_parent)(struct clk_hw *);
	int (*set_rate_and_parent)(struct clk_hw *, unsigned long, unsigned long, u8);
};
struct clk_init_data { const struct clk_ops *ops; };
struct clk_regmap { struct clk_hw hw; struct clk_vdd_class_data vdd_data; };
static struct clk_regmap *to_clk_regmap(struct clk_hw *hw)
{
	return container_of(hw, struct clk_regmap, hw);
}
static unsigned long clk_hw_get_rate(struct clk_hw *hw) { return hw->rate; }
static struct clk_hw parents[] = {
	{ .rate = 100000000 }, { .rate = 200000000 }, { .rate = 900000000 },
};
static struct clk_hw *clk_hw_get_parent_by_index(struct clk_hw *hw, u8 index)
{
	return index < ARRAY_SIZE(parents) ? &parents[index] : NULL;
}
static bool clk_hw_is_prepared(struct clk_hw *hw) { return hw->prepared; }
#include "clock-votes.c"

static int prepare_error, enable_error, program_error, enabled_error;
static bool disable_stuck;
static int prepared_calls, programmed_calls;
static int model_prepare(struct clk_hw *hw) { prepared_calls++; return prepare_error; }
static int model_enable(struct clk_hw *hw)
{
	if (enable_error) return enable_error;
	hw->enabled = true;
	return 0;
}
static void model_disable(struct clk_hw *hw) { if (!disable_stuck) hw->enabled = false; }
static int model_enabled(struct clk_hw *hw) { return enabled_error ?: hw->enabled; }
static int model_rate(struct clk_hw *hw, unsigned long rate, unsigned long parent)
{
	programmed_calls++;
	if (program_error) return program_error;
	hw->rate = rate;
	return 0;
}
static int model_parent(struct clk_hw *hw, u8 parent)
{
	programmed_calls++;
	if (program_error) return program_error;
	hw->parent = parent;
	return 0;
}
static u8 model_get_parent(struct clk_hw *hw) { return hw->parent; }
static unsigned long model_recalc(struct clk_hw *hw, unsigned long rate) { return rate; }
static int model_rate_parent(struct clk_hw *hw, unsigned long rate, unsigned long parent, u8 index)
{
	int ret = model_rate(hw, rate, parent);
	return ret ?: model_parent(hw, index);
}
static const struct clk_ops clk_alpha_pll_lucid_evo_ops = {
	.prepare = model_prepare, .enable = model_enable, .disable = model_disable,
	.is_enabled = model_enabled, .set_rate = model_rate,
};
static const struct clk_ops clk_alpha_pll_rivian_evo_ops = {
	.enable = model_enable, .disable = model_disable, .is_enabled = model_enabled,
};
static const struct clk_ops clk_alpha_pll_postdiv_lucid_ole_ops = { .set_rate = model_rate };
static const struct clk_ops clk_rcg2_shared_ops = {
	.enable = model_enable, .disable = model_disable, .set_rate = model_rate,
	.set_parent = model_parent, .get_parent = model_get_parent,
	.recalc_rate = model_recalc,
	.set_rate_and_parent = model_rate_parent,
};
static const struct clk_ops clk_branch2_ops = {
	.enable = model_enable, .disable = model_disable, .is_enabled = model_enabled,
};
static struct clk_regmap clocks[5];
static struct clk_regmap *cam_cc_sm7675_clocks[] = {
	&clocks[0], &clocks[1], &clocks[2], &clocks[3], &clocks[4],
};
static struct clk_init_data initial_clocks[5];
static unsigned long rates[VDD_NUM] = { [VDD_MIN] = 100000000, [VDD_LOW] = 200000000 };
static const struct qcom_reset_map cam_cc_sm7675_resets[] = {
	{ .reg = 0, .bit = 0 }, { .reg = 4, .bit = 1 },
};
static struct regmap model_map;
static int resource_failure, action_error, registration_error, reset_registration_error, sync_error;
static int region_count, map_count, regmap_count, releases, barriers, registration_calls;
static int reset_write_error, reset_read_error, reset_fail_at, reset_updates, reset_reads, sleeps;
static int common_reset_calls, common_reset_error;
static void (*detach_action)(void *);
static void *detach_data;
static struct reset_controller_dev *reset_provider;

static struct platform_device *to_platform_device(struct device *dev)
{
	return container_of(dev, struct platform_device, dev);
}
static bool of_node_check_flag(struct device_node *node, int flag) { return node->dynamic; }
static void *of_find_property(struct device_node *node, const char *name, int *length)
{
	return node->power_domains ? node : NULL;
}
static const char *dev_name(struct device *dev) { return "host-camera-model"; }
static struct resource *platform_get_resource(struct platform_device *pdev, int type, int index)
{
	return resource_failure == 1 ? NULL : &pdev->resource;
}
static resource_size_t resource_size(struct resource *resource)
{
	return resource->end - resource->start + 1;
}
static struct resource *request_mem_region(resource_size_t start, resource_size_t size, const char *name)
{
	static struct resource reservation;
	if (resource_failure == 2) return NULL;
	assert(!region_count++);
	return &reservation;
}
static void release_mem_region(resource_size_t start, resource_size_t size)
{
	assert(region_count-- == 1);
	releases++;
}
static void *ioremap(resource_size_t start, resource_size_t size)
{
	if (resource_failure == 3) return NULL;
	assert(!map_count++);
	return memory;
}
static void iounmap(void *base) { assert(base == memory && map_count-- == 1); releases++; }
static struct regmap *regmap_init(struct device *dev, void *bus, void *context,
				const struct regmap_config *config)
{
	if (resource_failure == 4) return ERR_PTR(-ENOMEM);
	assert(!bus && context == &cam_cc_power && !regmap_count++);
	model_map = (struct regmap) { .config = config, .context = context };
	return &model_map;
}
static void regmap_exit(struct regmap *map) { assert(regmap_count-- == 1); releases++; }
static int devm_add_action_or_reset(struct device *dev, void (*action)(void *), void *data)
{
	if (action_error) { action(data); return action_error; }
	assert(!detach_action);
	detach_action = action;
	detach_data = data;
	return 0;
}
static void pm_runtime_get_noresume(struct device *dev) { dev->power.usage_count++; }
static int pm_runtime_resume_and_get(struct device *dev)
{
	int ret;
	if (dev->disabled) return -EACCES;
	if (dev->suspended) {
		ret = dev->ops->runtime_resume(dev);
		if (ret) return ret;
		dev->suspended = false;
	}
	dev->power.usage_count++;
	return 0;
}
static void pm_runtime_put(struct device *dev) { assert(dev->power.usage_count-- > 0); }
static void pm_runtime_barrier(struct device *dev) { barriers++; }
static int clk_sync_state(struct device *dev) { return sync_error; }
static int qcom_cc_really_probe(struct device *dev, const struct qcom_cc_desc *desc, struct regmap *map)
{
	assert(desc->skip_reset_provider && !desc->use_rpm);
	assert(cam_cc_power.iface_on && !cam_cc_power.fault);
	for (int i = 0; i < 3; i++)
		assert(cam_cc_sm7675_regulators[i]->level_votes[cam_cc_sm7675_regulators[i]->num_levels - 1]);
	registration_calls++;
	for (int i = 0; i < 5; i++) clocks[i].hw.init = NULL;
	return registration_error;
}
static int reset_controller_register(struct reset_controller_dev *rcdev)
{
	assert(!reset_provider && rcdev->dev == cam_cc_power.dev);
	if (reset_registration_error) return reset_registration_error;
	reset_provider = rcdev;
	return 0;
}
static void reset_controller_unregister(struct reset_controller_dev *rcdev)
{
	assert(rcdev == reset_provider);
	reset_provider = NULL;
}
static int devm_reset_controller_register(struct device *dev, struct reset_controller_dev *rcdev)
{
	common_reset_calls++;
	return common_reset_error;
}
static int common_reset_selection(bool skip)
{
	struct qcom_cc_desc selection = { .skip_reset_provider = skip };
	const struct qcom_cc_desc *desc = &selection;
	struct qcom_reset_controller storage = { 0 }, *reset = &storage;
	struct device *dev = NULL;
	int ret = 0;
#include "common-reset.c"
put_rpm:
	return ret;
}
static int regmap_update_bits(struct regmap *map, unsigned int reg, unsigned int mask, unsigned int value)
{
	unsigned int old;
	int ret;
	reset_updates++;
	if (reset_updates == reset_fail_at) return reset_write_error;
	ret = map->config->reg_read(map->context, reg, &old);
	return ret ?: map->config->reg_write(map->context, reg, (old & ~mask) | (value & mask));
}
static int regmap_read(struct regmap *map, unsigned int reg, unsigned int *value)
{
	reset_reads++;
	return reset_read_error ?: map->config->reg_read(map->context, reg, value);
}
static void fsleep(unsigned int delay) { sleeps++; }
#undef assert
#include "reset-functions.c"
#include "native-provider.c"
#include <assert.h>

static struct device_node static_node;
static void native_environment(struct platform_device *pdev)
{
	reset(&pdev->dev);
	pdev->resource = (struct resource) { .start = 0x100000, .end = 0x100000 + sizeof(memory) - 1 };
	pdev->dev.driver = &cam_cc_native_driver.driver;
	pdev->dev.of_node = &static_node;
	pdev->dev.disabled = true;
	static_node = (struct device_node) { 0 };
	cam_cc_native_clocks_ready = cam_cc_native_probe_held = false;
	cam_cc_native_proxy_active = cam_cc_native_published = cam_cc_native_reset_registered = false;
	resource_failure = action_error = registration_error = reset_registration_error = sync_error = 0;
	region_count = map_count = regmap_count = releases = barriers = registration_calls = 0;
	reset_write_error = reset_read_error = reset_fail_at = reset_updates = reset_reads = sleeps = 0;
	prepare_error = enable_error = program_error = enabled_error = prepared_calls = programmed_calls = 0;
	disable_stuck = false;
	detach_action = NULL;
	reset_provider = NULL;
	for (int i = 0; i < 5; i++) {
		initial_clocks[i].ops = cam_cc_native_base_ops[i];
		clocks[i] = (struct clk_regmap) { .hw = { .init = &initial_clocks[i], .rate = 100000000 } };
		if (i == 0 || i == 1 || i == 3)
			clocks[i].vdd_data = (struct clk_vdd_class_data) {
				.vdd_class = cam_cc_sm7675_regulators[0], .rate_max = rates, .num_rate_max = VDD_NUM,
			};
	}
}

static void managed_cleanup(void)
{
	if (detach_action) { detach_action(detach_data); detach_action = NULL; }
}

static void early_failures(void)
{
	struct platform_device pdev;
	for (int failure = 0; failure < 8; failure++) {
		native_environment(&pdev);
		if (failure < 4) resource_failure = failure + 1;
		if (failure == 4) action_error = -ENOMEM;
		if (failure == 5) get_clock_error = -EPROBE_DEFER;
		if (failure == 6) get_rail_error = 2;
		if (failure == 7) missing_rail = 1;
		assert(cam_cc_native_probe(&pdev) < 0);
		managed_cleanup();
		assert(!cam_cc_power.dev && !pdev.dev.references);
		assert(!region_count && !map_count && !regmap_count);
		assert(!operations && !reads && !writes);
	}
	native_environment(&pdev);
	static_node.dynamic = true;
	assert(cam_cc_native_probe(&pdev) == -EINVAL && !region_count);
	static_node.dynamic = false;
	static_node.power_domains = true;
	assert(cam_cc_native_probe(&pdev) == -EINVAL && !region_count);
	puts("Native CAMCC: acquisition/defer failures unwind before power; dynamic/foreign ownership refused");
}

static void retained_failures(void)
{
	struct platform_device pdev;
	for (int failure = 0; failure < 6; failure++) {
		native_environment(&pdev);
		if (failure == 0) regulators[0].enable_error = -EREMOTEIO;
		if (failure == 1) iface.error = -EAGAIN;
		if (failure == 2) registration_error = -ENOMEM;
		if (failure == 3) registration_error = -EPROBE_DEFER;
		if (failure == 4) reset_registration_error = -EEXIST;
		if (failure == 5) regulators[0].set_error = -EREMOTEIO;
		assert(cam_cc_native_probe(&pdev) == 0);
		assert(cam_cc_power.fault && cam_cc_native_probe_held);
		assert(pdev.dev.references == 1 && pdev.dev.power.usage_count == 1);
		assert(region_count == 1 && map_count == 1 && regmap_count == 1 && !releases);
		blocked_access(-EIO);
		managed_cleanup(); /* Includes a later core bind/sysfs failure. */
		dev_set_drvdata(&pdev.dev, NULL);
		pdev.dev.driver = NULL;
		assert(pdev.dev.references == 1 && !releases);
		assert(region_count == 1 && map_count == 1 && regmap_count == 1);
		blocked_access(-EIO);
		assert(cam_cc_native_probe(&pdev) == -EINVAL);
	}
	puts("Native CAMCC: partial power/publication and late core failure retain permanent backends without retry");
}

static void handoff_and_remove(void)
{
	struct platform_device pdev;
	native_environment(&pdev);
	assert(cam_cc_native_probe(&pdev) == 0 && cam_cc_native_published && reset_provider);
	assert(!cam_cc_native_probe_held && !pdev.dev.power.usage_count);
	sync_error = -EBUSY;
	cam_cc_native_sync_state(&pdev.dev);
	assert(cam_cc_native_proxy_active && !cam_cc_power.fault && !pdev.dev.power.usage_count);
	sync_error = 0;
	cam_cc_native_sync_state(&pdev.dev);
	assert(!cam_cc_native_proxy_active && !cam_cc_power.fault);
	assert(pdev.dev.ops->runtime_suspend(&pdev.dev) == 0);
	pdev.dev.suspended = true;
	assert(pm_runtime_resume_and_get(&pdev.dev) == 0);
	pm_runtime_put(&pdev.dev);
	cam_cc_native_remove(&pdev);
	assert(!reset_provider && cam_cc_power.fault && cam_cc_native_probe_held && barriers);
	managed_cleanup();
	assert(!releases && pdev.dev.references == 1);
	blocked_access(-EIO);
	puts("Native CAMCC: readiness-gated proxy handoff, PM cycle, remove and repeated detach preserve lifetime");
}

static void clock_controls(void)
{
	struct platform_device pdev;
	struct clk_hw *hw;
	const struct clk_ops *ops;
	int before;

	native_environment(&pdev);
	assert(cam_cc_native_probe(&pdev) == 0);
	cam_cc_native_sync_state(&pdev.dev);
	assert(pm_runtime_resume_and_get(&pdev.dev) == 0);
	hw = &clocks[0].hw;
	ops = cam_cc_native_inits[0].ops;
	assert(!hw->init && ops->prepare(hw) == 0 && prepared_calls == 1);
	hw->prepared = true;
	assert(ops->pre_rate_change(hw, 100000000, 900000000) == -EINVAL && !cam_cc_power.fault);
	assert(ops->pre_rate_change(hw, 100000000, 200000000) == 0);
	assert(ops->set_rate(hw, 200000000, 19200000) == 0);
	assert(ops->post_rate_change(hw, 100000000, 200000000) == 0);
	assert(ops->enable(hw) == 0 && hw->enabled);
	ops->disable(hw);
	assert(!hw->enabled && !cam_cc_power.fault);
	ops->unprepare(hw);
	assert(!cam_cc_power.fault);
	hw->prepared = false;
	hw = &clocks[3].hw;
	ops = cam_cc_native_inits[3].ops;
	assert(ops->prepare(hw) == 0);
	hw->prepared = true;
	assert(ops->set_parent(hw, 2) == -EINVAL && !cam_cc_power.fault);
	assert(ops->set_parent(hw, 1) == 0 && ops->get_parent(hw) == 1);
	hw->rate = 200000000;
	assert(ops->pre_rate_change(hw, 200000000, 100000000) == 0);
	assert(ops->set_rate_and_parent(hw, 100000000, 19200000, 0) == 0);
	assert(ops->post_rate_change(hw, 200000000, 100000000) == 0);
	program_error = -ETIMEDOUT;
	assert(ops->set_rate(hw, 100000000, 19200000) == -EIO);
	before = programmed_calls;
	assert(ops->prepare(hw) == -EIO);
	assert(ops->set_parent(hw, 0) == -EIO && programmed_calls == before);
	ops->unprepare(hw);
	assert(clocks[3].vdd_data.vdd_class->level_votes[clocks[3].vdd_data.vdd_level]);
	puts("Native CAMCC: actual voltage callbacks, original clock ops and fatal stale-active guards checked");
}

static void reset_controls(void)
{
	struct platform_device pdev;
	struct reset_controller_dev *rcdev;
	for (int failure = 0; failure < 4; failure++) {
		native_environment(&pdev);
		assert(cam_cc_native_probe(&pdev) == 0);
		rcdev = reset_provider;
		reset_fail_at = failure == 1 ? 1 : failure == 3 ? 2 : 0;
		reset_write_error = -EREMOTEIO;
		reset_read_error = failure == 2 ? -ENXIO : 0;
		assert(rcdev->ops->reset(rcdev, 0) == (failure ? -EIO : 0));
		if (failure) {
			assert(cam_cc_power.fault && cam_cc_native_probe_held);
			assert(pdev.dev.power.usage_count == 1);
			assert(sleeps == (failure == 3));
		} else {
			assert(!cam_cc_power.fault && !pdev.dev.power.usage_count && sleeps == 1);
		}
		cam_cc_native_remove(&pdev);
		assert((rcdev->ops->assert)(rcdev, 0) == -EIO);
		assert((rcdev->ops->assert)(rcdev, 2) == -EINVAL);
		assert(!releases && region_count == 1);
	}
	common_reset_calls = common_reset_error = 0;
	assert(common_reset_selection(false) == 0 && common_reset_calls == 1);
	common_reset_error = -ENOMEM;
	assert(common_reset_selection(true) == 0 && common_reset_calls == 1);
	assert(common_reset_selection(false) == -ENOMEM && common_reset_calls == 2);
	puts("Native CAMCC: real reset write/read/pulse errors, PM ownership and retained reset handles checked");
}

static pthread_mutex_t write_gate = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t write_ready = PTHREAD_COND_INITIALIZER;
static bool writer_entered, writer_allowed;
static atomic_int transaction_order;
static int write_order, fault_order;

static void hold_write(void)
{
	assert(pthread_mutex_lock(&write_gate) == 0);
	writer_entered = true;
	assert(pthread_cond_broadcast(&write_ready) == 0);
	while (!writer_allowed)
		assert(pthread_cond_wait(&write_ready, &write_gate) == 0);
	assert(pthread_mutex_unlock(&write_gate) == 0);
	write_order = atomic_fetch_add(&transaction_order, 1) + 1;
}

static void *concurrent_write(void *data)
{
	assert(cam_cc_power_write(&cam_cc_power, 0, 0x12345678) == 0);
	return NULL;
}

static void *concurrent_fault(void *data)
{
	assert(cam_cc_power_fail(-EREMOTEIO, -ENXIO, BIT(1)) == -EIO);
	fault_order = atomic_fetch_add(&transaction_order, 1) + 1;
	return NULL;
}

static void fault_transaction(void)
{
	struct platform_device pdev;
	pthread_t writer, fault;

	native_environment(&pdev);
	assert(cam_cc_native_probe(&pdev) == 0);
	write_hook = hold_write;
	atomic_store(&spin_waits, 0);
	assert(pthread_create(&writer, NULL, concurrent_write, NULL) == 0);
	assert(pthread_mutex_lock(&write_gate) == 0);
	while (!writer_entered)
		assert(pthread_cond_wait(&write_ready, &write_gate) == 0);
	assert(pthread_mutex_unlock(&write_gate) == 0);
	assert(pthread_create(&fault, NULL, concurrent_fault, NULL) == 0);
	while (!atomic_load(&spin_waits)) sched_yield();
	assert(pthread_mutex_lock(&write_gate) == 0);
	writer_allowed = true;
	assert(pthread_cond_broadcast(&write_ready) == 0);
	assert(pthread_mutex_unlock(&write_gate) == 0);
	assert(pthread_join(writer, NULL) == 0 && pthread_join(fault, NULL) == 0);
	write_hook = NULL;
	assert(write_order == 1 && fault_order == 2 && memory[0] == 0x12345678);
	assert(cam_cc_power.primary_error == -EREMOTEIO && cam_cc_power.rollback_error == -ENXIO);
	assert(cam_cc_power_fail(-EINVAL, 0, BIT(2)) == -EIO);
	assert(cam_cc_power.primary_error == -EREMOTEIO && cam_cc_power.rollback_error == -ENXIO);
	assert(cam_cc_power.uncertain_rails == (BIT(1) | BIT(2)));
	blocked_access(-EIO);
	puts("Native CAMCC: fault publication waits for in-flight MMIO and preserves the first failure");
}

int main(void)
{
	early_failures();
	retained_failures();
	handoff_and_remove();
	clock_controls();
	reset_controls();
	fault_transaction();
	return 0;
}
