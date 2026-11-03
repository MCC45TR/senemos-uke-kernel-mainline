/* SPDX-License-Identifier: GPL-2.0-only */
/* Known-wire APM/IMCL fixture; no DSP, firmware or hardware access. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "audioreach-control-links.h"

int main(void)
{
	struct audioreach_ctrl_link links[AR_CTRL_LINK_MAX_COUNT + 1] = {
		{0x4040, 0x80000000, 0x49fd, 0x80000000, 0x08001231, 1},
	};
	/* Independent graph-open parameter, from the documented public APM ABI. */
	static const uint32_t expected[] = {
		1, 0x08001061, 52, 0, 1,
		0x4040, 0x80000000, 0x49fd, 0x80000000, 2,
		0x08001062, 8, 1, 0x08001231, 0x0800136f, 4, 1, 0,
	};
	_Alignas(8) uint8_t buffer[2048];
	unsigned int i;

	assert(audioreach_ctrl_links_size(0) == 0);
	assert(audioreach_ctrl_links_size(1) == sizeof(expected));
	assert(audioreach_ctrl_links_size(UINT32_MAX) == -E2BIG);
	assert(audioreach_ctrl_links_pack(NULL, 0, NULL, 0) == 0);
	memset(buffer, 0xa5, sizeof(buffer));
	assert(audioreach_ctrl_links_pack(buffer, sizeof(buffer), links, 1) == 72);
	for (i = 0; i < sizeof(expected) / 4; i++) {
		uint32_t word;
		memcpy(&word, buffer + 4 * i, 4);
		assert(le32_to_cpu(word) == expected[i]);
	}
	for (i = sizeof(expected); i < sizeof(buffer); i++) assert(buffer[i] == 0xa5);
	for (i = 0; i < 72; i++) {
		memset(buffer, 0xa5, sizeof(buffer));
		assert(audioreach_ctrl_links_pack(buffer, i, links, 1) == -EINVAL);
		for (unsigned int j = 0; j < sizeof(buffer); j++) assert(buffer[j] == 0xa5);
	}
	for (i = 0; i < 6; i++) {
		struct audioreach_ctrl_link bad = links[0];
		switch (i) {
		case 0: bad.first_instance = 0; break;
		case 1: bad.first_port = 0; break;
		case 2: bad.second_instance = 0; break;
		case 3: bad.second_port = 0; break;
		case 4: bad.intent = 0; break;
		case 5: bad.heap = 4; break;
		}
		assert(audioreach_ctrl_links_pack(buffer, sizeof(buffer), &bad, 1) == -EINVAL);
	}
	links[1] = links[0];
	assert(audioreach_ctrl_links_pack(buffer, sizeof(buffer), links, 2) == -EINVAL);
	links[1] = (struct audioreach_ctrl_link) {
		0x49fd, 0x80000000, 0x4040, 0x80000000, 0x08001231, 1};
	assert(audioreach_ctrl_links_pack(buffer, sizeof(buffer), links, 2) == -EINVAL);
	links[1] = (struct audioreach_ctrl_link) {1, 1, 1, 1, 1, 1};
	assert(audioreach_ctrl_links_pack(buffer, sizeof(buffer), links, 2) == -EINVAL);
	for (i = 0; i < AR_CTRL_LINK_MAX_COUNT; i++)
		links[i] = (struct audioreach_ctrl_link) {1 + i, 1, 100 + i, 2, 1, 1};
	assert(audioreach_ctrl_links_pack(buffer, sizeof(buffer), links,
		AR_CTRL_LINK_MAX_COUNT) == audioreach_ctrl_links_size(AR_CTRL_LINK_MAX_COUNT));
	assert(audioreach_ctrl_links_pack(buffer, sizeof(buffer), links,
		AR_CTRL_LINK_MAX_COUNT + 1) == -E2BIG);
	puts("AudioReach control-link wire, bounds and rejection fixtures passed; no device access.");
	return 0;
}
