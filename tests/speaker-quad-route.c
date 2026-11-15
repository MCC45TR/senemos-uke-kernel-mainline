/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#define current get_current()
#include "../src/audio/uke-speaker-quad.h"
#undef current

struct provider {
	unsigned int hardware[4], calls, faults;
	unsigned int fail_call, fail_restore;
};

static int apply(void *context, const unsigned int *map)
{
	struct provider *p = context;

	++p->calls;
	/* A command may have reached firmware before its failure response. */
	memcpy(p->hardware, map, sizeof(p->hardware));
	return p->calls == p->fail_call || p->calls == p->fail_restore ? -EIO : 0;
}

static void fault(void *context)
{
	((struct provider *)context)->faults++;
}

int main(void)
{
	const struct uke_quad_route_ops ops = { apply, fault };
	const unsigned int expected[4][4] = {
		{ 0, 1, 2, 3 }, { 1, 3, 0, 2 },
		{ 3, 2, 1, 0 }, { 2, 0, 3, 1 }
	};
	unsigned int scenarios = 0;

	for (unsigned int old = 0; old < 4; old++) {
		for (unsigned int target = 0; target < 4; target++) {
			struct provider p = {};
			unsigned int current = old;
			memcpy(p.hardware, expected[old], sizeof(p.hardware));
			assert(uke_quad_turn(expected[target], 4) == (int)target);
			assert(uke_quad_route(&p, &ops, &current, target) == (old != target));
			assert(current == target && p.calls == (unsigned int)(old != target));
			assert(!memcmp(p.hardware, expected[target], sizeof(p.hardware)) && !p.faults);
			++scenarios;
			if (old == target)
				continue;
			for (unsigned int failed_restore = 0; failed_restore < 2; failed_restore++) {
				p = (struct provider){ .fail_call = 1, .fail_restore = failed_restore ? 2 : 0 };
				current = old;
				assert(uke_quad_route(&p, &ops, &current, target) == -EIO);
				assert(current == old && p.calls == 2 && p.faults == failed_restore);
				assert(!memcmp(p.hardware, expected[old], sizeof(p.hardware)));
				++scenarios;
			}
		}
	}
	{
		struct provider p = {};
		unsigned int current = 0;
		const unsigned int invalid[][4] = {
			{0,0,2,3}, {4,1,2,3}, {0,2,1,3}, {3,1,2,0}
		};
		assert(uke_quad_turn(NULL,4) == -EINVAL);
		assert(uke_quad_turn(expected[0],3) == -EINVAL);
		for (unsigned int i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++)
			assert(uke_quad_turn(invalid[i],4) == -EINVAL);
		assert(uke_quad_route(&p,&ops,&current,4) == -EINVAL && !p.calls);
		current = 4;
		assert(uke_quad_route(&p,&ops,&current,0) == -EINVAL && !p.calls);
		assert(uke_quad_route(&p,NULL,&current,0) == -EINVAL && !p.calls);
		++scenarios;
	}
	printf("Actual quad route: %u mapping/transaction scenarios passed; controlled DSP provider only.\n", scenarios);
	return 0;
}
