// SPDX-License-Identifier: GPL-2.0-only
/* COPR-only compile consumer with real ARM64 kernel headers. Not a driver. */
#include "uke-ssc-dual-light.h"

int uke_ssc_light_native_proof(struct uke_ssc_light_pair *pair, u64 epoch,
			     unsigned int side, u64 ticks, s64 value,
			     bool known, bool closed, s64 *out, unsigned int op);
int uke_ssc_light_native_proof(struct uke_ssc_light_pair *pair, u64 epoch,
			     unsigned int side, u64 ticks, s64 value,
			     bool known, bool closed, s64 *out, unsigned int op)
{
	switch (op) {
	case 0:
		return uke_ssc_light_begin(pair, epoch, known, closed);
	case 1:
		return uke_ssc_light_update(pair, epoch, side, ticks, value, out);
	case 2:
		return uke_ssc_light_lid(pair, known, closed, out);
	case 3:
		uke_ssc_light_end(pair);
		return 0;
	default:
		return -EINVAL;
	}
}
