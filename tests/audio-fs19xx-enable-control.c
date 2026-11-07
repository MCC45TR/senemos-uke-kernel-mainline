/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual ALSA getter with synthetic lifecycle/transport; no audio or unit data. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "uke-fs19xx-protocol.h"
#include "uke-fs19xx-safety.h"
struct mutex { bool held; };
static void mutex_lock(struct mutex *p) { assert(!p->held); p->held = true; }
static void mutex_unlock(struct mutex *p) { assert(p->held); p->held = false; }
static struct mutex *take_lock(struct mutex *p) { mutex_lock(p); return p; }
static void drop_lock(struct mutex **p) { mutex_unlock(*p); }
#define guard(t) struct mutex *held_guard __attribute__((cleanup(drop_lock))) = take_lock
#define ARRAY_SIZE(v) (sizeof(v)/sizeof((v)[0]))
#define CAP_SYS_RAWIO 17
struct q6apm_fs19xx {
	struct mutex lock;
	struct uke_fs19xx_state data;
	void *owner;
	bool removing, admitted;
};
struct q6apm { struct q6apm_fs19xx *fs19xx; };
struct device { struct q6apm *data; };
struct snd_soc_component { struct device *dev; };
struct snd_kcontrol { struct snd_soc_component *component; };
struct snd_ctl_elem_info { unsigned int items; };
struct snd_ctl_elem_value { union { struct { unsigned int item[1]; } enumerated; } value; };
static struct snd_soc_component *snd_kcontrol_chip(struct snd_kcontrol *p) { return p->component; }
static struct q6apm *dev_get_drvdata(struct device *p) { return p->data; }
static int snd_ctl_enum_info(struct snd_ctl_elem_info *info, unsigned int count,
		unsigned int items, const char * const *names)
{
	assert(count == 1 && items == 6 && !strcmp(names[0], "Unavailable"));
	info->items = items;
	return 0;
}
static bool privileged;
static bool __attribute__((unused)) capable(int cap) { assert(cap == CAP_SYS_RAWIO); return privileged; }
static struct mutex fs19xx_guard_lock;
static struct uke_fs_guard fs19xx_guard;
static struct q6apm_fs19xx *expected_fs;
static unsigned int query_calls, reply_mask, during;
static int reply_error;
static void take_guard(struct mutex *p)
{
	assert(expected_fs->lock.held);
	mutex_lock(p);
}
#define spin_lock_irqsave(p,f) ((f)=0,take_guard(p))
#define spin_unlock_irqrestore(p,f) ((void)(f),mutex_unlock(p))
static int q6apm_fs19xx_read_enables(struct q6apm *apm, unsigned int *mask)
{
	assert(apm->fs19xx == expected_fs && expected_fs->lock.held && !fs19xx_guard_lock.held);
	query_calls++;
	if (during == 1) uke_fs_guard_trip(&fs19xx_guard);
	if (during == 2) fs19xx_guard.mode = 1;
	if (during == 3) fs19xx_guard.generation++;
	*mask = reply_mask;
	return reply_error;
}
#include "uke-fs19xx-enable-control.h"
#define SNDRV_CTL_ELEM_IFACE_MIXER 2
#define SNDRV_CTL_ELEM_ACCESS_READ 1
#define SNDRV_CTL_ELEM_ACCESS_VOLATILE 4
struct snd_kcontrol_new {
	int iface, access;
	const char *name;
	int (*info)(struct snd_kcontrol *, struct snd_ctl_elem_info *);
	int (*get)(struct snd_kcontrol *, struct snd_ctl_elem_value *);
	void *put;
};
static const struct snd_kcontrol_new actual_control = UKE_FS19XX_ENABLE_CONTROL;

int main(void)
{
	struct q6apm_fs19xx fs = {0};
	struct q6apm apm = {&fs};
	struct device dev = {&apm};
	struct snd_soc_component component = {&dev};
	struct snd_kcontrol control = {&component};
	struct snd_ctl_elem_value value = {0};
	struct snd_ctl_elem_info info = {0};
	unsigned int state, bits, mode, cases = 0;
	expected_fs = &fs;
	assert(actual_control.iface == SNDRV_CTL_ELEM_IFACE_MIXER && actual_control.access == 5 &&
	       !actual_control.put && !strcmp(actual_control.name, "FS19xx DSP Enable State"));
	assert(!fs19xx_enable_info(&control, &info) && info.items == 6);
	/* Only one fully active privileged state may send a remote query. */
	for (state = UKE_FS_EMPTY; state <= UKE_FS_FAULT; state++)
	for (bits = 0; bits < 32; bits++)
	for (mode = 0; mode <= 2; mode++) {
		fs.data.status = state;
		fs.admitted = bits & 1; fs.removing = bits & 2;
		fs.owner = bits & 4 ? &apm : NULL;
		privileged = bits & 8;
		fs19xx_guard = (struct uke_fs_guard){.generation=17,.mode=mode,.faulted=bits&16};
		query_calls = 0; reply_mask = 3; reply_error = 0; during = 0;
		value.value.enumerated.item[0] = 99;
		assert(!fs19xx_enable_get(&control, &value));
		bool active = state == UKE_FS_RUNNING && bits == 13 && mode == 2;
		assert(query_calls == (active ? 1U : 0U));
		assert(value.value.enumerated.item[0] == (active ? 4U : 0U));
		assert(!fs.lock.held && !fs19xx_guard_lock.held);
		cases++;
	}
	fs.admitted = privileged = true; fs.removing = false; fs.owner = &apm;
	fs.data.status = UKE_FS_RUNNING;
	for (unsigned int mask = 0; mask < 5; mask++)
	for (unsigned int error = 0; error < 2; error++)
	for (during = 0; during < 4; during++) {
		fs19xx_guard = (struct uke_fs_guard){.generation=17,.mode=2};
		query_calls = 0; reply_mask = mask; reply_error = error ? -ETIMEDOUT : 0;
		assert(!fs19xx_enable_get(&control, &value));
		assert(query_calls == 1);
		unsigned int expected = during ? 0 : (error || mask > 3 ? 5 : mask + 1);
		assert(value.value.enumerated.item[0] == expected);
		assert(!fs.lock.held && !fs19xx_guard_lock.held);
		cases++;
	}
	apm.fs19xx = NULL;
	assert(!fs19xx_enable_get(&control, &value) && !value.value.enumerated.item[0]);
	cases++;
	printf("Actual FS19xx enable getter: %u lifecycle cases passed.\n", cases);
	return 0;
}
