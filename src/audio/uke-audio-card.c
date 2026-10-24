// SPDX-License-Identifier: GPL-2.0-only
/* Uke DisplayPort playback and the separate closed registration profile. */
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <dt-bindings/sound/qcom,q6dsp-lpass-ports.h>
#include <sound/jack.h>
#include <sound/pcm_params.h>
#include <sound/soc.h>
#include "common.h"

static int uke_hdmi_late_probe(struct snd_soc_card *card)
{
	struct snd_soc_pcm_runtime *rtd;
	unsigned int frontends = 0, backends = 0;

	for_each_card_rtds(card, rtd) {
		struct snd_soc_dai *cpu = snd_soc_rtd_to_cpu(rtd, 0);

		if (rtd->dai_link->no_pcm) {
			if (cpu->id != DISPLAY_PORT_RX_0)
				return -EINVAL;
			backends++;
		} else {
			if (!rtd->dai_link->dynamic || cpu->id != 0 ||
			    cpu->driver->capture.channels_min)
				return -EINVAL;
			frontends++;
		}
	}
	return frontends == 1 && backends == 1 ? 0 : -EINVAL;
}

static int uke_hdmi_init(struct snd_soc_pcm_runtime *rtd)
{
	return qcom_snd_dp_jack_setup(rtd, snd_soc_card_get_drvdata(rtd->card), 0);
}

static int uke_hdmi_fixup(struct snd_soc_pcm_runtime *rtd,
			  struct snd_pcm_hw_params *params)
{
	struct snd_interval *rate = hw_param_interval(params, SNDRV_PCM_HW_PARAM_RATE);
	struct snd_interval *channels = hw_param_interval(params, SNDRV_PCM_HW_PARAM_CHANNELS);
	struct snd_mask *format = hw_param_mask(params, SNDRV_PCM_HW_PARAM_FORMAT);

	rate->min = rate->max = 48000;
	channels->min = channels->max = 2;
	snd_mask_none(format);
	snd_mask_set_format(format, SNDRV_PCM_FORMAT_S16_LE);
	return 0;
}

static int uke_hdmi_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct snd_soc_dai_link *link;
	struct snd_soc_card *card;
	struct snd_soc_jack *jack;
	struct device_node *frontend;
	int ret;

	card = devm_kzalloc(dev, sizeof(*card), GFP_KERNEL);
	jack = devm_kzalloc(dev, sizeof(*jack), GFP_KERNEL);
	if (!card || !jack)
		return -ENOMEM;
	card->dev = dev;
	card->owner = THIS_MODULE;
	card->driver_name = "sm7675";
	card->late_probe = uke_hdmi_late_probe;
	snd_soc_card_set_drvdata(card, jack);
	ret = qcom_snd_parse_of(card);
	if (ret)
		return ret;
	if (card->num_links != 1 || card->num_aux_devs ||
	    strcmp(card->name, "POCO-Pad-X1-HDMI"))
		return -EINVAL;
	link = card->dai_link;
	if (!link->no_pcm || link->id != DISPLAY_PORT_RX_0 ||
	    link->num_cpus != 1 || link->num_codecs != 1 || link->num_platforms != 1 ||
	    !of_device_is_compatible(link->cpus[0].of_node, "qcom,q6apm-lpass-dais") ||
	    !of_device_is_compatible(link->platforms[0].of_node, "qcom,q6apm") ||
	    !of_device_is_compatible(link->codecs[0].of_node, "qcom,sm7675-dp") ||
	    link->cpus[0].of_node->parent != link->platforms[0].of_node)
		return -EINVAL;
	frontend = of_get_compatible_child(link->platforms[0].of_node, "qcom,q6apm-dais");
	ret = frontend && of_device_is_available(frontend) &&
		of_property_read_bool(frontend, "xiaomi,hdmi-only") &&
		!of_property_read_bool(frontend, "xiaomi,registration-only") ? 0 : -EINVAL;
	of_node_put(frontend);
	if (ret)
		return ret;
	link->init = uke_hdmi_init;
	link->be_hw_params_fixup = uke_hdmi_fixup;
	return devm_snd_soc_register_card(dev, card);
}

static int uke_audio_late_probe(struct snd_soc_card *card)
{
	struct snd_soc_pcm_runtime *rtd;
	int count = 0;

	for_each_card_rtds(card, rtd) {
		if (rtd->dai_link->no_pcm || !rtd->dai_link->dynamic)
			return -EINVAL;
		count++;
	}

	return count == 2 ? 0 : -EINVAL;
}

static int uke_audio_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct snd_soc_card *card;
	struct device_node *dais, *apm;
	int ret;

	if (!of_machine_is_compatible("xiaomi,uke"))
		return -ENODEV;
	if (of_device_is_compatible(dev->of_node, "xiaomi,uke-hdmi-audio-card"))
		return uke_hdmi_probe(pdev);

	card = devm_kzalloc(dev, sizeof(*card), GFP_KERNEL);
	if (!card)
		return -ENOMEM;
	card->dev = dev;
	card->owner = THIS_MODULE;
	card->driver_name = "sm7675";
	card->long_name = "POCO Pad X1 AudioReach (streams disabled)";
	card->late_probe = uke_audio_late_probe;
	ret = snd_soc_of_parse_card_name(card, "model");
	if (ret || !card->name)
		return ret ?: -EINVAL;
	ret = snd_soc_of_parse_aux_devs(card, "aux-devs");
	if (ret)
		return ret;
	if (card->num_aux_devs != 2)
		return -EINVAL;

	/* Require both components before ASoC initializes the frontend runtimes. */
	dais = card->aux_dev[0].dlc.of_node;
	apm = card->aux_dev[1].dlc.of_node;
	if (!of_device_is_compatible(dais, "qcom,q6apm-dais") ||
	    !of_device_is_compatible(apm, "qcom,q6apm") ||
	    !of_property_read_bool(dais, "xiaomi,registration-only") ||
	    dais->parent != apm)
		return -EINVAL;

	return devm_snd_soc_register_card(dev, card);
}

static const struct of_device_id uke_audio_match[] = {
	{ .compatible = "xiaomi,uke-audio-card" },
	{ .compatible = "xiaomi,uke-hdmi-audio-card" },
	{}
};
MODULE_DEVICE_TABLE(of, uke_audio_match);

static struct platform_driver uke_audio_driver = {
	.probe = uke_audio_probe,
	.driver = {
		.name = "uke-audioreach-card",
		.of_match_table = uke_audio_match,
	},
};
module_platform_driver(uke_audio_driver);
MODULE_DESCRIPTION("Uke AudioReach DisplayPort and closed registration cards");
MODULE_LICENSE("GPL");
