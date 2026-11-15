/* SPDX-License-Identifier: GPL-2.0-only */
/* Quad program-channel mapping; calibration and feedback stay physical. */
#include "uke-speaker-display.h"
#include "uke-speaker-quad.h"
#include <sound/uke-fs19xx-guard.h>

static const char * const uke_display_angles[] = { "0", "90", "180", "270" };
static SOC_ENUM_SINGLE_EXT_DECL(uke_display_enum, uke_display_angles);

static int uke_display_get_amp(void *context, unsigned int amplifier,
			       unsigned int *turn)
{
	struct uke_speaker_data *data = context;
	struct snd_ctl_elem_value value = {};
	int ret;

	ret = data->rotation_controls[amplifier]->get(
		data->rotation_controls[amplifier], &value);
	if (ret < 0)
		return ret;
	*turn = value.value.enumerated.item[0];
	return 0;
}

static int uke_display_set_amp(void *context, unsigned int amplifier,
			       unsigned int turn)
{
	struct uke_speaker_data *data = context;
	struct snd_ctl_elem_value value = {};
	struct snd_kcontrol *control = data->rotation_controls[amplifier];
	int ret;

	value.value.enumerated.item[0] = turn;
	ret = control->put(control, &value);
	if (ret > 0)
		snd_ctl_notify(data->card->snd_card,
			       SNDRV_CTL_EVENT_MASK_VALUE, &control->id);
	return ret;
}

static void uke_display_route_fault(void *context)
{
	(void)context;
	/* Existing notifier path mutes all amplifiers and retains the fault latch. */
	q6apm_fs19xx_fault();
}


static int uke_display_get_turn(struct uke_speaker_data *data, unsigned int *turn)
{
	unsigned int tx_num = 0, rx_num = 0, tx[4] = {}, rx[4] = {};
	int ret;

	ret = snd_soc_dai_get_channel_map(data->rotation_dai, &tx_num, tx, &rx_num, rx);
	if (ret < 0)
		return ret;
	if (tx_num)
		return -EINVAL;
	ret = uke_quad_turn(rx, rx_num);
	if (ret < 0)
		return ret;
	*turn = ret;
	return 0;
}

static int uke_display_set_turn(struct uke_speaker_data *data, unsigned int turn)
{
	if (turn > 3)
		return -EINVAL;
	return snd_soc_dai_set_channel_map(data->rotation_dai, 0, NULL, 4,
					 uke_quad_sources[turn]);
}

static int uke_display_get(struct snd_kcontrol *control,
			   struct snd_ctl_elem_value *value)
{
	struct snd_soc_card *card = snd_kcontrol_chip(control);
	struct uke_speaker_data *data = snd_soc_card_get_drvdata(card);
	unsigned int turn, codec, i;
	int ret;

	guard(mutex)(&data->rotation_lock);
	ret = uke_display_get_turn(data, &turn);
	if (ret < 0)
		return ret;
	for (i = 0; i < UKE_DISPLAY_SPEAKERS; i++) {
		ret = uke_display_get_amp(data, i, &codec);
		if (ret < 0)
			return ret;
		if (codec != 0)
			return -EUCLEAN;
	}
	value->value.enumerated.item[0] = turn;
	return 0;
}

static int uke_display_put(struct snd_kcontrol *control,
			   struct snd_ctl_elem_value *value)
{
	struct snd_soc_card *card = snd_kcontrol_chip(control);
	struct uke_speaker_data *data = snd_soc_card_get_drvdata(card);
	unsigned int before[4], old_turn, actual, i;
	unsigned int target = value->value.enumerated.item[0];
	bool rollback_failed = false;
	int ret, first_error, changed = 0;

