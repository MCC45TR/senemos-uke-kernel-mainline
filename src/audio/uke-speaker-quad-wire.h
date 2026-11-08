/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_SPEAKER_QUAD_WIRE_H
#define UKE_SPEAKER_QUAD_WIRE_H

/* AudioReach chmixer_common_api.h, PARAM_ID_CHMIXER_COEFF. Its fixed
 * input/output identities stay canonical; only a unity permutation changes.
 * This is not an output media-format change and cannot add signal gain. */
#define UKE_QUAD_COEFF_ID 0x0800101f
#define UKE_QUAD_COEFF_BYTES 56

static inline void uke_quad_le16(unsigned char *wire, unsigned int value)
{
	wire[0] = value;
	wire[1] = value >> 8;
}

static inline int uke_quad_encode(unsigned char *wire, unsigned int bytes,
				  const unsigned int *map)
{
	static const unsigned int ids[] = { 1, 2, 5, 6 };
	unsigned int row;

	if (!wire || bytes != UKE_QUAD_COEFF_BYTES || uke_quad_turn(map, 4) < 0)
		return -EINVAL;
	memset(wire, 0, bytes);
	wire[0] = 1; /* One little-endian u32 coefficient-table count. */
	uke_quad_le16(wire + 4, 4);
	uke_quad_le16(wire + 6, 4);
	for (row = 0; row < 4; row++) {
		uke_quad_le16(wire + 8 + row * 2, ids[row]);
		uke_quad_le16(wire + 16 + row * 2, ids[row]);
		/* Row-major Q14 output x input matrix, one unity per row. */
		uke_quad_le16(wire + 24 + (row * 4 + map[row]) * 2, 0x4000);
	}
	return 0;
}

static inline int uke_quad_send_matrix(struct q6apm_graph *graph,
				       const struct audioreach_module *module,
				       const unsigned int *map)
{
	unsigned char wire[UKE_QUAD_COEFF_BYTES];
	struct apm_module_param_data *param;
	struct gpr_pkt *pkt;
	int ret;

	ret = uke_quad_encode(wire, sizeof(wire), map);
	if (ret < 0)
		return ret;
	if (!graph || !module || module->module_id != MODULE_ID_MFC ||
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
