/* SPDX-License-Identifier: GPL-2.0-only */
/* Included after the original LPASS callbacks, before q6tdm_ops. */
#include "uke-speaker-quad.h"
#include "uke-speaker-quad-wire.h"
#include "uke-fs19xx-runtime.h"
#include <sound/uke-fs19xx-guard.h>

static bool uke_quad_target(const struct snd_soc_dai *dai)
{
	return dai->id == SECONDARY_TDM_RX_0 &&
		of_machine_is_compatible("xiaomi,uke") &&
		of_machine_is_compatible("qcom,sm7675");
}

struct uke_quad_context {
	struct q6apm_lpass_dai_data *data;
	struct snd_soc_dai *dai;
};

static int uke_quad_mfc_apply(void *context, const unsigned int *map)
{
	struct uke_quad_context *ctx = context;
	struct q6apm_graph *graph = ctx->data->graph[ctx->dai->id];
	struct audioreach_module_config cfg;
	struct audioreach_sub_graph *sg;
	struct audioreach_container *container;
	struct audioreach_module *module, *mfc = NULL;

	if (uke_quad_turn(map, 4) < 0)
		return -EINVAL;
	/* Idle requests are retained for prepare without starting a DSP graph. */
	if (!graph)
		return 0;
	if (!q6apm_fs19xx_graph(graph))
		return -EOPNOTSUPP;
	cfg = ctx->data->module_config[ctx->dai->id];
	if (cfg.num_channels != 4 || cfg.sample_rate != 48000 ||
	    cfg.bit_width != 16 || cfg.direction != SNDRV_PCM_STREAM_PLAYBACK)
		return -EINVAL;
	list_for_each_entry(sg, &graph->info->sg_list, node) {
		list_for_each_entry(container, &sg->container_list, node) {
			list_for_each_entry(module, &container->modules_list, node) {
				if (module->module_id != MODULE_ID_MFC)
					continue;
				/* The admitted Uke protection graph has exactly one MFC
				 * before RX 0x4040. Never alter RX, TX, VI or TDM. */
				if (mfc || module->instance_id != 0x442e)
					return -EINVAL;
				mfc = module;
			}
		}
	}
	if (!mfc)
		return -ENODEV;
	return uke_quad_send_matrix(graph, mfc, map);
}

static void uke_quad_mfc_fault(void *context)
{
	(void)context;
	q6apm_fs19xx_fault();
}

static const struct uke_quad_route_ops uke_quad_ops = {
	.apply = uke_quad_mfc_apply,
	.fault = uke_quad_mfc_fault,
};

/* DAI channel maps are zero-based program-channel indices in physical output
 * order. Only the four display rotations are admitted, not arbitrary mixing. */
static int uke_quad_set_map(struct snd_soc_dai *dai, unsigned int tx_num,
			    const unsigned int *tx, unsigned int rx_num,
			    const unsigned int *rx)
{
	struct q6apm_lpass_dai_data *data = dev_get_drvdata(dai->dev);
	struct uke_quad_context context = { data, dai };
	int turn;

	if (!uke_quad_target(dai) || tx_num || tx)
		return -EINVAL;
	turn = uke_quad_turn(rx, rx_num);
	if (turn < 0)
		return turn;
	guard(mutex)(&data->uke_quad_lock);
	return uke_quad_route(&context, &uke_quad_ops, &data->uke_quad_turn, turn);
}

static int uke_quad_get_map(const struct snd_soc_dai *dai, unsigned int *tx_num,
			    unsigned int *tx, unsigned int *rx_num,
			    unsigned int *rx)
{
	struct q6apm_lpass_dai_data *data = dev_get_drvdata(dai->dev);

	if (!uke_quad_target(dai) || !tx_num || !rx_num || !rx)
		return -EINVAL;
	(void)tx;
	guard(mutex)(&data->uke_quad_lock);
	if (data->uke_quad_turn > 3)
		return -EUCLEAN;
	*tx_num = 0;
	*rx_num = 4;
	memcpy(rx, uke_quad_sources[data->uke_quad_turn], sizeof(uke_quad_sources[0]));
	return 0;
}

static int uke_quad_prepare(struct snd_pcm_substream *substream, struct snd_soc_dai *dai)
{
	struct q6apm_lpass_dai_data *data = dev_get_drvdata(dai->dev);
	struct uke_quad_context context = { data, dai };
	int ret;

	if (!uke_quad_target(dai))
		return q6apm_lpass_dai_prepare(substream, dai);
	guard(mutex)(&data->uke_quad_lock);
	ret = q6apm_lpass_dai_prepare(substream, dai);
	if (ret < 0)
		return ret;
	/* Preserve the default prepare command stream exactly. In particular,
	 * never repeat OUTPUT_MEDIA_FORMAT after graph_prepare, even at zero.
	 * Non-default rotation uses the dedicated unity-matrix coefficient API. */
	if (!data->uke_quad_turn)
		return 0;
	ret = uke_quad_mfc_apply(&context, uke_quad_sources[data->uke_quad_turn]);
	if (ret < 0) {
		q6apm_fs19xx_fault();
		q6i2s_lpass_dai_shutdown(substream, dai);
	}
	return ret;
}

static int uke_quad_startup(struct snd_pcm_substream *substream, struct snd_soc_dai *dai)
{
	struct q6apm_lpass_dai_data *data = dev_get_drvdata(dai->dev);

	if (!uke_quad_target(dai))
		return q6apm_lpass_dai_startup(substream, dai);
	guard(mutex)(&data->uke_quad_lock);
	return q6apm_lpass_dai_startup(substream, dai);
}

static void uke_quad_shutdown(struct snd_pcm_substream *substream, struct snd_soc_dai *dai)
{
	struct q6apm_lpass_dai_data *data = dev_get_drvdata(dai->dev);

	if (!uke_quad_target(dai)) {
		q6i2s_lpass_dai_shutdown(substream, dai);
		return;
	}
	guard(mutex)(&data->uke_quad_lock);
	q6i2s_lpass_dai_shutdown(substream, dai);
}

static int uke_quad_hw_params(struct snd_pcm_substream *substream,
			      struct snd_pcm_hw_params *params, struct snd_soc_dai *dai)
{
	struct q6apm_lpass_dai_data *data = dev_get_drvdata(dai->dev);

	if (!uke_quad_target(dai))
		return q6dma_hw_params(substream, params, dai);
	guard(mutex)(&data->uke_quad_lock);
	return q6dma_hw_params(substream, params, dai);
}

static int uke_quad_trigger(struct snd_pcm_substream *substream, int cmd,
			    struct snd_soc_dai *dai)
{
	struct q6apm_lpass_dai_data *data = dev_get_drvdata(dai->dev);

	if (!uke_quad_target(dai))
		return q6apm_lpass_dai_trigger(substream, cmd, dai);
	guard(mutex)(&data->uke_quad_lock);
	return q6apm_lpass_dai_trigger(substream, cmd, dai);
}
