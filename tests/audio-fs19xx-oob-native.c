// SPDX-License-Identifier: GPL-2.0-only
// COPR native compiler check only; this object is never linked into Image.
#include "uke-fs19xx-oob.h"

int uke_fs19xx_oob_compile(struct uke_oob_buffer *buffer,
		const struct uke_oob_ops *ops, void *context, const u8 *tuning);

int uke_fs19xx_oob_compile(struct uke_oob_buffer *buffer,
		const struct uke_oob_ops *ops, void *context, const u8 *tuning)
{
	return uke_fs19xx_oob_transfer(buffer, ops, context, 0x4040,
				     0x10001fb0, tuning, 5360);
}
