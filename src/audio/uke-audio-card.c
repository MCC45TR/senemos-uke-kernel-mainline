// SPDX-License-Identifier: GPL-2.0-only
/* Uke AudioReach registration; physical audio paths are not qualified yet. */
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>
#include <linux/slab.h>
#include <sound/soc.h>

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
MODULE_DESCRIPTION("Uke AudioReach card registration with closed streams");
MODULE_LICENSE("GPL");