	if (target > 3)
		return -EINVAL;
	guard(mutex)(&data->rotation_lock);
	ret = uke_display_get_turn(data, &old_turn);
	if (ret < 0)
		return ret;
	for (i = 0; i < 4; i++) {
		ret = uke_display_get_amp(data, i, &before[i]);
		if (ret < 0)
			return ret;
		if (before[i] > 3)
			return -EPROTO;
	}
	ret = uke_display_set_turn(data, target);
	if (ret < 0)
		goto rollback;
	changed = target != old_turn;
	/* Program material rotates in MFC. Keep every physical amplifier at its
	 * canonical channel selection, with its original calibration and VI path. */
	for (i = 0; i < 4; i++) {
		if (before[i] == 0)
			continue;
		ret = uke_display_set_amp(data, i, 0);
		if (ret < 0)
			goto rollback;
		changed = 1;
	}
	ret = uke_display_get_turn(data, &actual);
	if (ret < 0 || actual != target) {
		if (ret >= 0)
			ret = -EIO;
		goto rollback;
	}
	for (i = 0; i < 4; i++) {
		ret = uke_display_get_amp(data, i, &actual);
		if (ret < 0 || actual != 0) {
			if (ret >= 0)
				ret = -EIO;
			goto rollback;
		}
	}
	return changed;
rollback:
	first_error = ret;
	if (uke_display_set_turn(data, old_turn) < 0)
		rollback_failed = true;
	for (i = 0; i < 4; i++) {
		if (uke_display_set_amp(data, i, before[i]) < 0)
			rollback_failed = true;
		if (uke_display_get_amp(data, i, &actual) < 0 || actual != before[i])
			rollback_failed = true;
	}
	if (uke_display_get_turn(data, &actual) < 0 || actual != old_turn)
		rollback_failed = true;
	if (rollback_failed)
		uke_display_route_fault(data);
	return first_error;
}

static const struct snd_kcontrol_new uke_display_control =
	SOC_ENUM_EXT("Speaker Display Rotation", uke_display_enum,
		     uke_display_get, uke_display_put);

static int uke_speaker_display_init(struct snd_soc_card *card)
{
	static const char * const prefixes[] = {
		"TopLeft", "TopRight", "BottomLeft", "BottomRight"
	};
	struct uke_speaker_data *data = snd_soc_card_get_drvdata(card);
	struct snd_ctl_elem_info *info;
	struct snd_soc_pcm_runtime *rtd;
	char name[64];
	unsigned int i, item;
	int ret;

	info = kzalloc(sizeof(*info), GFP_KERNEL);
	if (!info)
		return -ENOMEM;
	for (i = 0; i < UKE_DISPLAY_SPEAKERS; i++) {
		snprintf(name, sizeof(name), "%s Speaker Rotation", prefixes[i]);
		data->rotation_controls[i] = snd_soc_card_get_kcontrol(card, name);
		if (!data->rotation_controls[i] || !data->rotation_controls[i]->get ||
		    !data->rotation_controls[i]->put || !data->rotation_controls[i]->info) {
			ret = -ENODEV;
			goto out;
		}
		for (item = 0; item < 4; item++) {
			memset(info, 0, sizeof(*info));
			info->value.enumerated.item = item;
			ret = data->rotation_controls[i]->info(data->rotation_controls[i], info);
			if (ret < 0)
				goto out;
			if (info->type != SNDRV_CTL_ELEM_TYPE_ENUMERATED || info->count != 1 ||
			    info->value.enumerated.items != 4 ||
			    strcmp(info->value.enumerated.name, uke_display_angles[item])) {
				ret = -EPROTO;
				goto out;
			}
		}
	}
	for_each_card_rtds(card, rtd) {
		struct snd_soc_dai *cpu = snd_soc_rtd_to_cpu(rtd, 0);

		if (!rtd->dai_link->no_pcm || cpu->id != SECONDARY_TDM_RX_0)
			continue;
		if (data->rotation_dai || !cpu->driver->ops ||
		    !cpu->driver->ops->set_channel_map ||
		    !cpu->driver->ops->get_channel_map) {
			ret = -EINVAL;
			goto out;
		}
		data->rotation_dai = cpu;
	}
	if (!data->rotation_dai) {
		ret = -ENODEV;
		goto out;
	}
	data->card = card;
	ret = snd_soc_add_card_controls(card, &uke_display_control, 1);
out:
	kfree(info);
	return ret;
}
