/* SPDX-License-Identifier: GPL-2.0-only */
/* Included by q6apm-dai.c; only Uke's dedicated speaker FE is affected. */
#ifndef UKE_SPEAKER_SURROUND_FE_H
#define UKE_SPEAKER_SURROUND_FE_H
static const unsigned int uke_surround_fe_counts[] = { 4, 6, 8 };
static const struct snd_pcm_hw_constraint_list uke_surround_fe_constraint = {
	.count = ARRAY_SIZE(uke_surround_fe_counts),
	.list = uke_surround_fe_counts,
};
static const struct snd_pcm_chmap_elem uke_surround_fe_maps[] = {
	{ .channels = 4, .map = {
		SNDRV_CHMAP_FL, SNDRV_CHMAP_FR, SNDRV_CHMAP_RL, SNDRV_CHMAP_RR } },
	{ .channels = 6, .map = {
		SNDRV_CHMAP_FL, SNDRV_CHMAP_FR, SNDRV_CHMAP_RL, SNDRV_CHMAP_RR,
		SNDRV_CHMAP_FC, SNDRV_CHMAP_LFE } },
	{ .channels = 8, .map = {
		SNDRV_CHMAP_FL, SNDRV_CHMAP_FR, SNDRV_CHMAP_RL, SNDRV_CHMAP_RR,
		SNDRV_CHMAP_FC, SNDRV_CHMAP_LFE, SNDRV_CHMAP_SL, SNDRV_CHMAP_SR } },
	{ }
};

static bool uke_surround_fe_target(int graph_id, int stream)
{
	return graph_id == 1 && stream == SNDRV_PCM_STREAM_PLAYBACK &&
		of_machine_is_compatible("xiaomi,uke") &&
		of_machine_is_compatible("qcom,sm7675");
}

static int uke_surround_fe_open(struct snd_pcm_substream *substream, int graph_id)
{
	if (!uke_surround_fe_target(graph_id, substream->stream))
		return 0;
	return snd_pcm_hw_constraint_list(substream->runtime, 0,
		SNDRV_PCM_HW_PARAM_CHANNELS, &uke_surround_fe_constraint);
}

static int uke_surround_fe_chmap(struct snd_pcm *pcm, int graph_id)
{
	if (!uke_surround_fe_target(graph_id, SNDRV_PCM_STREAM_PLAYBACK) ||
	    !pcm->streams[SNDRV_PCM_STREAM_PLAYBACK].substream)
		return 0;
	return snd_pcm_add_chmap_ctls(pcm, SNDRV_PCM_STREAM_PLAYBACK,
		uke_surround_fe_maps, 8, 0, NULL);
}
#endif
