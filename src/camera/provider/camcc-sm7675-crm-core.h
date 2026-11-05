/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Cliffs camera AP SWDRV0 vote planning and first-error handling.
 * Register layout derived from drivers/soc/qcom/crm.c in Xiaomi Uke
 * 5712080a4b0c0b1a879e6d145c601c649ddaddfd:
 * Copyright (c) 2022-2023, Qualcomm Innovation Center, Inc. All rights reserved.
 * BCM format also follows include/soc/qcom/tcs.h:
 * Copyright (c) 2016-2019, The Linux Foundation. All rights reserved.
 * Copyright (c) 2022 Qualcomm Innovation Center, Inc. All rights reserved.
 *
 * This core performs no MMIO and admits no hardware by itself. Its caller must
 * hold controller power and a sleepable transaction lock. The transport must
 * arm an owned IRQ before ACTIVE, wait a bounded time for its acknowledgement,
 * and quarantine timeout/late-IRQ ambiguity. SLEEP/WAKE writes are stored votes,
 * not proof that hardware has entered either power state.
 */
#ifndef UKE_CAMCC_SM7675_CRM_CORE_H
#define UKE_CAMCC_SM7675_CRM_CORE_H

#include <linux/errno.h>
#include <linux/types.h>

enum cam_cc_crm_kind {
	CAM_CC_CRM_PERF,
	CAM_CC_CRM_BW,
};

enum cam_cc_crm_state {
	CAM_CC_CRM_ACTIVE,
	CAM_CC_CRM_SLEEP,
	CAM_CC_CRM_WAKE,
	CAM_CC_CRM_STATES,
};

enum cam_cc_crm_register {
	CAM_CC_CRM_VOTE,
	CAM_CC_CRM_IRQ_STATUS,
	CAM_CC_CRM_IRQ_CLEAR,
	CAM_CC_CRM_IRQ_ENABLE,
};

struct cam_cc_crm_caps {
	u32 sw_drvs;
	u32 perf_vcds;
	u32 bw_vcds;
	u32 bw_nodes;
};

struct cam_cc_crm_packet {
	u32 offset;
	u32 data;
	enum cam_cc_crm_state state;
	bool wait_for_ack;
};

struct cam_cc_crm_vote_state {
	bool poisoned;
	bool confirmed_valid;
	u32 confirmed_value;
};

/* Only the seven PERF voters and CRMB node0 named by the OEM CAMCC are owned. */
static inline bool cam_cc_crm_owned(unsigned int kind, u32 resource)
{
	if (kind == CAM_CC_CRM_PERF)
		return resource < 8 && resource != 5;
	return kind == CAM_CC_CRM_BW && resource == 0;
}

static inline bool cam_cc_crm_caps_valid(const struct cam_cc_crm_caps *caps)
{
	/* The register banks are 0x40 bytes apart: do not alias adjacent banks. */
	return caps && caps->sw_drvs && caps->sw_drvs <= 15 &&
		caps->perf_vcds >= 8 && caps->perf_vcds <= 15 &&
		caps->bw_vcds && caps->bw_vcds <= 15 &&
		caps->bw_nodes && caps->bw_nodes <= 16;
}

/* Raw hardware version is deliberately not guessed or whitelisted here. */
static inline int cam_cc_crm_decode_caps(u32 cfg1, u32 cfg2,
					struct cam_cc_crm_caps *out)
{
	struct cam_cc_crm_caps caps;

	caps.sw_drvs = (cfg1 >> 20) & 0xf;
	caps.perf_vcds = (cfg1 >> 8) & 0xf;
	caps.bw_vcds = (cfg1 >> 24) & 0xf;
	/* BW nodes come from CFG2, independently of CFG1 BW VCDs. */
	caps.bw_nodes = (cfg2 >> 26) & 0x1f;
	if (!out || !cam_cc_crm_caps_valid(&caps))
		return -EINVAL;
	*out = caps;
	return 0;
}

