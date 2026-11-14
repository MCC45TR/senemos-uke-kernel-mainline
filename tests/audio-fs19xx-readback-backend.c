/* SPDX-License-Identifier: GPL-2.0-only */
/* Production transport with independent GPR providers; synthetic enables only. */
#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include "uke-fs19xx-readback.h"
typedef uint8_t u8;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int spinlock_t;
typedef int wait_queue_head_t;
typedef struct { int64_t value; } atomic64_t;
#define ATOMIC64_INIT(v) {v}
static int64_t atomic64_add_return(int n, atomic64_t *a) { return a->value += n; }
#define U32_MAX UINT32_MAX
#define GFP_KERNEL 0
#define GPR_PKT_VER 0
#define GPR_PKT_HEADER_WORD_SIZE 6
#define GPR_DOMAIN_ID_APPS 3
#define GPR_DOMAIN_ID_ADSP 2
#define READ_ONCE(v) (v)
#define IS_ERR(p) ((intptr_t)(p) < 0 && (intptr_t)(p) > -4096)
#define PTR_ERR(p) ((int)(intptr_t)(p))
#define spin_lock_init(p) (*(p) = 0)
#define init_waitqueue_head(p) (*(p) = 0)
#define spin_lock_irqsave(p, f) do { f = 0; assert(!*(p)); *(p) = 1; } while (0)
#define spin_unlock_irqrestore(p, f) do { (void)(f); assert(*(p)); *(p) = 0; } while (0)
#define wait_event_timeout(q, c, t) do { (void)(q); (void)(t); mock_wait(); (void)(c); } while (0)
#define msecs_to_jiffies(v) (v)
struct device { int unused; };
struct apr_device { int unused; };
struct q6apm { struct device *dev; struct apr_device *gdev; };
struct gpr_hdr {
	u32 version:4, hdr_size:4, pkt_size:24;
	u32 dest_domain:8, src_domain:8, reserved:16;
	u32 src_port, dest_port, token, opcode;
} __attribute__((packed));
struct gpr_pkt { struct gpr_hdr hdr; u32 payload[]; };
struct gpr_resp_pkt { struct gpr_hdr hdr; void *payload; int payload_size; };
#define GPR_HDR_SIZE sizeof(struct gpr_hdr)
typedef struct {
	int id;
	int (*callback)(const struct gpr_resp_pkt *, void *, int);
	void *context;
} gpr_port_t;
static gpr_port_t *port;
static int allocations, fail_allocation, allocation_index, sent, wakes, scenario;
static unsigned int requested_mask;
static u32 current_token, previous_token;
static unsigned char reply_bytes[28];
static struct gpr_resp_pkt response;
enum {
	GOOD, FIRST_ERROR, SECOND_ERROR, TIMEOUT, SHORT_SEND, SEND_ERROR,
	BAD_LENGTH, WRONG_TOKEN, ACCEPTED, BASIC_ACK, WRONG_DOMAIN, DUPLICATE,
	OLD_RX_IN_TX, TRANSPORT_GONE, NEGATIVE_LENGTH, WAITED, SCENARIOS
};
static void *kzalloc(size_t n, int flags)
{
	void *p;
	(void)flags;
	if (++allocation_index == fail_allocation) return NULL;
	p = calloc(1, n); assert(p); allocations++;
	return p;
}
static void kfree(void *p) { if (p) { allocations--; free(p); } }
static void wake_up(wait_queue_head_t *q) { (void)q; wakes++; }
static gpr_port_t *gpr_alloc_port(struct apr_device *apm, struct device *dev,
		int (*callback)(const struct gpr_resp_pkt *, void *, int), void *context)
{
	(void)apm; (void)dev;
	port = kzalloc(sizeof(*port), 0);
	if (!port) return (gpr_port_t *)(intptr_t)-ENOMEM;
	port->id = 0x1234; port->callback = callback; port->context = context;
	return port;
}
static void deliver(void) { port->callback(&response, port->context, 0); }
static void gpr_free_port(gpr_port_t *p)
{
	assert(p == port);
	/* Emulate a queued callback drained while its private client still exists. */
	deliver();
	kfree(p); port = NULL;
}
static void mock_wait(void)
{
	if (scenario == WAITED) deliver();
}
static int gpr_send_port_pkt(gpr_port_t *p, const struct gpr_pkt *packet)
{
	const unsigned char *request_bytes = (const unsigned char *)packet->payload;
	u32 instance = sent ? 0x49fd : 0x4040;
	u32 parameter = sent ? 0x11111601 : 0x11111611;
	unsigned int bit = sent++;
	assert(p == port && bit < 2);
	assert(packet->hdr.version == 0 && packet->hdr.hdr_size == 6);
	assert(packet->hdr.pkt_size == 64 && !packet->hdr.reserved);
	assert(packet->hdr.src_domain == 3 && packet->hdr.dest_domain == 2);
	assert(packet->hdr.src_port == 0x1234 && packet->hdr.dest_port == 1);
	assert(packet->hdr.opcode == 0x01001007);
	assert(packet->hdr.token > previous_token);
	previous_token = packet->hdr.token;
	assert(!uke_rb_word(request_bytes) && !uke_rb_word(request_bytes + 4) &&
	       !uke_rb_word(request_bytes + 8) && uke_rb_word(request_bytes + 12) == 24);
	assert(uke_rb_word(request_bytes + 16) == instance &&
	       uke_rb_word(request_bytes + 20) == parameter &&
	       uke_rb_word(request_bytes + 24) == 4 &&
	       !uke_rb_word(request_bytes + 28) && !uke_rb_word(request_bytes + 32) &&
	       !uke_rb_word(request_bytes + 36));
	current_token = packet->hdr.token;
	memset(reply_bytes, 0, sizeof(reply_bytes));
	uke_rb_put(reply_bytes + 4, instance);
	uke_rb_put(reply_bytes + 8, parameter);
	uke_rb_put(reply_bytes + 12, 4);
	uke_rb_put(reply_bytes + 20, !!(requested_mask & (1U << bit)));
	/* Optional alignment may contain arbitrary bytes, independently of data. */
	uke_rb_put(reply_bytes + 24, 0xa5c3f17bU);
	response = (struct gpr_resp_pkt) {
		.hdr = { .hdr_size = 6, .pkt_size = 52, .src_domain = 2, .reserved = 0xc8,
			.dest_domain = 3, .src_port = 1, .dest_port = 0x1234,
			.token = current_token, .opcode = UKE_RB_GET_REPLY },
		.payload = reply_bytes, .payload_size = 28,
	};
	if (scenario == SHORT_SEND) return 63;
	if (scenario == SEND_ERROR) return -EAGAIN;
	if (scenario == TIMEOUT || scenario == WAITED) return 64;
	if (scenario == TRANSPORT_GONE) {
		p->callback(NULL, p->context, -ENODEV); return 64;
	}
	if (scenario == FIRST_ERROR || (scenario == SECOND_ERROR && bit))
		uke_rb_put(reply_bytes, 3);
	if (scenario == BAD_LENGTH) response.hdr.pkt_size--;
	if (scenario == WRONG_TOKEN) response.hdr.token++;
	if (scenario == NEGATIVE_LENGTH) response.payload_size = -1;
	if (scenario == ACCEPTED || scenario == BASIC_ACK) {
		unsigned char interim[8] = {0};
		struct gpr_resp_pkt ack = response;
		uke_rb_put(interim, UKE_RB_GET_CFG);
		ack.payload = interim;
		ack.payload_size = scenario == ACCEPTED ? 4 : 8;
		ack.hdr.pkt_size = 24 + ack.payload_size;
		ack.hdr.opcode = scenario == ACCEPTED ? UKE_RB_ACCEPTED : UKE_RB_BASIC_REPLY;
		p->callback(&ack, p->context, 0);
		assert(!wakes || bit); /* No terminal wake for this ACK. */
	}
	if (scenario == WRONG_DOMAIN || (scenario == OLD_RX_IN_TX && bit)) {
		struct gpr_resp_pkt stale = response;
		if (scenario == WRONG_DOMAIN) stale.hdr.src_domain = 3;
		else stale.hdr.token--;
		p->callback(&stale, p->context, 0);
	}
	deliver();
	if (scenario == DUPLICATE) deliver();
	return 64;
}
#include "native-readback.inc"

