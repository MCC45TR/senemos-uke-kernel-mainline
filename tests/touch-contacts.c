/* SPDX-License-Identifier: GPL-2.0-or-later */
#include <assert.h>
#include <errno.h>
#include <string.h>
#include "../src/input/nt36532-uke-protocol.h"

static u8 packet[NVT_UKE_GESTURE_SIZE];
static void checksum(void)
{
	unsigned int sum = 0;
	for (unsigned int i = 0; i < sizeof(packet) - 1; i++)
		sum += packet[i];
	packet[sizeof(packet) - 1] = (u8)-sum;
}
static void empty(void)
{
	memset(packet, 0xff, sizeof(packet));
	checksum();
}
static void point(unsigned int index, unsigned int id, unsigned int state,
		  unsigned int x, unsigned int y)
{
	u8 *p = packet + index * 6;
	p[0] = (u8)((id << 3) | state);
	p[1] = (u8)(x >> 4); p[2] = (u8)(y >> 4);
	p[3] = (u8)(((x & 15) << 4) | (y & 15));
	checksum();
}
int main(void)
{
	struct nvt_uke_contacts contacts, previous;

	empty();
	assert(!nvt_uke_decode_contacts(packet, sizeof(packet), 3199, 2135, &contacts));
	assert(!contacts.active);
	for (unsigned int i = 0; i < NVT_UKE_CONTACTS; i++)
		point(i, NVT_UKE_CONTACTS - i, i % 2 + 1, i * 321, i * 233);
	assert(!nvt_uke_decode_contacts(packet, sizeof(packet), 3199, 2135, &contacts));
	assert(contacts.active == 0x3ff);
	for (unsigned int i = 0; i < NVT_UKE_CONTACTS; i++) {
		assert(contacts.x[9 - i] == i * 321);
		assert(contacts.y[9 - i] == i * 233);
	}
	empty(); point(0, 1, 1, 0, 0); point(9, 10, 2, 3199, 2135);
	assert(!nvt_uke_decode_contacts(packet, sizeof(packet), 3199, 2135, &contacts));
	assert(contacts.active == 0x201 && !contacts.x[0] && !contacts.y[0]);
	assert(contacts.x[9] == 3199 && contacts.y[9] == 2135);
	point(0, 1, 3, 4095, 4095);
	assert(!nvt_uke_decode_contacts(packet, sizeof(packet), 3199, 2135, &contacts));
	assert(contacts.active == 0x200);
	previous = contacts;
	for (unsigned int i = 0; i < sizeof(packet); i++) {
		packet[i] ^= 1;
		assert(nvt_uke_decode_contacts(packet, sizeof(packet), 3199, 2135, &contacts) == -EBADMSG);
		assert(!memcmp(&contacts, &previous, sizeof(contacts)));
		packet[i] ^= 1;
	}
	for (unsigned int size = 0; size < sizeof(packet); size++)
		assert(nvt_uke_decode_contacts(packet, size, 3199, 2135, &contacts) == -EINVAL);
	assert(nvt_uke_decode_contacts(packet, sizeof(packet) + 1, 3199, 2135, &contacts) == -EINVAL);
	assert(nvt_uke_decode_contacts(NULL, sizeof(packet), 3199, 2135, &contacts) == -EINVAL);
	assert(nvt_uke_decode_contacts(packet, sizeof(packet), 3199, 2135, NULL) == -EINVAL);
	assert(nvt_uke_decode_contacts(packet, sizeof(packet), 0, 2135, &contacts) == -EINVAL);
	assert(nvt_uke_decode_contacts(packet, sizeof(packet), 4096, 2135, &contacts) == -EINVAL);
	for (unsigned int id = 0; id < 12; id++) {
		if (id >= 1 && id <= 10) continue;
		empty(); point(0, id, 1, 0, 0);
		assert(nvt_uke_decode_contacts(packet, sizeof(packet), 3199, 2135, &contacts) == -EPROTO);
	}
	for (unsigned int state = 0; state < 8; state++) {
		if (state >= 1 && state <= 3) continue;
		empty(); point(0, 1, state, 0, 0);
		assert(nvt_uke_decode_contacts(packet, sizeof(packet), 3199, 2135, &contacts) == -EPROTO);
	}
	empty(); point(0, 1, 1, 1, 1); point(9, 1, 2, 2, 2);
	assert(nvt_uke_decode_contacts(packet, sizeof(packet), 3199, 2135, &contacts) == -EPROTO);
	empty(); point(0, 1, 1, 3200, 0);
	assert(nvt_uke_decode_contacts(packet, sizeof(packet), 3199, 2135, &contacts) == -ERANGE);
	empty(); point(0, 1, 1, 0, 2136);
	assert(nvt_uke_decode_contacts(packet, sizeof(packet), 3199, 2135, &contacts) == -ERANGE);
	assert(!memcmp(&contacts, &previous, sizeof(contacts)));
}
