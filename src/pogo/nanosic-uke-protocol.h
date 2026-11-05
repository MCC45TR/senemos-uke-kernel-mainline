/* SPDX-License-Identifier: GPL-2.0-only */
/* Firmware framing derived from map220v's WN8030 driver (2025), with the
 * bounded parser by yzddmr6 at 8ee5a1576e123ecbacfcfb9925d0f56820132bb8.
 * Board policy and runtime framing are maintained separately for Uke.
 */
#ifndef _NANOSIC_UKE_PROTOCOL_H
#define _NANOSIC_UKE_PROTOCOL_H
#include <linux/errno.h>
#include <linux/minmax.h>
#include <linux/string.h>
#include <linux/types.h>
#include <linux/unaligned.h>
#define NANOSIC_BOOT_REGISTER		0x5c
#define NANOSIC_REPORT_REGISTER		0x4c
#define NANOSIC_FW_HEADER_OFFSET		0x7fc0
#define NANOSIC_FW_CODE_OFFSET		0x8000
#define NANOSIC_FW_HEADER_CMD_SIZE	65
#define NANOSIC_FW_DATA_CMD_SIZE		512
#define NANOSIC_FW_CHUNK_SIZE		503
#define NANOSIC_FRAME_SIZE		68
#define NANOSIC_TOUCH_X_MAX		3199
#define NANOSIC_TOUCH_Y_MAX		2135
#define NANOSIC_TOUCH_MAX_CONTACTS	8
#define NANOSIC_TOUCH_CONTACTS_PER_REPORT	3

struct nanosic_firmware {
	const u8 *header;
	const u8 *code;
	u32 size;
	u32 word_sum;
};

static inline int nanosic_firmware_parse(const u8 *data, size_t size,
					struct nanosic_firmware *fw)
{
	const u8 *header;
	u32 code_size, byte_sum = 0, word_sum = 0;
	u8 header_sum = 0;
	size_t i;

	if (size < NANOSIC_FW_CODE_OFFSET)
		return -EINVAL;
	header = data + NANOSIC_FW_HEADER_OFFSET;
	if (memcmp(header, "NANO IC", 7) || get_unaligned_le16(header + 7) != 0x8030)
		return -EINVAL;

	code_size = get_unaligned_le32(header + 48);
	if (!code_size || code_size % 4 || code_size > size - NANOSIC_FW_CODE_OFFSET)
		return -EINVAL;
	for (i = 0; i < 63; i++)
		header_sum += header[i];
	if (header_sum != header[63])
		return -EBADMSG;

	for (i = 0; i < code_size; i++)
		byte_sum += data[NANOSIC_FW_CODE_OFFSET + i];
	if (byte_sum != get_unaligned_le32(header + 52))
		return -EBADMSG;
	for (i = 0; i < code_size; i += 4)
		word_sum += get_unaligned_le32(data + NANOSIC_FW_CODE_OFFSET + i);

	*fw = (struct nanosic_firmware) {
		.header = header,
		.code = data + NANOSIC_FW_CODE_OFFSET,
		.size = code_size,
		.word_sum = word_sum,
	};
	return 0;
}

/* The caller retains the validated firmware bytes while building commands. */
static inline void nanosic_firmware_header(const struct nanosic_firmware *fw,
					   u8 cmd[NANOSIC_FW_HEADER_CMD_SIZE])
{
	u8 checksum = 0;
	unsigned int i;

	memset(cmd, 0, NANOSIC_FW_HEADER_CMD_SIZE);
	cmd[0] = 0x06;
	memcpy(cmd + 1, fw->header, 7);
	put_unaligned_le16(0x8140, cmd + 8);
	put_unaligned_le32(0x2345, cmd + 10);
	put_unaligned_le32(0x40, cmd + 14);
	put_unaligned_le32(fw->size, cmd + 18);
	/* Entry, product/vendor IDs and two version bytes retain their wire order. */
	memcpy(cmd + 22, fw->header + 21, 10);
	put_unaligned_le32(fw->word_sum, cmd + 53);
	for (i = 1; i < NANOSIC_FW_HEADER_CMD_SIZE - 1; i++)
		checksum += cmd[i];
	cmd[NANOSIC_FW_HEADER_CMD_SIZE - 1] = checksum;
}

/* Returns the number of code bytes consumed; the wire payload is always 512. */
static inline int nanosic_firmware_chunk(const struct nanosic_firmware *fw,
					u32 offset, u8 cmd[NANOSIC_FW_DATA_CMD_SIZE])
{
	u32 count;

	if (offset >= fw->size)
		return -EINVAL;
	count = min_t(u32, NANOSIC_FW_CHUNK_SIZE, fw->size - offset);
	memset(cmd, 0, NANOSIC_FW_DATA_CMD_SIZE);
	cmd[0] = 0x07;
	put_unaligned_be32(offset, cmd + 1);
	put_unaligned_be32(count, cmd + 5);
	memcpy(cmd + 9, fw->code + offset, count);
	return count;
}

static inline int nanosic_uke_command(u8 route, u8 opcode, const u8 *payload,
				     size_t len, u8 cmd[66])
{
	u8 sum = 0;
	size_t i;

	if (len > 57 || (len && !payload))
		return -EINVAL;
	memset(cmd, 0, 66);
	cmd[0] = 0x32;
	cmd[2] = route;
	cmd[3] = 0x31;
	cmd[4] = 0x80;
	cmd[5] = 0x38;
	cmd[6] = opcode;
	cmd[7] = len;
	if (len)
		memcpy(cmd + 8, payload, len);
	for (i = 2; i < 8 + len; i++)
		sum += cmd[i];
	cmd[8 + len] = sum;
	return 0;
}

/* One legacy report per 68-byte read; no guessed packed/pressure format. */
static inline int nanosic_uke_report(const u8 *frame, size_t size)
{
	const u8 *p;
	int i, j;

	if (size != NANOSIC_FRAME_SIZE)
		return -EMSGSIZE;
	if ((frame[0] & 0x7f) != 0x57)
		return -EBADMSG;
	if (!frame[2])
		return 0;
	p = frame + 3;
	switch (p[0]) {
	case 0x05:
		return 9;
	case 0x06:
		return 3;
	case 0x19:
		/* OEM hybrid report: three entries per packet, up to eight per frame. */
		if (p[20] > NANOSIC_TOUCH_MAX_CONTACTS)
			return -EBADMSG;
		for (i = 0; i < NANOSIC_TOUCH_CONTACTS_PER_REPORT; i++) {
			const u8 *c = p + 2 + i * 6;

			if (!(c[0] & 1))
				continue;
			if (get_unaligned_le16(c + 2) > NANOSIC_TOUCH_X_MAX ||
			    get_unaligned_le16(c + 4) > NANOSIC_TOUCH_Y_MAX)
				return -EBADMSG;
			for (j = 0; j < i; j++)
				if ((p[2 + j * 6] & 1) && c[1] == p[3 + j * 6])
					return -EBADMSG;
		}
		return 21;
	case 0x22:
	case 0x23:
	case 0x24:
		if (p[2] != 0x38 || p[3] != 0x80 || p[5] > size - 9)
			return -EBADMSG;
		return 6 + p[5];
	default:
		return -EOPNOTSUPP;
	}
}
#endif
