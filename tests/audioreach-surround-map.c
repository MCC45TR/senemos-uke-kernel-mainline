/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual extracted production callback and header constants, no DSP provider. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint8_t u8;
#include "actual-q6apm-channel-ids.h"
#include "actual-audioreach-map.inc"

int main(void)
{
	static const struct {
		unsigned int count;
		u8 map[8];
	} expected[] = {
		{1, {1}}, {2, {1, 2}}, {4, {1, 2, 4, 5}},
		{6, {1, 2, 4, 5, 3, 6}}, {8, {1, 2, 8, 9, 3, 6, 4, 5}},
	};
	unsigned int checks = 0;
	for (unsigned int i = 0; i < sizeof(expected) / sizeof(expected[0]); i++) {
		struct { u8 before[8], map[16], after[8]; } data;
		memset(&data, 0xa5, sizeof(data));
		audioreach_set_default_channel_mapping(data.map, expected[i].count);
		assert(!memcmp(data.map, expected[i].map, expected[i].count));
		for (unsigned int j = expected[i].count; j < sizeof(data.map); j++)
			assert(data.map[j] == 0xa5);
		for (unsigned int j = 0; j < 8; j++)
			assert(data.before[j] == 0xa5 && data.after[j] == 0xa5);
		for (unsigned int j = 0; j < expected[i].count; j++) {
			assert(data.map[j] > 0);
			for (unsigned int k = j + 1; k < expected[i].count; k++)
				assert(data.map[j] != data.map[k]);
		}
		checks++;
	}
	const int unsupported[] = {-1, 0, 3, 5, 7, 9, 32};
	for (unsigned int i = 0; i < sizeof(unsupported) / sizeof(unsupported[0]); i++) {
		u8 map[16];
		memset(map, 0xa5, sizeof(map));
		audioreach_set_default_channel_mapping(map, unsupported[i]);
		for (unsigned int j = 0; j < sizeof(map); j++) assert(map[j] == 0xa5);
		checks++;
	}
	printf("Actual AudioReach map: %u layouts/bounds/refusal cases passed; no DSP or desktop profile.\n", checks);
	return 0;
}