static void trial(int which, unsigned int mask, int expected)
{
	unsigned int result = 0xdead;
	struct device dev = {0};
	struct apr_device gdev = {0};
	struct q6apm apm = {.dev = &dev, .gdev = &gdev};
	scenario = which; sent = wakes = allocation_index = 0; requested_mask = mask;
	assert(q6apm_fs19xx_read_enables(&apm, &result) == expected);
	assert(result == (expected ? 0 : mask));
	assert(!allocations && !port);
}
int main(void)
{
	unsigned int i, cases = 0;
	int expected[] = {0, -EREMOTEIO, -EREMOTEIO, -ETIMEDOUT, -EIO, -EAGAIN,
		-EPROTO, -ETIMEDOUT, 0, 0, 0, 0, 0, -ENODEV, -ETIMEDOUT, 0};
	for (i = 0; i < 4; i++) { trial(GOOD, i, 0); cases++; }
	for (i = 1; i < SCENARIOS; i++) { trial(i, 3, expected[i]); cases++; }
	for (i = 1; i <= 3; i++) {
		fail_allocation = i; trial(GOOD, 3, -ENOMEM); cases++;
	}
	fail_allocation = 0;
	uke_rb_tokens.value = UINT32_MAX - 1;
	trial(GOOD, 3, -EOVERFLOW); cases++;
	printf("Production FS19xx readback transport: %u synthetic cases passed.\n", cases);
	return 0;
}