static inline int cam_cc_crm_offset(const struct cam_cc_crm_caps *caps,
		unsigned int kind, u32 resource, unsigned int reg,
		unsigned int state, u32 span, u32 *out)
{
	u32 offset;

	if (!out || !cam_cc_crm_caps_valid(caps) ||
	    !cam_cc_crm_owned(kind, resource) || reg > CAM_CC_CRM_IRQ_ENABLE ||
	    state >= CAM_CC_CRM_STATES ||
	    (reg != CAM_CC_CRM_VOTE && state != CAM_CC_CRM_ACTIVE))
		return -EINVAL;
	if (resource >= (kind == CAM_CC_CRM_PERF ? caps->perf_vcds : caps->bw_nodes))
		return -EINVAL;
	/* SWDRV0 only; no HW voter/channel or other SW DRV is addressed. */
	offset = 0x1060 + resource * 4;
	if (kind == CAM_CC_CRM_BW)
		offset += 0x3a0;
	if (reg == CAM_CC_CRM_VOTE)
		offset += state * 0x40;
	else
		offset += 0x100 + (reg - CAM_CC_CRM_IRQ_STATUS) * 0x40;
	if ((span & 3) || span < 4 || offset > span - 4 || span > 0x2000)
		return -ERANGE;
	*out = offset;
	return 0;
}

/* value is a PERF level or an already rounded, range-checked IB vote in MHz. */
static inline int cam_cc_crm_plan(const struct cam_cc_crm_caps *caps,
		unsigned int kind, u32 resource, u32 value, u32 span,
		struct cam_cc_crm_packet out[CAM_CC_CRM_STATES])
{
	struct cam_cc_crm_packet plan[CAM_CC_CRM_STATES];
	u32 data;
	unsigned int i;
	int ret;

	if (!out || (kind != CAM_CC_CRM_PERF && kind != CAM_CC_CRM_BW))
		return -EINVAL;
	if (value > (kind == CAM_CC_CRM_PERF ? 7U : 0x3fffU))
		return -ERANGE;
	data = value;
	if (kind == CAM_CC_CRM_BW)
		/* OEM wait=1 also sets RESP_REQ on the stored SLEEP/WAKE words. */
		data |= (1U << 29) | (1U << 30) | (1U << 31);
	for (i = 0; i < CAM_CC_CRM_STATES; i++) {
		ret = cam_cc_crm_offset(caps, kind, resource, CAM_CC_CRM_VOTE,
				       i, span, &plan[i].offset);
		if (ret)
			return ret;
		plan[i].data = data;
		plan[i].state = (enum cam_cc_crm_state)i;
		plan[i].wait_for_ack = i == CAM_CC_CRM_ACTIVE;
	}
	/* Rejected plans leave the caller's output and hardware untouched. */
	for (i = 0; i < CAM_CC_CRM_STATES; i++)
		out[i] = plan[i];
	return 0;
}

typedef int (*cam_cc_crm_transport_fn)(void *context,
				      const struct cam_cc_crm_packet *packet);

static inline int cam_cc_crm_send_vote(const struct cam_cc_crm_caps *caps,
		unsigned int kind, u32 resource, u32 value, u32 span,
		struct cam_cc_crm_vote_state *vote, cam_cc_crm_transport_fn send,
		void *context)
{
	struct cam_cc_crm_packet plan[CAM_CC_CRM_STATES];
	unsigned int i;
	int ret;

	if (!vote || !send)
		return -EINVAL;
	if (vote->poisoned)
		return -EIO;
	ret = cam_cc_crm_plan(caps, kind, resource, value, span, plan);
	if (ret)
		return ret;
	for (i = 0; i < CAM_CC_CRM_STATES; i++) {
		ret = send(context, &plan[i]);
		if (ret) {
			/* Partial writes/late completion cannot be safely retried here. */
			vote->poisoned = true;
			vote->confirmed_valid = false;
			return ret < 0 ? ret : -EIO;
		}
	}
	vote->confirmed_value = value;
	vote->confirmed_valid = true;
	return 0;
}

#endif /* UKE_CAMCC_SM7675_CRM_CORE_H */
