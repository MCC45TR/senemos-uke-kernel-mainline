/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * AudioReach IMCL graph-open encoding. Wire layout follows AudioReach engine
 * b38cb85a1a25, fwk/api/apm/apm_module_api.h (BSD-3-Clause).
 * Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
 * No amplifier tuning or calibration data is embedded here.
 */
#ifndef AUDIOREACH_CONTROL_LINKS_H
#define AUDIOREACH_CONTROL_LINKS_H

#include <asm/byteorder.h>
#include <linux/errno.h>
#include <linux/string.h>
#include <linux/types.h>

#define AR_CTRL_LINK_MAX_COUNT 32
#define AR_CTRL_LINK_PARAM_ID 0x08001061
#define AR_CTRL_LINK_INTENT_PROP 0x08001062
#define AR_CTRL_LINK_HEAP_PROP 0x0800136f

struct audioreach_ctrl_link {
	u32 first_instance;
	u32 first_port;
	u32 second_instance;
	u32 second_port;
	u32 intent;
	u32 heap;
};

static inline bool audioreach_ctrl_link_valid(const struct audioreach_ctrl_link *link)
{
	return link->first_instance && link->first_port && link->second_instance &&
	       link->second_port && link->intent && link->heap >= 1 && link->heap <= 3 &&
	       (link->first_instance != link->second_instance ||
		link->first_port != link->second_port);
}

/* APM parameter header, count, and one intent plus heap property per link. */
static inline int audioreach_ctrl_links_size(unsigned int count)
{
	if (count > AR_CTRL_LINK_MAX_COUNT)
		return -E2BIG;
	if (!count)
		return 0;
	return (16 + 4 + 48 * count + 7) & ~7;
}

static inline int audioreach_ctrl_links_pack(void *destination, size_t capacity,
					    const struct audioreach_ctrl_link *links,
					    unsigned int count)
{
	unsigned int i, j, word = 0;
	__le32 *output = destination;
	int size = audioreach_ctrl_links_size(count);

	if (size <= 0)
		return size;
	if (!destination || !links || capacity < (size_t)size)
		return -EINVAL;
	/* Validate the complete set before touching the destination. */
	for (i = 0; i < count; i++) {
		if (!audioreach_ctrl_link_valid(&links[i]))
			return -EINVAL;
		for (j = 0; j < i; j++) {
			const struct audioreach_ctrl_link *a = &links[i], *b = &links[j];
			bool same = a->first_instance == b->first_instance &&
				a->first_port == b->first_port &&
				a->second_instance == b->second_instance &&
				a->second_port == b->second_port;
			bool reverse = a->first_instance == b->second_instance &&
				a->first_port == b->second_port &&
				a->second_instance == b->first_instance &&
				a->second_port == b->first_port;

			if (same || reverse)
				return -EINVAL;
		}
	}
	memset(destination, 0, size);
#define AR_CTRL_WORD(value) (output[word++] = cpu_to_le32(value))
	AR_CTRL_WORD(1); /* APM_MODULE_INSTANCE_ID */
	AR_CTRL_WORD(AR_CTRL_LINK_PARAM_ID);
	AR_CTRL_WORD(4 + 48 * count); /* parameter bytes exclude alignment padding */
	AR_CTRL_WORD(0); /* error_code */
	AR_CTRL_WORD(count);
	for (i = 0; i < count; i++) {
		AR_CTRL_WORD(links[i].first_instance);
		AR_CTRL_WORD(links[i].first_port);
		AR_CTRL_WORD(links[i].second_instance);
		AR_CTRL_WORD(links[i].second_port);
		AR_CTRL_WORD(2); /* num_props */
		AR_CTRL_WORD(AR_CTRL_LINK_INTENT_PROP);
		AR_CTRL_WORD(8); /* one u32 count and one u32 intent */
		AR_CTRL_WORD(1);
		AR_CTRL_WORD(links[i].intent);
		AR_CTRL_WORD(AR_CTRL_LINK_HEAP_PROP);
		AR_CTRL_WORD(4);
		AR_CTRL_WORD(links[i].heap);
	}
#undef AR_CTRL_WORD
	return size;
}

#endif
