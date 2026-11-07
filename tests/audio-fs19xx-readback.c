/* SPDX-License-Identifier: GPL-2.0-only */
/* Synthetic packet tests of the production parser; never open audio hardware. */
#include <assert.h>
#include <stdio.h>
#include "uke-fs19xx-readback.h"

static unsigned int cases;
static struct uke_rb_query query;
static struct uke_rb_envelope envelope;
static unsigned char request[40], response[64];

static void fresh(unsigned int channel, unsigned int enabled, size_t length)
{
	assert(!uke_rb_begin(&query, 0x1234, 42, channel, request, sizeof(request)));
	envelope = (struct uke_rb_envelope) {
		.header_words = 6, .packet_bytes = 24 + length,
		.source_domain = 2, .destination_domain = 3,
		.source_port = 1, .destination_port = 0x1234,
		.token = 42, .opcode = UKE_RB_GET_REPLY,
	};
	memset(response, 0, sizeof(response));
	uke_rb_put(response + 4, channel ? 0x49fd : 0x4040);
	uke_rb_put(response + 8, channel ? 0x11111601 : 0x11111611);
	uke_rb_put(response + 12, 4);
	uke_rb_put(response + 20, enabled);
}
static void finish(int error, bool enabled, size_t length)
{
	assert(uke_rb_reply(&query, &envelope, response, length) == 1);
	assert(!query.pending && query.error == error && query.enabled == enabled);
	cases++;
}
int main(void)
{
	unsigned int channel, enabled, i, variant;
	const size_t lengths[] = {24, 28};
	for (channel = 0; channel < 2; channel++) {
		for (enabled = 0; enabled < 2; enabled++) {
			for (i = 0; i < sizeof(lengths) / sizeof(lengths[0]); i++) {
				fresh(channel, enabled, lengths[i]);
				assert(uke_rb_word(request + 12) == 24);
				assert(uke_rb_word(request + 16) == query.instance);
				assert(uke_rb_word(request + 20) == query.parameter);
				assert(uke_rb_word(request + 24) == 4);
				assert(!uke_rb_word(request) && !uke_rb_word(request + 4) &&
				       !uke_rb_word(request + 8) && !uke_rb_word(request + 28) &&
				       !uke_rb_word(request + 32) && !uke_rb_word(request + 36));
				finish(0, enabled, lengths[i]);
				/* A duplicate cannot replace a disabled/enabled result. */
				uke_rb_put(response + 20, !enabled);
				assert(!uke_rb_reply(&query, &envelope, response, lengths[i]));
				assert(query.enabled == enabled && !query.pending);
				cases++;
			}
		}
	}
	/* Every framing/identity field is independently corrupted. */
	for (variant = 0; variant < 18; variant++) {
		fresh(0, 1, 28);
		switch (variant) {
		case 0: envelope.token++; break;
		case 1: envelope.source_domain++; break;
		case 2: envelope.destination_domain++; break;
		case 3: envelope.source_port++; break;
		case 4: envelope.destination_port++; break;
		case 5: envelope.version++; break;
		case 6: envelope.header_words--; break;
		case 7: envelope.packet_bytes--; break;
		case 8: envelope.reserved = 0x100; break;
		case 9: envelope.opcode++; break;
		case 10: response[4] ^= 1; break;
		case 11: response[8] ^= 1; break;
		case 12: response[12] = 8; break;
		case 13: response[20] = 2; break;
		case 14: response[24] = 1; break;
		case 15: response[16] = 3; break;
		case 16: response[0] = 3; break;
		case 17: response[15] = 0x80; break;
		}
		if (variant < 5) {
			assert(!uke_rb_reply(&query, &envelope, response, 28));
			assert(query.pending && !query.enabled && query.error == -ENODATA);
			cases++;
		} else {
			finish(variant == 15 || variant == 16 ? -EREMOTEIO : -EPROTO, false, 28);
			if (variant == 15 || variant == 16) assert(query.remote_status == 3);
		}
	}
	/* The complete client byte is valid; every high-byte bit remains reserved. */
	for (i = 1; i <= 255; i++) {
		fresh(i & 1, 1, 28);
		envelope.reserved = i;
		finish(0, true, 28);
	}
	for (i = 8; i < 16; i++) {
		fresh(0, 1, 28);
		envelope.reserved = 1U << i;
		finish(-EPROTO, false, 28);
	}
	for (i = 0; i <= 40; i++) {
		if (i == 24 || i == 28) continue;
		fresh(0, 1, i);
		finish(-EPROTO, false, i);
	}
	for (i = 0; i < 3; i++) {
		fresh(1, 1, i == 2 ? 4 : 8);
		if (i < 2) {
			envelope.opcode = UKE_RB_BASIC_REPLY;
			uke_rb_put(response, UKE_RB_GET_CFG);
			uke_rb_put(response + 4, i);
			if (!i) {
				assert(!uke_rb_reply(&query, &envelope, response, 8));
				assert(query.pending && !query.enabled);
				cases++;
			} else finish(-EREMOTEIO, false, 8);
		} else {
			uke_rb_put(response, 3);
			finish(-EREMOTEIO, false, 4);
		}
	}
	fresh(1, 1, 4);
	envelope.opcode = UKE_RB_ACCEPTED;
	uke_rb_put(response, UKE_RB_GET_CFG);
	assert(!uke_rb_reply(&query, &envelope, response, 4));
	assert(query.pending && !query.enabled);
	uke_rb_cancel(&query, -ETIMEDOUT);
	assert(!query.pending && !query.enabled && query.error == -ETIMEDOUT);
	cases++;
	fresh(0, 1, 28);
	assert(uke_rb_reply(&query, &envelope, NULL, 28) == 1);
	assert(query.error == -EPROTO && !query.enabled);
	cases++;
	assert(uke_rb_begin(NULL, 1, 1, 0, request, 40) == -EINVAL);
	assert(uke_rb_begin(&query, 0, 1, 0, request, 40) == -EINVAL);
	assert(uke_rb_begin(&query, 1, 0, 0, request, 40) == -EINVAL);
	assert(uke_rb_begin(&query, 1, 1, 2, request, 40) == -EINVAL);
	assert(uke_rb_begin(&query, 1, 1, 0, request, 39) == -EINVAL);
	assert(uke_rb_begin(&query, 1, 1, 0, NULL, 40) == -EINVAL);
	cases += 6;
	printf("Production FS19xx readback parser: %u synthetic cases passed.\n", cases);
	return 0;
}
