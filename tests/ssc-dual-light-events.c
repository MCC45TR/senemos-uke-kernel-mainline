// SPDX-License-Identifier: GPL-2.0-only
/* Actual production reducer; synthetic admitted sensor/Hall events only. */
#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include "uke-ssc-dual-light.h"

static unsigned int cases;
#define CHECK(expr) do { assert(expr); cases++; } while (0)

static bool same_pair(const struct uke_ssc_light_pair *a, const struct uke_ssc_light_pair *b)
{
	return a->epoch == b->epoch && a->ticks[0] == b->ticks[0] &&
		a->ticks[1] == b->ticks[1] && a->micro_lux[0] == b->micro_lux[0] &&
		a->micro_lux[1] == b->micro_lux[1] && a->last_output == b->last_output &&
		a->valid == b->valid && a->active == b->active &&
		a->lid_known == b->lid_known && a->lid_closed == b->lid_closed &&
		a->have_output == b->have_output;
}

static void ordered_readings(void)
{
	const s64 values[] = { 0, 1, 999999, 1000000, 125000001, LLONG_MAX };
	unsigned int a, b, order;

	for (a = 0; a < 6; a++)
		for (b = 0; b < 6; b++)
			for (order = 0; order < 2; order++) {
				struct uke_ssc_light_pair pair = {};
				s64 out = -77, input[] = { values[a], values[b] };
				unsigned int first = order, second = 1U - order;

				CHECK(!uke_ssc_light_begin(&pair, 1, true, false));
				CHECK(uke_ssc_light_update(&pair, 1, first, 10, input[first], &out) == -EAGAIN);
				CHECK(out == -77);
				CHECK(uke_ssc_light_update(&pair, 1, second, 11, input[second], &out) == 1);
				CHECK(out == (input[0] > input[1] ? input[0] : input[1]));
				out = -77;
				CHECK(uke_ssc_light_update(&pair, 1, second, 12, input[second], &out) == 0);
				CHECK(out == -77);
			}
}

static void closed_cover(void)
{
	struct uke_ssc_light_pair pair = {};
	s64 out = -77;

	CHECK(!uke_ssc_light_begin(&pair, 2, true, true));
	CHECK(uke_ssc_light_required(&pair) == 2U);
	CHECK(uke_ssc_light_update(&pair, 2, 0, 10, LLONG_MAX, &out) == 0);
	CHECK(out == -77 && !pair.valid && !pair.have_output);
	CHECK(uke_ssc_light_update(&pair, 2, 1, 10, 1234567, &out) == 1);
	CHECK(out == 1234567 && pair.valid == 2U);
	out = -77;
	CHECK(uke_ssc_light_update(&pair, 2, 0, 11, LLONG_MAX, &out) == 0);
	CHECK(out == -77);
	CHECK(uke_ssc_light_update(&pair, 2, 1, 11, 0, &out) == 1 && out == 0);
	/* No front indication is necessary for a closed-cover monitor measurement. */
}

static void lid_transitions(void)
{
	struct uke_ssc_light_pair pair = {};
	s64 out = -77;

	CHECK(!uke_ssc_light_begin(&pair, 3, true, false));
	CHECK(uke_ssc_light_update(&pair, 3, 0, 10, 100, &out) == -EAGAIN);
	CHECK(uke_ssc_light_update(&pair, 3, 1, 10, 50, &out) == 1 && out == 100);
	CHECK(uke_ssc_light_lid(&pair, true, true, &out) == 1 && out == 50);
	out = -77;
	CHECK(uke_ssc_light_update(&pair, 3, 0, 11, 500, &out) == 0 && out == -77);
	CHECK(uke_ssc_light_lid(&pair, true, false, &out) == -EAGAIN && out == -77);
	CHECK(uke_ssc_light_required(&pair) == 3U && pair.valid == 2U);
	CHECK(uke_ssc_light_update(&pair, 3, 1, 11, 80, &out) == -EAGAIN && out == -77);
	CHECK(uke_ssc_light_update(&pair, 3, 0, 12, 30, &out) == 1 && out == 80);
	CHECK(uke_ssc_light_lid(&pair, true, true, &out) == 0);
	CHECK(uke_ssc_light_lid(&pair, false, true, &out) == -EAGAIN);
	CHECK(uke_ssc_light_required(&pair) == 3U); /* Unknown never means closed. */
}

static void lifecycle_and_errors(void)
{
	struct uke_ssc_light_pair pair = {}, before;
	s64 out = -77;

	CHECK(uke_ssc_light_update(&pair, 1, 1, 10, 5, &out) == -ENODEV);
	CHECK(uke_ssc_light_begin(&pair, 0, false, false) == -EINVAL);
	CHECK(!uke_ssc_light_begin(&pair, 4, false, true));
	CHECK(uke_ssc_light_required(&pair) == 3U);
	CHECK(uke_ssc_light_begin(&pair, 5, true, false) == -EINVAL);
	before = pair;
	CHECK(uke_ssc_light_update(&pair, 3, 0, 10, 1, &out) == -ESTALE);
	CHECK(same_pair(&pair, &before) && out == -77);
	CHECK(uke_ssc_light_update(&pair, 4, 2, 10, 1, &out) == -EINVAL);
	CHECK(uke_ssc_light_update(&pair, 4, 0, 0, 1, &out) == -ESTALE);
	CHECK(uke_ssc_light_update(&pair, 4, 0, 10, -1, &out) == -ERANGE);
	CHECK(same_pair(&pair, &before) && out == -77);
	CHECK(uke_ssc_light_update(&pair, 4, 0, 10, 12, &out) == -EAGAIN);
	before = pair;
	CHECK(uke_ssc_light_update(&pair, 4, 0, 10, 99, &out) == -ESTALE);
	CHECK(uke_ssc_light_update(&pair, 4, 0, 9, 99, &out) == -ESTALE);
	CHECK(same_pair(&pair, &before));
	CHECK(uke_ssc_light_update(&pair, 4, 1, 10, 13, &out) == 1 && out == 13);
	uke_ssc_light_end(&pair);
	CHECK(!pair.active && !pair.valid && !pair.have_output && pair.epoch == 4);
	CHECK(!pair.micro_lux[0] && !pair.micro_lux[1] && !pair.ticks[0] && !pair.ticks[1]);
	out = -77;
	CHECK(uke_ssc_light_update(&pair, 4, 0, 11, 100, &out) == -ENODEV && out == -77);
	CHECK(uke_ssc_light_begin(&pair, 4, true, false) == -EINVAL);
	CHECK(!uke_ssc_light_begin(&pair, 5, true, true));
	CHECK(uke_ssc_light_update(&pair, 4, 1, 12, 200, &out) == -ESTALE && out == -77);
	CHECK(uke_ssc_light_update(&pair, 5, 1, 1, 0, &out) == 1 && out == 0);
	uke_ssc_light_end(&pair);
}

int main(void)
{
	ordered_readings();
	closed_cover();
	lid_transitions();
	lifecycle_and_errors();
	printf("Actual dual-light event reducer: %u synthetic assertions passed; no live SSC/Hall/monitor acceptance.\n", cases);
	return 0;
}
