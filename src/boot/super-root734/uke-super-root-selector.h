/* SPDX-License-Identifier: GPL-2.0-only */
/* Early ARM64 setup only. Keep the complete existing normal-root parser. */
#ifndef UKE_SUPER_ROOT_SELECTOR734_H
#define UKE_SUPER_ROOT_SELECTOR734_H

#define uke_select_root uke_select_base_root734
#include "uke-root-selector.h"
#undef uke_select_root

#ifdef __KERNEL__
ELFNOTE64("UKE", 0x554b4503,
	  "super-root-v1;role=rescue;root=dm-uke-rescue;readonly;noresume");
#define UKE_SUPER_INITDATA __initdata
#else
#define UKE_SUPER_INITDATA
#endif

/* setup_arch is single-threaded; init memory is reclaimed after startup. */
static char uke_super_cmdline734[COMMAND_LINE_SIZE] UKE_SUPER_INITDATA;

static int UKE_INIT uke_super_replace734(char *line, size_t capacity,
				       const char *before, const char *after)
{
	size_t pos = 0, found = 0, offset = 0;
	size_t length = strlen(line), old_bytes = strlen(before), new_bytes = strlen(after);

	while (pos < length) {
		size_t start;

		while (pos < length && uke_cmdline_space(line[pos]))
			pos++;
		start = pos;
		while (pos < length && !uke_cmdline_space(line[pos]))
			pos++;
		if (pos - start == old_bytes && !memcmp(line + start, before, old_bytes)) {
			found++;
			offset = start;
		}
	}
	if (found != 1 || new_bytes >= capacity ||
	    length - old_bytes >= capacity - new_bytes)
		return -1;
	memmove(line + offset + new_bytes, line + offset + old_bytes,
		length - offset - old_bytes + 1);
	memcpy(line + offset, after, new_bytes);
	return 0;
}

static int UKE_INIT uke_select_root(char *cmdline, size_t capacity,
				   const char *handoff, size_t bytes)
{
	static const char prefix[] = "senemos.role=";
	static const char rescue[] = "senemos.role=rescue";
	static const char suffix[] = " senemos.role=rescue noresume";
	size_t pos = 0, roles = 0, length;
	char *work = uke_super_cmdline734;
	int selected;

	if (!cmdline || !capacity || bytes > 8192 || (!handoff && bytes))
		return -1;
	if (bytes && (handoff[bytes - 1] || memchr(handoff, 0, bytes - 1)))
		return -1;
	while (bytes && pos < bytes - 1) {
		size_t start, count;

		while (pos < bytes - 1 && uke_cmdline_space(handoff[pos]))
			pos++;
		start = pos;
		while (pos < bytes - 1 && !uke_cmdline_space(handoff[pos]))
			pos++;
		count = pos - start;
		if (count < sizeof(prefix) - 1 ||
		    memcmp(handoff + start, prefix, sizeof(prefix) - 1))
			continue;
		if (++roles != 1 || count != sizeof(rescue) - 1 ||
		    memcmp(handoff + start, rescue, count))
			return -1;
	}
	if (!roles)
		return uke_select_base_root734(cmdline, capacity, handoff, bytes);
	if (capacity > sizeof(uke_super_cmdline734))
		return -1;
	length = 0;
	while (length < capacity && cmdline[length])
		length++;
	if (length == capacity)
		return -1;
	memcpy(work, cmdline, length + 1);
	selected = uke_select_base_root734(work, capacity, handoff, bytes);
	if (selected != 1)
		return -1;
	if (uke_super_replace734(work, capacity, "root=PARTLABEL=userdata",
				 "root=/dev/mapper/uke-rescue") ||
	    uke_super_replace734(work, capacity, "rootfstype=ext4,f2fs,xfs,btrfs",
				 "rootfstype=ext4") ||
	    uke_super_replace734(work, capacity, "rw", "ro"))
		return -1;
	length = strlen(work);
	if (length >= capacity || sizeof(suffix) > capacity - length)
		return -1;
	memcpy(work + length, suffix, sizeof(suffix));
	memcpy(cmdline, work, length + sizeof(suffix));
	return 1;
}
#undef UKE_SUPER_INITDATA
#endif
