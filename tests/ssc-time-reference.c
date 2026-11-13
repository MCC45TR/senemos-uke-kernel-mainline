/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include "count.inc"
typedef unsigned long long u64;
typedef unsigned int u32;
struct ssc_sensor {
	bool declared, ready, registered, stream_active;
	int error;
	u64 ticks, sample_sequence;
};
struct ssc_controller {
	int state;
	bool removed, paused, lookup_fault, client_open;
	unsigned int endpoint_count;
	u64 generation, client_generation;
	struct ssc_sensor sensor[SSC_SENSOR_COUNT];
};
struct device { struct ssc_controller *data; };
struct device_attribute {
	unsigned int mode;
	ssize_t (*show)(struct device *, struct device_attribute *, char *);
};
#define DEVICE_ATTR(name, permissions, callback, store) \
	struct device_attribute dev_attr_##name = { permissions, callback }
static unsigned int locks, unlocks, frequency_reads, counter_reads, time_reads;
static u32 frequency = 19200000;
static u64 counter = 100000, before = 200000, after = 200080;
static int *locked;
#define spin_lock_irqsave(lock, flags) do { \
	assert(!locked && *(lock) == 0);locked = (lock);*(lock) = 1; \
	(flags) = 42;locks++; \
} while (0)
#define spin_unlock_irqrestore(lock, flags) do { \
	assert(locked == (lock) && *(lock) == 1 && (flags) == 42); \
	*(lock) = 0;locked = NULL;unlocks++; \
} while (0)
static void *dev_get_drvdata(struct device *dev) { return dev->data; }
#if defined(CONFIG_ARM64) && defined(CONFIG_ARM_ARCH_TIMER)
static u32 arch_timer_get_cntfrq(void) {
	assert(locked);frequency_reads++;return frequency;
}
static u64 arch_timer_read_counter(void) {
	assert(locked);counter_reads++;return counter;
}
static u64 ktime_get_boottime_ns(void) {
	assert(locked);return ++time_reads == 1 ? before : after;
}
#endif
#define PAGE_SIZE 4096
static int emit(char *buf, int at, const char *format, va_list args) {
	assert(!locked && at >= 0 && at < PAGE_SIZE);
	const int n = vsnprintf(buf + at, PAGE_SIZE - (unsigned int)at, format, args);
	assert(n >= 0 && n < PAGE_SIZE - at);return n;
}
static int sysfs_emit(char *buf, const char *format, ...) {
	va_list args;va_start(args, format);const int n = emit(buf, 0, format, args);
	va_end(args);return n;
}
static int sysfs_emit_at(char *buf, int at, const char *format, ...) {
	va_list args;va_start(args, format);const int n = emit(buf, at, format, args);
	va_end(args);return n;
}
#include "callbacks.inc"
static void check(struct ssc_controller *c) {
	const struct ssc_controller original = *c;
	char buf[PAGE_SIZE + 16];memset(buf, 0xa5, sizeof buf);
	struct device dev = { c };
	locks = unlocks = frequency_reads = counter_reads = time_reads = 0;
	const ssize_t bytes = ssc_time_reference_show(&dev, NULL, buf);
	assert(bytes > 0 && bytes < PAGE_SIZE && locks == 1 && unlocks == 1 && !locked);
	assert(!memcmp(c, &original, sizeof original));
	assert(buf[bytes] == 0);
	for (size_t i = PAGE_SIZE; i < sizeof buf; i++) assert((unsigned char)buf[i] == 0xa5);
	unsigned int schema, admitted, connected, available, hz, count;
	u64 generation, ticks, t0, t1;
	assert(sscanf(buf, "schema=%u admitted=%u generation=%llu connected=%u reference_available=%u "
		"cntfrq_hz=%u linux_arch_counter=%llu boottime_before_ns=%llu "
		"boottime_after_ns=%llu sensor_count=%u", &schema, &admitted, &generation,
		&connected, &available, &hz, &ticks, &t0, &t1, &count) == 10);
	assert(schema == 1 && admitted == 0 && generation == c->generation && count == SSC_SENSOR_COUNT);
	assert(connected == ssc_current(c));
#if defined(CONFIG_ARM64) && defined(CONFIG_ARM_ARCH_TIMER)
	assert(frequency_reads == connected && counter_reads == connected && time_reads == 2 * connected);
	assert(hz == (connected ? frequency : 0));
	assert(ticks == (connected ? counter : 0));
	assert(t0 == (connected ? before : 0) && t1 == (connected ? after : 0));
	assert(available == (connected && frequency && counter && after >= before));
#else
	assert(!frequency_reads && !counter_reads && !time_reads);
	assert(!available && !hz && !ticks && !t0 && !t1);
#endif
	char *line = strchr(buf, '\n');assert(line);line++;
	for (unsigned int i = 0; i < SSC_SENSOR_COUNT; i++) {
		unsigned int index, valid, active;u64 sequence, sensor_ticks;
		assert(sscanf(line, "sensor=%u cached_valid=%u stream_active=%u sequence=%llu sensor_ticks=%llu",
			&index, &valid, &active, &sequence, &sensor_ticks) == 5);
		const struct ssc_sensor *s = &c->sensor[i];
		const bool expected = connected && s->declared && s->ready && s->registered &&
			!s->error && s->ticks && s->sample_sequence;
		assert(index == i && valid == expected && active == (expected && s->stream_active));
		assert(sequence == (expected ? s->sample_sequence : 0));
		assert(sensor_ticks == (expected ? s->ticks : 0));
		line = strchr(line, '\n');assert(line);line++;
	}
	assert(!*line);
}
int main(void) {
	struct ssc_controller c = {.client_open = true, .endpoint_count = 1,
		.generation = 4, .client_generation = 4};
	for (unsigned int i = 0; i < SSC_SENSOR_COUNT; i++)
		c.sensor[i] = (struct ssc_sensor){.declared = true, .ready = true,
			.registered = true, .stream_active = true, .ticks = i + 1, .sample_sequence = i + 2};
	assert(dev_attr_ssc_time_reference.mode == 0400);
	assert(dev_attr_ssc_time_reference.show == ssc_time_reference_show);
	check(&c);
	c.removed = true;check(&c);c.removed = false;
	c.paused = true;check(&c);c.paused = false;
	c.lookup_fault = true;check(&c);c.lookup_fault = false;
	c.client_open = false;check(&c);c.client_open = true;
	c.endpoint_count = 2;check(&c);c.endpoint_count = 1;
	c.client_generation = 3;check(&c);c.client_generation = 4;
	for (unsigned int i = 0; i < SSC_SENSOR_COUNT; i++) {
		struct ssc_sensor *s = &c.sensor[i];const struct ssc_sensor good = *s;
		s->declared = false;check(&c);*s = good;
		s->ready = false;check(&c);*s = good;
		s->registered = false;check(&c);*s = good;
		s->error = -5;check(&c);*s = good;
		s->ticks = 0;check(&c);*s = good;
		s->sample_sequence = 0;check(&c);*s = good;
		s->stream_active = false;check(&c);*s = good;
		s->ticks = s->sample_sequence = UINT64_MAX;check(&c);*s = good;
	}
	c.generation = c.client_generation = UINT64_MAX;
	for (unsigned int i = 0; i < SSC_SENSOR_COUNT; i++)
		c.sensor[i].ticks = c.sensor[i].sample_sequence = UINT64_MAX;
	check(&c);
	frequency = 0;check(&c);frequency = 19200000;
	counter = 0;check(&c);counter = UINT64_MAX;
	before = 200;after = 100;check(&c);
	before = after = UINT64_MAX;check(&c);
	puts("Actual SSC time-reference callback:root0400,clock brackets,all cache/generation states,bounds and no state mutation pass;mapping unadmitted");
}
