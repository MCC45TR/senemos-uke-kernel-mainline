/* SPDX-License-Identifier: GPL-2.0-only */
/* Nonpersistent APM configuration, with conservative ownership after timeout.
 * Wire contract: AudioReach graphservices558ddfc2, spf/api/apm/apm_api.h and
 * apm_memmap_api.h (Qualcomm, BSD-3-Clause). No donor code or calibration data.
 */
#ifndef UKE_FS19XX_OOB_H
#define UKE_FS19XX_OOB_H
#ifdef __KERNEL__
#include <linux/types.h>
#include <linux/errno.h>
#include <linux/string.h>
typedef u8 uke_oob_u8;
typedef u32 uke_oob_u32;
#else
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <errno.h>
#include <string.h>
typedef uint8_t uke_oob_u8;
typedef uint32_t uke_oob_u32;
#endif

#define UKE_OOB_MAP 0x0100100c
#define UKE_OOB_UNMAP 0x0100100d
#define UKE_OOB_SET_CFG 0x01001006
#define UKE_OOB_TUNING_IID 0x4040
#define UKE_OOB_TUNING_PARAM 0x10001fb0
#define UKE_OOB_TUNING_BYTES 5360
#define UKE_OOB_PAYLOAD_BYTES (16 + UKE_OOB_TUNING_BYTES)
#define UKE_OOB_MEMORY_BYTES 8192

enum uke_oob_state {
	UKE_OOB_EMPTY, UKE_OOB_LOCAL, UKE_OOB_MAP_SENT, UKE_OOB_MAPPED,
	UKE_OOB_CONFIG_SENT, UKE_OOB_CONFIG_COMPLETE, UKE_OOB_UNMAP_SENT,
	UKE_OOB_QUARANTINED,
};
struct uke_oob_buffer {
	uke_oob_u8 *data;
	uke_oob_u32 address_low, address_high, bytes, handle;
	enum uke_oob_state state;
	void *cookie;
};
struct uke_oob_reply {
	int error;
	bool sent;
	bool complete;
	uke_oob_u32 handle;
};
struct uke_oob_ops {
	int (*allocate)(void *, struct uke_oob_buffer *);
	struct uke_oob_reply (*command)(void *, uke_oob_u32,
				       const uke_oob_u8 *, size_t);
	void (*erase)(void *, struct uke_oob_buffer *);
	void (*release)(void *, struct uke_oob_buffer *);
	/* Must retain the allocation and callback state without allocating.
	 * No retry/rebind may reuse them until remote ownership is disproved.
	 */
	void (*quarantine)(void *, struct uke_oob_buffer *);
};

static inline void uke_oob_put32(uke_oob_u8 *p, uke_oob_u32 v)
{
	p[0] = v; p[1] = v >> 8; p[2] = v >> 16; p[3] = v >> 24;
}

static inline uke_oob_u32 uke_oob_get32(const uke_oob_u8 *p)
{
	return (uke_oob_u32)p[0] | ((uke_oob_u32)p[1] << 8) |
	       ((uke_oob_u32)p[2] << 16) | ((uke_oob_u32)p[3] << 24);
}

static inline int uke_oob_retain(struct uke_oob_buffer *b,
		const struct uke_oob_ops *ops, void *context, int error)
{
	ops->erase(context, b);
	b->state = UKE_OOB_QUARANTINED;
	ops->quarantine(context, b);
	return error ? error : -EPROTO;
}

static inline void uke_oob_release(struct uke_oob_buffer *b,
		const struct uke_oob_ops *ops, void *context)
{
	ops->erase(context, b);
	ops->release(context, b);
	memset(b, 0, sizeof(*b));
}

/* Caller serializes the client, holds device/transport lifetime and keeps the
 * amplifiers muted. Backend owns a dedicated response port, validates source,
 * opcode, token, length and handle, and distinguishes unsent from ambiguous.
 * No command contains calibration bytes; the complete TLV lives in shared RAM.
 */
