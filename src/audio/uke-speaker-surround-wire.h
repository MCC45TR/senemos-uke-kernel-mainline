/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_SPEAKER_SURROUND_WIRE_H
#define UKE_SPEAKER_SURROUND_WIRE_H

/* AudioReach PARAM_ID_CHMIXER_COEFF: one set replaces all previous tables.
 * Keep a quad permutation alongside both multichannel layouts so a format
 * change cannot silently discard rotation. This is a conservative downmix,
 * not a spatial renderer, crossover or transducer-protection algorithm. */
#define UKE_SURROUND_COEFF_BYTES 220

static inline unsigned int uke_surround_weight(unsigned int channels,
					       unsigned int row, unsigned int col)
{
	/* Reserve 1/8 for LFE. The front main/center ratio approximates sqrt(2).
	 * Every row sums to Q14 unity, even for correlated full-scale inputs.
	 * This bounds digital peaks, not acoustic excursion or thermal safety. */
	if (col == 5)
		return 2048;
	if (row < 2) {
		if (col == row)
			return 8398;
		return col == 4 ? 5938 : 0;
	}
	if (channels == 6)
		return col == row ? 14336 : 0;
	return col == row || col == row + 4 ? 7168 : 0;
}

static inline int uke_surround_encode(unsigned char *wire, unsigned int bytes,
				      const unsigned int *map)
{
	static const unsigned int ids[] = {
		PCM_CHANNEL_FL, PCM_CHANNEL_FR, PCM_CHANNEL_LS, PCM_CHANNEL_RS,
		PCM_CHANNEL_FC, PCM_CHANNEL_LFE
	};
	static const unsigned int back[] = { PCM_CHANNEL_LB, PCM_CHANNEL_RB };
	unsigned int channels, row, col, offset = 4;
	unsigned char quad[UKE_QUAD_COEFF_BYTES];

	if (!wire || bytes != UKE_SURROUND_COEFF_BYTES ||
	    uke_quad_encode(quad, sizeof(quad), map) < 0)
		return -EINVAL;
	memset(wire, 0, bytes);
	wire[0] = 3;
	/* The first table is byte-identical to the existing quad coefficient set. */
	memcpy(wire + offset, quad + 4, sizeof(quad) - 4);
	offset += sizeof(quad) - 4;
	for (channels = 6; channels <= 8; channels += 2) {
		unsigned char *table = wire + offset;
		unsigned int coeff = 4 + (4 + channels) * 2;

		uke_quad_le16(table, 4);
		uke_quad_le16(table + 2, channels);
		for (row = 0; row < 4; row++)
			uke_quad_le16(table + 4 + row * 2, ids[row]);
		for (col = 0; col < channels; col++) {
			unsigned int id = ids[col < 6 ? col : col - 4];

			if (channels == 8 && col >= 2 && col < 4)
				id = back[col - 2];
			uke_quad_le16(table + 12 + col * 2, id);
		}
		for (row = 0; row < 4; row++)
			for (col = 0; col < channels; col++)
				uke_quad_le16(table + coeff + (row * channels + col) * 2,
					uke_surround_weight(channels, map[row], col));
		offset += coeff + 4 * channels * 2;
	}
	return 0;
}

static inline int uke_surround_send_matrix(struct q6apm_graph *graph,
					  const struct audioreach_module *module,
					  const unsigned int *map)
{
	unsigned char wire[UKE_SURROUND_COEFF_BYTES];
	struct apm_module_param_data *param;
	struct gpr_pkt *pkt;
	int ret;

	ret = uke_surround_encode(wire, sizeof(wire), map);
	if (ret < 0)
		return ret;
	if (!graph || !graph->apm || !module || module->module_id != MODULE_ID_MFC ||
	    module->instance_id != 0x442e)
		return -EINVAL;
	pkt = audioreach_alloc_apm_cmd_pkt(APM_MODULE_PARAM_DATA_SIZE + sizeof(wire),
					 APM_CMD_SET_CFG, 0);
	if (IS_ERR(pkt))
		return PTR_ERR(pkt);
	param = (void *)pkt + GPR_HDR_SIZE + APM_CMD_HDR_SIZE;
	param->module_instance_id = module->instance_id;
	param->param_id = UKE_QUAD_COEFF_ID;
	param->param_size = sizeof(wire);
	param->error_code = 0;
	memcpy(param + 1, wire, sizeof(wire));
	ret = q6apm_send_cmd_sync(graph->apm, pkt, 0);
	kfree(pkt);
	return ret > 0 ? -EIO : ret;
}
#endif
