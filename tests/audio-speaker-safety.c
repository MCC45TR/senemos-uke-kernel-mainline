/* SPDX-License-Identifier: GPL-2.0-only */
/* Register fixtures are synthetic. No device calibration or hardware access. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <limits.h>
#include "uke-fs19xx-safety.h"
#define BIT(n) (1U << (n))
#define GENMASK(h, l) ((UINT_MAX >> (31 - (h))) & (UINT_MAX << (l)))
#include "codec-definitions.h"

struct work_struct { int unused; };
struct delayed_work { struct work_struct work; };
struct fake_bus {
	unsigned int reg[256];
	unsigned int operations, reads, fail_at, drop_gate_at_read;
	unsigned int runs, writes, resets;
	bool ignore_sensor_write, sensing_verified, unsafe_run;
};
struct fs19xx_priv {
	struct fake_bus *regmap;
	void *dev;
	struct fake_bus *gpio_reset;
	int lock;
	struct delayed_work unmute_work;
	unsigned int volume, pll_polls;
	bool powered, unmuted, require_protection;
};
struct snd_soc_component { struct fs19xx_priv *data; };
struct snd_kcontrol { struct snd_soc_component *component; };
struct snd_ctl_elem_value { struct { struct { long value[1]; } integer; } value; };
static struct snd_soc_component *snd_kcontrol_chip(struct snd_kcontrol *control)
{
	return control->component;
}
static struct fs19xx_priv *snd_soc_component_get_drvdata(struct snd_soc_component *component)
{
	return component->data;
}
static bool configured, running;
static unsigned int faults, next_delay, cancellations;
static bool q6apm_fs19xx_configured(void) { return configured; }
static bool q6apm_fs19xx_running(void) { return running; }
static void q6apm_fs19xx_fault(void) { faults++; configured = false; running = false; }
static int regmap_read(struct fake_bus *bus, unsigned int reg, unsigned int *value)
{
	bus->operations++;
	bus->reads++;
	if (bus->reads == bus->drop_gate_at_read) running = false;
	if (bus->operations == bus->fail_at) return -EIO;
	*value = bus->reg[reg];
	if (reg == FS19XX_REG_TSCTRL)
		bus->sensing_verified = !!(*value & FS19XX_TSCTRL_TSEN);
	return 0;
}
static int regmap_write(struct fake_bus *bus, unsigned int reg, unsigned int value)
{
	bus->operations++;
	if (bus->operations == bus->fail_at) return -EIO;
	bus->writes++;
	if (reg == FS19XX_REG_DACCTRL && value == FS19XX_DACCTRL_RUN) {
		bus->runs++;
		if (!bus->sensing_verified) bus->unsafe_run = true;
	}
	if (!(reg == FS19XX_REG_TSCTRL && bus->ignore_sensor_write))
		bus->reg[reg] = value;
	return 0;
}
static void gpiod_set_value_cansleep(struct fake_bus *bus, int asserted)
{
	assert(asserted == 1);
	bus->resets++;
}
static void msleep(unsigned int ms) { (void)ms; }
static void mod_delayed_work(void *queue, struct delayed_work *work, unsigned int ms)
{
	(void)queue; (void)work;
	next_delay = ms;
}
static void cancel_delayed_work(struct delayed_work *work)
{
	(void)work;
	cancellations++;
	next_delay = 0;
}
#define system_percpu_wq NULL
#define msecs_to_jiffies(ms) (ms)
#define guard(kind) (void)
#define dev_err(...) ((void)0)
#define container_of(p, type, member) ((type *)((char *)(p) - offsetof(type, member)))
#define to_delayed_work(p) container_of(p, struct delayed_work, work)
#include "codec-under-test.h"

static struct fs19xx_priv initial(struct fake_bus *bus)
{
	memset(bus, 0, sizeof(*bus));
	bus->reg[FS19XX_REG_STATUS] = FS19XX_STATUS_PLLS;
	bus->reg[FS19XX_REG_DACCTRL] = FS19XX_DACCTRL_MUTE;
	bus->reg[FS19XX_REG_SYSCTRL] = FS19XX_SYSCTRL_ALL_ON;
	bus->reg[FS19XX_REG_VOLCTRL] = (223U << 8) | 0xc0;
	configured = true; running = true;
	faults = 0; next_delay = 0; cancellations = 0;
	return (struct fs19xx_priv){.regmap = bus, .gpio_reset = bus,
		.volume = 223, .powered = true, .require_protection = true};
}
static void tick(struct fs19xx_priv *fs)
{
	next_delay = 0;
	fs19xx_unmute_work(&fs->unmute_work.work);
}
static void assert_stopped(struct fs19xx_priv *fs, struct fake_bus *bus)
{
	assert(!fs->powered && !fs->unmuted && faults == 1);
	assert(bus->resets == 1 && !running && !configured && next_delay == 0);
	unsigned int operations = bus->operations;
	tick(fs);
	assert(bus->operations == operations && bus->resets == 1);
}
static void startup_tests(void)
{
	struct fake_bus bus;
	struct fs19xx_priv fs = initial(&bus);
	assert(fs19xx_unmute_output(&fs) == 0);
	assert(bus.runs == 1 && bus.sensing_verified && !bus.unsafe_run);
	unsigned int operations = bus.operations, reads = bus.reads;
	for (unsigned int failure = 1; failure <= operations; failure++) {
		fs = initial(&bus); bus.fail_at = failure;
		assert(fs19xx_unmute_output(&fs) < 0 && bus.runs == 0);
	}
	for (unsigned int read = 1; read <= reads; read++) {
		fs = initial(&bus); bus.drop_gate_at_read = read;
		assert(fs19xx_unmute_output(&fs) < 0 && bus.runs == 0);
	}
	fs = initial(&bus); bus.ignore_sensor_write = true;
	tick(&fs); assert(bus.runs == 0); assert_stopped(&fs, &bus);
	fs = initial(&bus); running = false;
	tick(&fs); assert(fs.powered && !fs.unmuted && bus.runs == 0 && next_delay == FS19XX_LOCK_POLL_MS);
	configured = false; tick(&fs); assert_stopped(&fs, &bus);
	fs = initial(&bus); bus.reg[FS19XX_REG_STATUS] = 0;
	for (unsigned int i = 0; i < FS19XX_LOCK_POLL_COUNT; i++) tick(&fs);
	assert(bus.runs == 0); assert_stopped(&fs, &bus);
}
static void live_tests(void)
{
	struct fake_bus bus;
	struct fs19xx_priv fs = initial(&bus);
	tick(&fs);
	assert(fs.unmuted && bus.runs == 1 && next_delay == FS19XX_HEALTH_POLL_MS);
	tick(&fs);
	assert(fs.unmuted && bus.runs == 1 && next_delay == FS19XX_HEALTH_POLL_MS);
	unsigned int operations = bus.operations;
	fs19xx_power_off(&fs);
	assert(!fs.powered && !fs.unmuted && cancellations == 1 && bus.resets == 1);
	assert(bus.operations > operations && next_delay == 0);
	operations = bus.operations; tick(&fs); assert(bus.operations == operations);
	const unsigned int reg[] = {FS19XX_REG_STATUS, FS19XX_REG_TSCTRL, FS19XX_REG_PWRCTRL,
		FS19XX_REG_SYSCTRL, FS19XX_REG_VOLCTRL, FS19XX_REG_DACCTRL};
	const unsigned int bad[] = {0, 0, FS19XX_PWRCTRL_PWDN, 0, (243U << 8) | 0xc0,
		FS19XX_DACCTRL_MUTE};
	for (size_t i = 0; i < sizeof(reg) / sizeof(reg[0]); i++) {
		fs = initial(&bus); tick(&fs); assert(fs.unmuted);
		bus.reg[reg[i]] = bad[i]; tick(&fs);
		assert_stopped(&fs, &bus);
		assert(bus.runs == 1); // no repair/re-unmute after a live fault
	}
	fs = initial(&bus); tick(&fs); bus.fail_at = bus.operations + 1; tick(&fs);
	assert_stopped(&fs, &bus);
	fs = initial(&bus); tick(&fs); running = false; tick(&fs);
	assert_stopped(&fs, &bus);
}
static void gain_tests(void)
{
	struct fake_bus bus;
	assert(FS19XX_VOL_MAX == 223 && FS19XX_VOL_DEFAULT == 223);
	for (unsigned int value = 0; value <= 255; value++) {
		struct fs19xx_priv fs = initial(&bus);
		int ret = fs19xx_set_volume_reg(&fs, value);
		if (value <= 223) assert(ret == 0 && bus.writes == 1);
		else assert(ret == -ERANGE && bus.writes == 0);
	}
	struct fs19xx_priv fs = initial(&bus);
	assert(fs19xx_set_volume_reg(&fs, UINT_MAX) == -ERANGE && !bus.writes);
	// Even a prepared/running DSP and enabled sensor cannot authorize 243.
	fs.volume = 243;
	bus.reg[FS19XX_REG_VOLCTRL] = (243U << 8) | 0xc0;
	assert(fs19xx_unmute_output(&fs) == -ERANGE && !bus.runs);
	fs = initial(&bus);
	struct snd_soc_component component = {.data = &fs};
	struct snd_kcontrol mixer = {.component = &component};
	struct snd_ctl_elem_value request = {.value.integer.value = {243}};
	assert(fs19xx_volume_put(&mixer, &request) == -EINVAL && !bus.writes);
	request.value.integer.value[0] = -1;
	assert(fs19xx_volume_put(&mixer, &request) == -EINVAL && !bus.writes);
	request.value.integer.value[0] = 222;
	assert(fs19xx_volume_put(&mixer, &request) == 1 && fs.volume == 222);
	fs = initial(&bus); bus.fail_at = 1;
	assert(fs19xx_volume_put(&mixer, &request) == -EIO && fs.volume == 223);
	assert_stopped(&fs, &bus);
}
static void guard_tests(void)
{
	struct uke_fs_guard state = {0};
	assert(!uke_fs_guard_configured(&state) && !uke_fs_guard_running(&state));
	assert(uke_fs_guard_mode(&state, 1) == 0 && uke_fs_guard_configured(&state));
	assert(!uke_fs_guard_running(&state));
	assert(uke_fs_guard_mode(&state, 2) == 0 && uke_fs_guard_running(&state));
	assert(uke_fs_guard_reprovision(&state, state.generation) == -EAGAIN);
	for (unsigned int fault = 0; fault < 1024; fault++) {
		uke_fs_generation old = state.generation; // transaction BEGIN ticket
		uke_fs_guard_trip(&state);
		assert(state.faulted && !state.mode && state.generation != old);
		assert(uke_fs_guard_mode(&state, 2) == -EIO);
		assert(uke_fs_guard_mode(&state, 0) == 0 && state.faulted);
		assert(uke_fs_guard_reprovision(&state, old) == -EAGAIN && state.faulted);
		uke_fs_generation fresh = state.generation;
		assert(uke_fs_guard_reprovision(&state, fresh) == 0);
		assert(!state.faulted && !uke_fs_guard_running(&state));
		assert(uke_fs_guard_mode(&state, 2) == 0);
		// A fault after COMMIT also defeats later arming; stopping never clears it.
		uke_fs_guard_trip(&state);
		assert(!uke_fs_guard_running(&state) && uke_fs_guard_mode(&state, 1) == -EIO);
	}
}
int main(void)
{
	startup_tests(); live_tests(); gain_tests(); guard_tests();
	puts("Actual FS19xx codec safety fixtures passed; 243 remains rejected.");
	return 0;
}
