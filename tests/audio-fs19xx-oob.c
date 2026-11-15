/* SPDX-License-Identifier: GPL-2.0-only */
/* Independent fake APM peer: exact wire bytes and remote memory ownership. */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include "uke-fs19xx-oob.h"

enum failure {
	OK, ALLOC, BAD_ALIGN, BAD_HIGH, BAD_END, BAD_SIZE, MAP_UNSENT,
	MAP_TIMEOUT, MAP_ERROR, MAP_ZERO, SET_UNSENT, SET_TIMEOUT,
	SET_ERROR, SET_MODULE_ERROR, SET_MUTATION,
	UNMAP_UNSENT, UNMAP_TIMEOUT, UNMAP_ERROR,
};
struct peer {
	enum failure failure;
	unsigned allocations, commands, erases, frees, retained;
	bool mapped, reading;
	unsigned char *pages;
	unsigned char original[5360];
	uint32_t low, high;
};
static uint32_t read32(const unsigned char *p)
{
	return p[0] + 256U * p[1] + 65536U * p[2] + 16777216U * p[3];
}
static int allocate(void *context, struct uke_oob_buffer *b)
{
	struct peer *p = context;
	p->allocations++;
	if (p->failure == ALLOC)
		return -ENOMEM;
	p->pages = malloc(8192);
	assert(p->pages);
	memset(p->pages, 0xa5, 8192);
	b->data = p->pages;
	b->bytes = p->failure == BAD_SIZE ? 4096 : 8192;
	b->address_low = p->failure == BAD_ALIGN ? 0x12340020U : p->low;
	b->address_high = p->failure == BAD_HIGH ? 16 : p->high;
	if (p->failure == BAD_END) {
		b->address_high = 15;
		b->address_low = 0xfffff000U;
	}
	return 0;
}
static void erased(struct peer *p)
{
	for (size_t i = 0; i < 8192; i++)
		assert(p->pages[i] == 0);
}
static void erase(void *context, struct uke_oob_buffer *b)
{
	struct peer *p = context;
	assert(b->data == p->pages);
	/* Backend owns the actual allocation size, including invalid metadata. */
	memset(p->pages, 0, 8192);
	p->erases++;
}
static void release(void *context, struct uke_oob_buffer *b)
{
	struct peer *p = context;
	assert(b->data == p->pages && !p->mapped && !p->reading);
	erased(p);
	free(p->pages);
	p->pages = NULL;
	p->frees++;
}
static void quarantine(void *context, struct uke_oob_buffer *b)
{
	struct peer *p = context;
	assert(b->data == p->pages && b->state == UKE_OOB_QUARANTINED);
	erased(p);
	p->retained++;
}
static struct uke_oob_reply command(void *context, uint32_t opcode,
		const unsigned char *wire, size_t bytes)
{
	struct peer *p = context;
	struct uke_oob_reply r = {.sent = true, .complete = true};
	p->commands++;
	if (opcode == 0x0100100c) {
		assert(p->commands == 1 && bytes == 20 && !p->mapped);
		assert(wire[0] == 3 && wire[1] == 0 && wire[2] == 1 && wire[3] == 0);
		assert(read32(wire + 4) == 0);
		assert(read32(wire + 8) == p->low && read32(wire + 12) == p->high);
		assert((read32(wire + 8) & 4095) == 0 && read32(wire + 16) == 8192);
		if (p->failure == MAP_UNSENT)
			return (struct uke_oob_reply){.error = -ENOMEM};
		/* Timeout/error does not prove that the peer did not map it. */
		p->mapped = true;
		if (p->failure == MAP_TIMEOUT)
			return (struct uke_oob_reply){.sent = true, .error = -ETIMEDOUT};
		if (p->failure == MAP_ERROR) {
			r.error = -EREMOTEIO;
			return r;
		}
		r.handle = p->failure == MAP_ZERO ? 0 : 0x51a9;
		return r;
	}
	if (opcode == 0x01001006) {
		assert(p->commands == 2 && bytes == 16 && p->mapped && !p->reading);
		assert(read32(wire) == p->low && read32(wire + 4) == p->high);
		assert(read32(wire + 8) == 0x51a9 && read32(wire + 12) == 5376);
		assert(read32(p->pages) == 0x4040 && read32(p->pages + 4) == 0x10001fb0);
		assert(read32(p->pages + 8) == 5360 && read32(p->pages + 12) == 0);
		assert(!memcmp(p->pages + 16, p->original, 5360));
		for (size_t i = 5376; i < 8192; i++)
			assert(p->pages[i] == 0);
		if (p->failure == SET_UNSENT)
			return (struct uke_oob_reply){.error = -ENOMEM};
		if (p->failure == SET_TIMEOUT) {
			p->reading = true;
			return (struct uke_oob_reply){.sent = true, .error = -ETIMEDOUT};
		}
		if (p->failure == SET_ERROR)
			r.error = -EREMOTEIO;
		if (p->failure == SET_MODULE_ERROR)
			p->pages[12] = 5;
		if (p->failure == SET_MUTATION)
			p->pages[100] ^= 1;
		return r;
	}
	assert(opcode == 0x0100100d && p->commands == 3 && bytes == 4);
	assert(p->mapped && !p->reading && read32(wire) == 0x51a9);
	if (p->failure == UNMAP_UNSENT)
		return (struct uke_oob_reply){.error = -ENOMEM};
	if (p->failure == UNMAP_TIMEOUT)
		return (struct uke_oob_reply){.sent = true, .error = -ETIMEDOUT};
	if (p->failure == UNMAP_ERROR) {
		r.error = -EREMOTEIO;
		return r;
	}
	p->mapped = false;
	return r;
}
static const struct uke_oob_ops ops = {allocate, command, erase, release, quarantine};
static void trial(enum failure mode, int expected, bool retained)
{
	struct peer p = {.failure = mode, .low = 0x12340000, .high = 1};
	struct uke_oob_buffer b = {0};
	for (size_t i = 0; i < sizeof(p.original); i++)
		p.original[i] = (unsigned char)(i * 19 + (i >> 4));
	int ret = uke_fs19xx_oob_transfer(&b, &ops, &p, 0x4040, 0x10001fb0,
					p.original, sizeof(p.original));
	assert(ret == expected && p.allocations == 1);
	assert(p.retained == (unsigned)retained);
	if (retained) {
		assert(p.frees == 0 && b.state == UKE_OOB_QUARANTINED);
		assert(uke_fs19xx_oob_transfer(&b, &ops, &p, 0x4040, 0x10001fb0,
			p.original, sizeof(p.original)) == -EBUSY);
		assert(p.allocations == 1);
		/* Test process teardown simulates reboot, never production recovery. */
		erased(&p);
		free(p.pages);
	} else {
		assert(b.state == UKE_OOB_EMPTY && !b.data);
		assert(p.frees == (mode == ALLOC ? 0U : 1U));
	}
}
int main(void)
{
	trial(OK, 0, false);
	trial(ALLOC, -ENOMEM, false);
	trial(BAD_ALIGN, -EINVAL, false);
	trial(BAD_HIGH, -EINVAL, false);
	trial(BAD_END, -EINVAL, false);
	trial(BAD_SIZE, -EINVAL, false);
	trial(MAP_UNSENT, -ENOMEM, false);
	trial(MAP_TIMEOUT, -ETIMEDOUT, true);
	trial(MAP_ERROR, -EREMOTEIO, true);
	trial(MAP_ZERO, -EPROTO, true);
	trial(SET_UNSENT, -ENOMEM, false);
	trial(SET_TIMEOUT, -ETIMEDOUT, true);
	trial(SET_ERROR, -EREMOTEIO, false);
	trial(SET_MODULE_ERROR, -EREMOTEIO, false);
	trial(SET_MUTATION, -EPROTO, false);
	trial(UNMAP_UNSENT, -ENOMEM, true);
	trial(UNMAP_TIMEOUT, -ETIMEDOUT, true);
	trial(UNMAP_ERROR, -EREMOTEIO, true);
	struct peer p = {0};
	struct uke_oob_buffer b = {0};
	assert(uke_fs19xx_oob_transfer(&b, &ops, &p, 0x4041, 0x10001fb0, p.original, 5360) == -EINVAL);
	assert(uke_fs19xx_oob_transfer(&b, &ops, &p, 0x4040, 0x10001fb1, p.original, 5360) == -EINVAL);
	assert(uke_fs19xx_oob_transfer(&b, &ops, &p, 0x4040, 0x10001fb0, p.original, 5359) == -EINVAL);
	assert(uke_fs19xx_oob_transfer(&b, &ops, &p, 0x4040, 0x10001fb0, NULL, 5360) == -EINVAL);
	assert(!p.allocations && !p.commands);
	puts("Protected OOB core: exact5376-byte TLV, physical map/SET_CFG/unmap wire, module errors, ambiguity quarantine/erasure and retry refusal pass with fake APM peer; no hardware claim.");
	return 0;
}
