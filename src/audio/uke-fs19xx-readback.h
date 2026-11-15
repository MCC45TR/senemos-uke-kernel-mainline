/* SPDX-License-Identifier: GPL-2.0-only */
/* Bounded, in-band enable readback. Never query tuning or unit calibration.
 * Wire reference: AudioReach graphservices558ddfc2 apm_api.h, BSD-3-Clause.
 * RX/TX enable is not proof of the proprietary limiter's physical behavior.
 */
#ifndef UKE_FS19XX_READBACK_H
#define UKE_FS19XX_READBACK_H
#ifdef __KERNEL__
#include <linux/types.h>
#include <linux/errno.h>
#include <linux/string.h>
typedef u8 uke_rb_u8;
typedef u32 uke_rb_u32;
#else
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <errno.h>
#include <string.h>
typedef uint8_t uke_rb_u8;
typedef uint32_t uke_rb_u32;
#endif

#define UKE_RB_GET_CFG 0x01001007
#define UKE_RB_GET_REPLY 0x02001000
#define UKE_RB_BASIC_REPLY 0x02001005
#define UKE_RB_ACCEPTED 0x02001006
#define UKE_RB_REQUEST_BYTES 40

struct uke_rb_envelope {
	uke_rb_u32 version, header_words, packet_bytes, reserved;
	uke_rb_u32 source_domain, destination_domain, source_port, destination_port;
	uke_rb_u32 token, opcode;
};
struct uke_rb_query {
	uke_rb_u32 port, token, instance, parameter, remote_status;
	bool pending, enabled;
	int error;
};

static inline uke_rb_u32 uke_rb_word(const uke_rb_u8 *p)
{
	return (uke_rb_u32)p[0] | (uke_rb_u32)p[1] << 8 |
	       (uke_rb_u32)p[2] << 16 | (uke_rb_u32)p[3] << 24;
}
static inline void uke_rb_put(uke_rb_u8 *p, uke_rb_u32 v)
{
	p[0] = v; p[1] = v >> 8; p[2] = v >> 16; p[3] = v >> 24;
}

/* There is deliberately no caller-supplied instance, parameter or size. */
static inline int uke_rb_begin(struct uke_rb_query *q, uke_rb_u32 port,
		uke_rb_u32 token, unsigned int channel, uke_rb_u8 *request, size_t bytes)
{
	if (!q || !request || bytes != UKE_RB_REQUEST_BYTES || !port || !token || channel > 1)
		return -EINVAL;
	memset(q, 0, sizeof(*q));
	memset(request, 0, bytes);
	q->port = port;
	q->token = token;
	q->instance = channel ? 0x49fd : 0x4040;
	q->parameter = channel ? 0x11111601 : 0x11111611;
	q->error = -ENODATA;
	q->pending = true;
	/* apm_cmd_header: no mapped memory; one 8-byte-aligned parameter TLV. */
	uke_rb_put(request + 12, 24);
	uke_rb_put(request + 16, q->instance);
	uke_rb_put(request + 20, q->parameter);
	uke_rb_put(request + 24, 4);
	return 0;
}

static inline void uke_rb_cancel(struct uke_rb_query *q, int error)
{
	q->pending = false;
	q->enabled = false;
	q->remote_status = 0;
	q->error = error;
}

/* Caller serializes begin/reply/cancel and retains the dynamic GPR port.
 * Return1 for a terminal matching reply,0 for an unrelated/interim reply.
 * No contents are logged or copied to a caller-selected buffer.
 */
static inline int uke_rb_reply(struct uke_rb_query *q, const struct uke_rb_envelope *h,
		const uke_rb_u8 *data, size_t bytes)
{
	uke_rb_u32 status;
	if (!q || !h || !q->pending || h->token != q->token ||
	    h->source_domain != 2 || h->destination_domain != 3 ||
	    h->source_port != 1 || h->destination_port != q->port)
		return 0;
	/* Linux names16 bits reserved; fitted GPR uses their low byte as client data. */
	if (!data || h->version || h->header_words != 6 || (h->reserved & 0xff00U) ||
	    bytes > 28 || h->packet_bytes != 24 + bytes)
		goto malformed;
	if (h->opcode == UKE_RB_ACCEPTED) {
		if (bytes != 4 || uke_rb_word(data) != UKE_RB_GET_CFG)
			goto malformed;
		return 0;
	}
	if (h->opcode == UKE_RB_BASIC_REPLY) {
		if (bytes != 8 || uke_rb_word(data) != UKE_RB_GET_CFG)
			goto malformed;
		status = uke_rb_word(data + 4);
		/* A successful basic ACK carries no enable value. */
		if (!status)
			return 0;
		goto remote_error;
	}
	if (h->opcode != UKE_RB_GET_REPLY || bytes < 4)
		goto malformed;
	status = uke_rb_word(data);
	if (status)
		goto remote_error;
	if ((bytes != 24 && bytes != 28) ||
	    uke_rb_word(data + 4) != q->instance ||
	    uke_rb_word(data + 8) != q->parameter ||
	    uke_rb_word(data + 12) != 4)
		goto malformed;
	/* APM permits optional final alignment. Its bytes have no value contract;
	 * only the exact four-byte parameter participates in this enable result.
	 */
	status = uke_rb_word(data + 16);
	if (status)
		goto remote_error;
	status = uke_rb_word(data + 20);
	if (status > 1)
		goto malformed;
	q->enabled = status;
	q->error = 0;
	q->pending = false;
	return 1;
remote_error:
	uke_rb_cancel(q, -EREMOTEIO);
	q->remote_status = status;
	return 1;
malformed:
	uke_rb_cancel(q, -EPROTO);
	return 1;
}
#ifdef __KERNEL__
struct q6apm;
int q6apm_fs19xx_read_enables(struct q6apm *apm, unsigned int *enabled);
#endif
#endif
