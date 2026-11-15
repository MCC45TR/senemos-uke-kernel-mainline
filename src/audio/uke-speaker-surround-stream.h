/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_SPEAKER_SURROUND_STREAM_H
#define UKE_SPEAKER_SURROUND_STREAM_H

static inline bool uke_surround_channels_valid(unsigned int channels)
{
	return channels == 4 || channels == 6 || channels == 8;
}

/* Called from the BE prepare callback under the ASoC PCM and quad locks.
 * Read the actual FE hw_params, not the BE fixup (which must remain four).
 * Multiple FE users may share this graph only with the same channel layout. */
static int uke_surround_stream_channels(struct snd_pcm_substream *substream)
{
	struct snd_soc_pcm_runtime *be;
	struct snd_soc_dpcm *dpcm;
	unsigned int channels = 0;

	if (!substream || substream->stream != SNDRV_PCM_STREAM_PLAYBACK)
		return -EINVAL;
	be = snd_soc_substream_to_rtd(substream);
	if (!be || !be->dai_link || !be->dai_link->no_pcm)
		return -EINVAL;
	for_each_dpcm_fe(be, SNDRV_PCM_STREAM_PLAYBACK, dpcm) {
		unsigned int count;
		snd_pcm_format_t format;

		if (!dpcm->fe || !dpcm->fe->dai_link ||
		    !dpcm->fe->dai_link->dynamic || dpcm->fe->dai_link->num_cpus != 1 ||
		    snd_soc_rtd_to_cpu(dpcm->fe, 0)->id != 1)
			return -EINVAL;
		count = params_channels(&dpcm->fe->dpcm[SNDRV_PCM_STREAM_PLAYBACK].hw_params);
		format = params_format(&dpcm->fe->dpcm[SNDRV_PCM_STREAM_PLAYBACK].hw_params);
		if (!uke_surround_channels_valid(count))
			return -EINVAL;
		if (params_rate(&dpcm->fe->dpcm[SNDRV_PCM_STREAM_PLAYBACK].hw_params) != 48000 ||
		    (format != SNDRV_PCM_FORMAT_S16_LE && format != SNDRV_PCM_FORMAT_S24_LE &&
		     format != SNDRV_PCM_FORMAT_S32_LE))
			return -EINVAL;
		if (channels && channels != count)
			return -EBUSY;
		channels = count;
	}
	if (!channels)
		return -ENOLINK;
	return channels;
}
#endif
