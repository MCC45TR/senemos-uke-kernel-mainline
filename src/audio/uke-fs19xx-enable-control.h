/* SPDX-License-Identifier: GPL-2.0-only */
/* Included after the private FS19xx state and guard definitions. */
#ifndef UKE_FS19XX_ENABLE_CONTROL_H
#define UKE_FS19XX_ENABLE_CONTROL_H
#include "uke-fs19xx-readback.h"

static const char * const fs19xx_enable_names[] = {
	"Unavailable", "Both disabled", "RX only", "TX only", "RX and TX enabled", "Query failed",
};
static int fs19xx_enable_info(struct snd_kcontrol *kcontrol, struct snd_ctl_elem_info *info)
{
	(void)kcontrol;
	return snd_ctl_enum_info(info, 1, ARRAY_SIZE(fs19xx_enable_names), fs19xx_enable_names);
}
static int fs19xx_enable_get(struct snd_kcontrol *kcontrol, struct snd_ctl_elem_value *value)
{
	struct snd_soc_component *component = snd_kcontrol_chip(kcontrol);
	struct q6apm *apm = dev_get_drvdata(component->dev);
	struct q6apm_fs19xx *fs = apm->fs19xx;
	uke_fs_generation generation;
	unsigned long flags;
	unsigned int enabled = 0;
	bool running;
	int ret;

	value->value.enumerated.item[0] = 0;
	/* Routine desktop enumeration must not issue remote diagnostics. */
	if (!fs || !capable(CAP_SYS_RAWIO))
		return 0;
	guard(mutex)(&fs->lock);
	if (!fs->admitted || fs->removing || !fs->owner || fs->data.status != UKE_FS_RUNNING)
		return 0;
	spin_lock_irqsave(&fs19xx_guard_lock, flags);
	running = uke_fs_guard_running(&fs19xx_guard);
	generation = fs19xx_guard.generation;
	spin_unlock_irqrestore(&fs19xx_guard_lock, flags);
	if (!running)
		return 0;
	/* The owner mutex pins the graph until both bounded queries finish. */
	ret = q6apm_fs19xx_read_enables(apm, &enabled);
	spin_lock_irqsave(&fs19xx_guard_lock, flags);
	running = uke_fs_guard_running(&fs19xx_guard) && fs19xx_guard.generation == generation;
	spin_unlock_irqrestore(&fs19xx_guard_lock, flags);
	if (running)
		value->value.enumerated.item[0] = ret || enabled > 3 ? 5 : enabled + 1;
	return 0;
}

#define UKE_FS19XX_ENABLE_CONTROL \
	{ .iface = SNDRV_CTL_ELEM_IFACE_MIXER, .name = "FS19xx DSP Enable State", \
	  .access = SNDRV_CTL_ELEM_ACCESS_READ | SNDRV_CTL_ELEM_ACCESS_VOLATILE, \
	  .info = fs19xx_enable_info, .get = fs19xx_enable_get }
#endif
