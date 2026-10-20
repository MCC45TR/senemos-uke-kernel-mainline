/* SPDX-License-Identifier: GPL-2.0-only */
/* Keep CONFIG_CMDLINE_FORCE; admit only an explicit root-profile override. */
#ifndef UKE_ROOT_SELECTOR_H
#define UKE_ROOT_SELECTOR_H

static int UKE_INIT uke_cmdline_space(char value)
{
	return value == ' ' || value == '\t' || value == '\r' || value == '\n';
}

/* All validation precedes mutation. No allocation or filesystem discovery. */
static int UKE_INIT uke_select_root(char *cmdline, size_t capacity,
				   const char *handoff, size_t bytes)
{
	static const char prefix[] = "senemos.root=";
	static const char standard[] = "root=PARTLABEL=linux";
	static const char userdata[] = "root=PARTLABEL=userdata";
	size_t pos = 0, length = 0, root = 0, roots = 0;
	int selected = 0;

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
		if (selected)
			return -1;
		if (count == sizeof("senemos.root=linux") - 1 &&
		    !memcmp(handoff + start, "senemos.root=linux", count))
			selected = 1;
		else if (count == sizeof("senemos.root=userdata") - 1 &&
			 !memcmp(handoff + start, "senemos.root=userdata", count))
			selected = 2;
		else
			return -1;
	}
	while (length < capacity && cmdline[length])
		length++;
	if (length == capacity)
		return -1;
	pos = 0;
	while (pos < length) {
		size_t start, count;

		while (pos < length && uke_cmdline_space(cmdline[pos]))
			pos++;
		start = pos;
		while (pos < length && !uke_cmdline_space(cmdline[pos]))
			pos++;
		count = pos - start;
		if (count < 5 || memcmp(cmdline + start, "root=", 5))
			continue;
		if (++roots != 1 || count != sizeof(standard) - 1 ||
		    memcmp(cmdline + start, standard, count))
			return -1;
		root = start;
	}
	if (roots != 1)
		return -1;
	if (selected != 2)
		return 0;
	if (capacity - length <= sizeof(userdata) - sizeof(standard))
		return -1;
	memmove(cmdline + root + sizeof(userdata) - 1,
		cmdline + root + sizeof(standard) - 1,
		length - root - (sizeof(standard) - 1) + 1);
	memcpy(cmdline + root, userdata, sizeof(userdata) - 1);
	return 1;
}
#endif
