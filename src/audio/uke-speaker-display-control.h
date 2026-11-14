/* SPDX-License-Identifier: GPL-2.0-only */
/* Included by the Uke machine driver after struct uke_speaker_data. */
#include "uke-speaker-display.h"
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

static const struct uke_display_route_ops uke_display_ops = {
	.get = uke_display_get_amp,
	.set = uke_display_set_amp,
	.fault = uke_display_route_fault,
};

static int uke_display_get(struct snd_kcontrol *control,
			   struct snd_ctl_elem_value *value)
{
	struct snd_soc_card *card = snd_kcontrol_chip(control);
	struct uke_speaker_data *data = snd_soc_card_get_drvdata(card);
	unsigned int turn, other, i;
	int ret;

	guard(mutex)(&data->rotation_lock);
	ret = uke_display_get_amp(data, 0, &turn);
	if (ret < 0)
		return ret;
	if (turn > 3)
		return -EPROTO;
	for (i = 1; i < UKE_DISPLAY_SPEAKERS; i++) {
		ret = uke_display_get_amp(data, i, &other);
		if (ret < 0)
			return ret;
		if (turn != other)
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

	guard(mutex)(&data->rotation_lock);
	return uke_display_route(data, &uke_display_ops,
				 value->value.enumerated.item[0]);
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
	data->card = card;
	ret = snd_soc_add_card_controls(card, &uke_display_control, 1);
out:
	kfree(info);
	return ret;
}