static inline int uke_fs19xx_oob_transfer(struct uke_oob_buffer *b,
		const struct uke_oob_ops *ops, void *context, uke_oob_u32 instance,
		uke_oob_u32 parameter, const uke_oob_u8 *data, size_t bytes)
{
	struct uke_oob_reply response;
	uke_oob_u8 map[20] = {0}, config[16] = {0}, unmap[4] = {0};
	int ret, result;

	if (!b || !ops || !ops->allocate || !ops->command || !ops->erase ||
	    !ops->release || !ops->quarantine || !data ||
	    instance != UKE_OOB_TUNING_IID || parameter != UKE_OOB_TUNING_PARAM ||
	    bytes != UKE_OOB_TUNING_BYTES)
		return -EINVAL;
	if (b->state != UKE_OOB_EMPTY)
		return -EBUSY;
	ret = ops->allocate(context, b);
	if (ret)
		return ret;
	b->state = UKE_OOB_LOCAL;
	/* APM specifies contiguous, 32-byte aligned 32/36-bit addresses. The
	 * dedicated allocation covers whole4K mapping pages; never share slab.
	 */
	if (!b->data || b->bytes != UKE_OOB_MEMORY_BYTES ||
	    (b->address_low & 4095) || b->address_high > 15 ||
	    (b->address_high == 15 && b->address_low > 0xffffe000U) ||
	    (!b->address_low && !b->address_high)) {
		uke_oob_release(b, ops, context);
		return -EINVAL;
	}
	memset(b->data, 0, b->bytes);
	uke_oob_put32(b->data, instance);
	uke_oob_put32(b->data + 4, parameter);
	uke_oob_put32(b->data + 8, bytes);
	memcpy(b->data + 16, data, bytes);

	/* APM_MEMORY_MAP_SHMEM8_4K_POOL, one physical region, property0. The
	 * native backend must verify its DMA address is valid for this contract.
	 */
	map[0] = 3; map[2] = 1;
	uke_oob_put32(map + 8, b->address_low);
	uke_oob_put32(map + 12, b->address_high);
	uke_oob_put32(map + 16, b->bytes);
	b->state = UKE_OOB_MAP_SENT;
	response = ops->command(context, UKE_OOB_MAP, map, sizeof(map));
	if (!response.sent) {
		ret = response.error ? response.error : -EPROTO;
		uke_oob_release(b, ops, context);
		return ret;
	}
	if (!response.complete || response.error || !response.handle)
		return uke_oob_retain(b, ops, context,
			response.error ? response.error : -EPROTO);
	b->handle = response.handle;
	b->state = UKE_OOB_MAPPED;
	uke_oob_put32(config, b->address_low);
	uke_oob_put32(config + 4, b->address_high);
	uke_oob_put32(config + 8, b->handle);
	uke_oob_put32(config + 12, UKE_OOB_PAYLOAD_BYTES);
	b->state = UKE_OOB_CONFIG_SENT;
	response = ops->command(context, UKE_OOB_SET_CFG, config, sizeof(config));
	/* An unmap ACK alone does not prove a timed-out asynchronous module
	 * command has stopped reading. Retain its pages and port until recovery.
	 */
	if (response.sent && !response.complete)
		return uke_oob_retain(b, ops, context,
			response.error ? response.error : -EPROTO);
	result = response.error;
	if (!response.sent && !result)
		result = -EPROTO;
	/* The backend performs the coherent read barrier after a matching reply.
	 * APM places per-module errors in the shared TLV, even if BASIC_RSP is0.
	 */
	if (!result && response.complete) {
		if (uke_oob_get32(b->data) != instance ||
		    uke_oob_get32(b->data + 4) != parameter ||
		    uke_oob_get32(b->data + 8) != bytes ||
		    memcmp(b->data + 16, data, bytes))
			result = -EPROTO;
		else if (uke_oob_get32(b->data + 12))
			result = -EREMOTEIO;
	}
	b->state = UKE_OOB_CONFIG_COMPLETE;
	uke_oob_put32(unmap, b->handle);
	b->state = UKE_OOB_UNMAP_SENT;
	response = ops->command(context, UKE_OOB_UNMAP, unmap, sizeof(unmap));
	if (!response.sent || !response.complete || response.error)
		return uke_oob_retain(b, ops, context,
			response.error ? response.error : -EPROTO);
	uke_oob_release(b, ops, context);
	return result;
}
#endif
