/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual backend with independent GPR/DMA providers; synthetic bytes only. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "uke-fs19xx-oob.h"
typedef uint8_t u8;
typedef uint32_t u32;
typedef uint64_t u64;
typedef uint64_t dma_addr_t;
typedef int spinlock_t;
typedef int wait_queue_head_t;
#define GFP_KERNEL 0
#define THIS_MODULE NULL
#define HZ 100
#define GPR_DOMAIN_ID_ADSP 2
#define GPR_DOMAIN_ID_APPS 3
#define GPR_PKT_VER 0
#define GPR_PKT_HEADER_WORD_SIZE 6
#define GPR_BASIC_RSP_RESULT 0x02001005
#define GPR_BASIC_EVT_ACCEPTED 0x02001006
#define READ_ONCE(v) (v)
#define lower_32_bits(v) ((u32)(v))
#define upper_32_bits(v) ((u32)((u64)(v) >> 32))
#define IS_ERR(v) ((intptr_t)(v) < 0 && (intptr_t)(v) > -4096)
#define PTR_ERR(v) ((int)(intptr_t)(v))
#define spin_lock_init(p) (*(p) = 0)
#define spin_lock_irqsave(p, f) do { (f) = 0; assert(!*(p)); *(p) = 1; } while (0)
#define spin_unlock_irqrestore(p, f) do { (void)(f); assert(*(p)); *(p) = 0; } while (0)
#define init_waitqueue_head(p) (*(p) = 0)
#define wait_event_timeout(q, c, t) do { (void)(q); (void)(t); mock_wait(); (void)(c); } while (0)
struct device { int refs; };
struct apr_device { int unused; };
struct q6apm { struct device *dev; struct apr_device *gdev; };
#define __packed __attribute__((packed))
#include "native-gpr-wire.inc"
#undef __packed
#define GPR_HDR_SIZE sizeof(struct gpr_hdr)
typedef struct {
	int id;
	int (*callback)(const struct gpr_resp_pkt *, void *, int);
	void *context;
} gpr_port_t;
struct uke_audio_config_memory {
	void *area; dma_addr_t dma; u64 dsp_address; u32 bytes, first_token;
};
static unsigned client_data, forbidden_bit = 8;
static int module_refs, allocation_call, fail_allocation, live_allocations;
static int free_ports, acquire_count, release_count, quarantine_count, send_count;
static int wmb_count, rmb_count, scenario;
static bool busy, poisoned, delayed;
static u32 next_token = 1;
static struct uke_audio_config_memory active_memory;
static gpr_port_t *active_port;
static struct gpr_resp_pkt previous_reply, delayed_reply;
static u8 previous_payload[8], delayed_payload[8];
static u8 expected_tuning[5360];
enum {
	GOOD, DELAYED, MAP_BASIC, MAP_TIMEOUT, SET_TIMEOUT, UNMAP_TIMEOUT,
	MAP_SEND_FAIL, SET_SEND_FAIL, UNMAP_SEND_FAIL, SHORT_SEND,
	ZERO_HANDLE, MAP_BAD_LENGTH, SET_BAD_LENGTH, MAP_ERROR, SET_ERROR,
	UNMAP_ERROR, MODULE_ERROR, CHANGED_TUNING,
	WRONG_SOURCE_DOMAIN, WRONG_DEST_DOMAIN, WRONG_SOURCE_PORT,
	WRONG_DEST_PORT, WRONG_TOKEN, BAD_VERSION, BAD_HEADER_SIZE,
	BAD_PACKET_SIZE, BAD_RESERVED, BAD_OPCODE, BAD_ECHO, DUPLICATE,
	SCENARIOS
};
struct allocation { size_t bytes; };
static void *kzalloc(size_t bytes, int flags)
{
	struct allocation *p;
	(void)flags;
	if (++allocation_call == fail_allocation)
		return NULL;
	p = calloc(1, sizeof(*p) + bytes);
	assert(p);
	p->bytes = bytes;
	live_allocations++;
	return p + 1;
}
static void kfree(void *area)
{
	if (area) { live_allocations--; free((struct allocation *)area - 1); }
}
static void kfree_sensitive(void *area)
{
	struct allocation *p = (struct allocation *)area - 1;
	memset(area, 0, p->bytes);
	kfree(area);
}
static void memzero_explicit(void *area, size_t bytes) { memset(area, 0, bytes); }
static void dma_wmb(void) { wmb_count++; }
static void __attribute__((unused)) dma_rmb(void) { rmb_count++; }
static bool try_module_get(void *p) { (void)p; module_refs++; return true; }
static void module_put(void *p) { (void)p; assert(module_refs > 0); module_refs--; }
static struct device *get_device(struct device *d) { d->refs++; return d; }
static void put_device(struct device *d) { assert(d->refs > 0); d->refs--; }
static void wake_up(wait_queue_head_t *q) { (*q)++; }
static void mock_wait(void);
static int uke_audio_config_ready(void) { return 0; }
static gpr_port_t *gpr_alloc_port(struct apr_device *, struct device *,
				int (*)(const struct gpr_resp_pkt *, void *, int), void *);
static void gpr_free_port(gpr_port_t *);
static int gpr_send_port_pkt(gpr_port_t *, const struct gpr_pkt *);
static int uke_audio_config_acquire(struct device *d, struct uke_audio_config_memory *m)
{
	assert(d);
	acquire_count++;
	if (busy || poisoned) return -EBUSY;
	*m = (struct uke_audio_config_memory){calloc(1,8192), 0x12340000,
		0x112340000ULL, 8192, next_token};
	assert(m->area);
	next_token += 3;
	active_memory = *m;
	busy = true;
	return 0;
}
static void check_erased(void)
{
	assert(active_memory.area);
	for (u32 i = 0; i < active_memory.bytes; i++)
		assert(!((u8 *)active_memory.area)[i]);
}
static void uke_audio_config_release(struct uke_audio_config_memory *m, bool uncertain)
{
	assert(busy && m->area == active_memory.area);
	check_erased();
	if (uncertain) { poisoned = true; quarantine_count++; return; }
	assert(!poisoned);
	free(m->area);
	memset(&active_memory, 0, sizeof(active_memory));
	memset(m, 0, sizeof(*m));
	busy = false;
	release_count++;
}
#include "native-backend.inc"

static gpr_port_t *gpr_alloc_port(struct apr_device *g, struct device *d,
		int (*callback)(const struct gpr_resp_pkt *, void *, int), void *context)
{
	gpr_port_t *p = calloc(1, sizeof(*p));
	assert(g && d && p && !active_port);
	p->id = 1024; p->callback = callback; p->context = context;
	active_port = p;
	return p;
}
static void gpr_free_port(gpr_port_t *p)
{
	struct uke_oob_client *c = p->context;
	assert(!c->pending && !c->retained);
	/* Callback drain while its independent client is still alive. */
	if (previous_reply.payload) p->callback(&previous_reply, c, 0);
	free_ports++;
	assert(active_port == p);
	active_port = NULL;
	free(p);
}
static void copy_reply(struct gpr_resp_pkt *out, u8 *payload,
		       const struct gpr_resp_pkt *in)
{
	*out = *in;
	memcpy(payload, in->payload, (size_t)in->payload_size);
	out->payload = payload;
}
static int gpr_send_port_pkt(gpr_port_t *port, const struct gpr_pkt *packet)
{
	struct uke_oob_client *c = port->context;
	u32 command = packet->hdr.opcode;
	u8 payload[8] = {0};
	struct gpr_resp_pkt response = { .hdr = packet->hdr, .payload = payload };
	bool map = command == UKE_OOB_MAP, config = command == UKE_OOB_SET_CFG;
	assert(module_refs && c->device->refs && !c->lock && wmb_count);
	assert(packet->hdr.src_domain == 3 && packet->hdr.dest_domain == 2);
	assert(packet->hdr.src_port == 1024 && packet->hdr.dest_port == 1);
	assert(packet->hdr.token == active_memory.first_token + (u32)send_count);
	send_count++;
	assert(packet->hdr.pkt_size == (map ? 44u : config ? 40u : 28u));
	if (map) {
		const u8 *p = (const u8 *)packet->payload;
		assert(uke_oob_get32(p) == 0x10003 && !uke_oob_get32(p+4));
		assert(uke_oob_get32(p+8) == 0x12340000 && uke_oob_get32(p+12) == 1);
		assert(uke_oob_get32(p+16) == 8192);
		assert(uke_oob_get32(active_memory.area) == 0x4040);
		assert(!memcmp((u8 *)active_memory.area+16, expected_tuning, 5360));
	} else if (config) {
		const u8 *p = (const u8 *)packet->payload;
		assert(uke_oob_get32(p) == 0x12340000 && uke_oob_get32(p+4) == 1);
		assert(uke_oob_get32(p+8) == 0x2468 && uke_oob_get32(p+12) == 5376);
		if (scenario == MODULE_ERROR) uke_oob_put32((u8 *)active_memory.area+12, 7);
		if (scenario == CHANGED_TUNING) ((u8 *)active_memory.area)[100] ^= 1;
	} else assert(uke_oob_get32((const u8 *)packet->payload) == 0x2468);
	if ((map && scenario == MAP_SEND_FAIL) || (config && scenario == SET_SEND_FAIL) ||
	    (!map && !config && scenario == UNMAP_SEND_FAIL)) return -EIO;
	if (map && scenario == SHORT_SEND) return 0;
	if ((map && scenario == MAP_TIMEOUT) || (config && scenario == SET_TIMEOUT) ||
	    (!map && !config && scenario == UNMAP_TIMEOUT)) return packet->hdr.pkt_size;
	/* Independent documented GPR wire word: domains plus full client-data byte. */
	u8 domain_wire[4];
	uke_oob_put32(domain_wire, 3u | (2u << 8) | (client_data << 16));
	memcpy((u8 *)&response.hdr + 4, domain_wire, sizeof(domain_wire));
	response.hdr.src_port = 1; response.hdr.dest_port = 1024;
	response.hdr.opcode = map ? 0x02001001 : GPR_BASIC_RSP_RESULT;
	response.payload_size = map ? 4 : 8;
	response.hdr.pkt_size = 24 + response.payload_size;
	uke_oob_put32(payload, map ? 0x2468 : command);
	if (scenario == DUPLICATE && previous_reply.payload) {
		port->callback(&previous_reply, c, 0);
		assert(c->pending && !c->done);
	}
	if (map && scenario >= WRONG_SOURCE_DOMAIN && scenario <= WRONG_TOKEN) {
		struct gpr_resp_pkt foreign = response;
		switch (scenario) {
		case WRONG_SOURCE_DOMAIN: foreign.hdr.src_domain++; break;
		case WRONG_DEST_DOMAIN: foreign.hdr.dest_domain++; break;
		case WRONG_SOURCE_PORT: foreign.hdr.src_port++; break;
		case WRONG_DEST_PORT: foreign.hdr.dest_port++; break;
		default: foreign.hdr.token++; break;
		}
		port->callback(&foreign, c, 0);
		assert(c->pending && !c->done);
	}
	if (map && scenario == MAP_BASIC) {
		struct gpr_resp_pkt intermediate = response;
		intermediate.hdr.opcode = GPR_BASIC_RSP_RESULT;
		intermediate.hdr.pkt_size = 32; intermediate.payload_size = 8;
		uke_oob_put32(payload, command);
		port->callback(&intermediate, c, 0);
		assert(c->pending && !c->done);
		intermediate.hdr.opcode = GPR_BASIC_EVT_ACCEPTED;
		intermediate.hdr.pkt_size = 28; intermediate.payload_size = 4;
		port->callback(&intermediate, c, 0);
		assert(c->pending && !c->done);
		uke_oob_put32(payload, 0x2468);
	}
	if (map && scenario == ZERO_HANDLE) uke_oob_put32(payload, 0);
	if ((map && scenario == MAP_BAD_LENGTH) || (config && scenario == SET_BAD_LENGTH)) {
		response.payload_size--; response.hdr.pkt_size--;
	}
	if ((map && scenario == MAP_ERROR) || (config && scenario == SET_ERROR) ||
	    (!map && !config && scenario == UNMAP_ERROR)) {
		response.hdr.opcode = GPR_BASIC_RSP_RESULT;
		response.hdr.pkt_size = 32; response.payload_size = 8;
		uke_oob_put32(payload, command); uke_oob_put32(payload+4, 24);
	}
	if (map) switch (scenario) {
	case BAD_VERSION: response.hdr.version = 1; break;
	case BAD_HEADER_SIZE: response.hdr.hdr_size--; break;
	case BAD_PACKET_SIZE: response.hdr.pkt_size++; break;
	case BAD_RESERVED: response.hdr.reserved |= 1u << forbidden_bit; break;
	case BAD_OPCODE: response.hdr.opcode++; break;
	case BAD_ECHO:
		response.hdr.opcode = GPR_BASIC_RSP_RESULT;
		response.hdr.pkt_size = 32; response.payload_size = 8;
		uke_oob_put32(payload, UKE_OOB_UNMAP); break;
	default: break;
	}
	copy_reply(&previous_reply, previous_payload, &response);
	if (scenario == DELAYED) {
		copy_reply(&delayed_reply, delayed_payload, &response); delayed = true;
	} else port->callback(&response, c, 0);
	return packet->hdr.pkt_size;
}
static void mock_wait(void)
{
	if (delayed) { delayed = false; active_port->callback(&delayed_reply, active_port->context, 0); }
}
static void run_case(int which, int allocation_failure)
{
	struct device device = {0}; struct apr_device gdev = {0};
	struct q6apm apm = {&device, &gdev};
	int expected = 0;
	bool retain = false;
	scenario = which; allocation_call = 0; fail_allocation = allocation_failure;
	free_ports = acquire_count = release_count = quarantine_count = send_count = 0;
	wmb_count = rmb_count = 0; previous_reply.payload = NULL;
	assert(!module_refs && !live_allocations && !busy && !active_port);
	if (which >= MAP_TIMEOUT && which <= UNMAP_TIMEOUT) { expected = -ETIMEDOUT; retain = true; }
	if (which >= MAP_SEND_FAIL && which <= SHORT_SEND) { expected = -EIO; retain = true; }
	if ((which >= ZERO_HANDLE && which <= SET_BAD_LENGTH) ||
	    (which >= BAD_VERSION && which <= BAD_ECHO)) { expected = -EPROTO; retain = true; }
	if (which >= MAP_ERROR && which <= MODULE_ERROR) {
		expected = -EREMOTEIO; retain = which == MAP_ERROR || which == UNMAP_ERROR;
	}
	if (which == CHANGED_TUNING) expected = -EPROTO;
	if (allocation_failure) { expected = -ENOMEM; retain = allocation_failure == 4; }
	assert(q6apm_fs19xx_oob_send(&apm,0x4040,0x10001fb0,expected_tuning,5360) == expected);
	assert(quarantine_count == (int)retain);
	if (retain) {
		struct uke_oob_client *c = active_port->context;
		assert(c->retained && c->buffer.state == UKE_OOB_QUARANTINED);
		assert(module_refs == 1 && device.refs == 1 && busy && poisoned && !free_ports);
		check_erased();
		/* Simulated APM unbind leaves only independent callback state. */
		apm.dev = NULL; apm.gdev = NULL;
		if (previous_reply.payload) active_port->callback(&previous_reply,c,0);
		assert(module_refs == 1 && busy && !release_count);
		/* Fixture power-off only, never a production timeout recovery. */
		free(active_memory.area); memset(&active_memory,0,sizeof(active_memory));
		put_device(c->device); kfree_sensitive(c); free(active_port);
		active_port = NULL; busy = poisoned = false; module_put(NULL);
	} else {
		assert(!module_refs && !device.refs && !busy && !active_port);
		assert(free_ports == (allocation_failure == 1 ? 0 : 1));
		if (!expected) assert(send_count == 3 && rmb_count == 3 && release_count == 1);
	}
	assert(!live_allocations && !module_refs);
}
int main(void)
{
	assert(sizeof(struct gpr_hdr) == 24);
	assert(!q6apm_fs19xx_oob_ready() && !acquire_count);
	for (unsigned int i=0; i<sizeof(expected_tuning); i++) expected_tuning[i]=(u8)(i*29+7);
	assert(offsetof(struct gpr_resp_pkt, payload) == 24);
	assert(offsetof(struct gpr_resp_pkt, payload_size) == 32);
	for (client_data=0; client_data<256; client_data++) {
		for (int i=0; i<SCENARIOS; i++) run_case(i,0);
		for (int i=1; i<=4; i++) run_case(GOOD,i);
	}
	client_data = 200;
	for (forbidden_bit=8; forbidden_bit<16; forbidden_bit++) run_case(BAD_RESERVED,0);
	printf("Actual Uke GPR client-byte peer: %u cases, all256 target client values,8 true-reserved bits, exact wire/tuning and retained lifetime passed; synthetic only.\n", (unsigned)((SCENARIOS+4)*256+8));
	return 0;
}
