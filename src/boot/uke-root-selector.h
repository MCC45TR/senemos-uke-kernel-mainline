/* SPDX-License-Identifier: GPL-2.0-only */
/* Keep CONFIG_CMDLINE_FORCE; admit bounded root, boot-slot and private VRR controls. */
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
	const char *slot = NULL, *vrr = NULL;
	size_t slot_bytes = 0, vrr_bytes = 0, extra;
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
		if (count >= sizeof("androidboot.slot_suffix=") - 1 &&
		    !memcmp(handoff + start, "androidboot.slot_suffix=",
			    sizeof("androidboot.slot_suffix=") - 1)) {
			if (slot || count != sizeof("androidboot.slot_suffix=_a") - 1 ||
			    (memcmp(handoff + start, "androidboot.slot_suffix=_a", count) &&
			     memcmp(handoff + start, "androidboot.slot_suffix=_b", count)))
				return -1;
			slot = handoff + start;
			slot_bytes = count;
			continue;
		}
		if (count >= sizeof("msm.o82_vrr_test_min_hz=") - 1 &&
		    !memcmp(handoff + start, "msm.o82_vrr_test_min_hz=",
			    sizeof("msm.o82_vrr_test_min_hz=") - 1)) {
			if (vrr ||
			    !((count == sizeof("msm.o82_vrr_test_min_hz=0") - 1 &&
			       !memcmp(handoff + start, "msm.o82_vrr_test_min_hz=0", count)) ||
			      (count == sizeof("msm.o82_vrr_test_min_hz=30") - 1 &&
			       !memcmp(handoff + start, "msm.o82_vrr_test_min_hz=30", count))))
				return -1;
			vrr = handoff + start;
			vrr_bytes = count;
			continue;
		}
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
	if (vrr && selected != 2)
		return -1;
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
		if ((count >= sizeof("androidboot.slot_suffix=") - 1 &&
		     !memcmp(cmdline + start, "androidboot.slot_suffix=",
			     sizeof("androidboot.slot_suffix=") - 1)) ||
		    (count >= sizeof("msm.o82_vrr_test_min_hz=") - 1 &&
		     !memcmp(cmdline + start, "msm.o82_vrr_test_min_hz=",
			     sizeof("msm.o82_vrr_test_min_hz=") - 1)))
			return -1;
		if (count < 5 || memcmp(cmdline + start, "root=", 5))
			continue;
		if (++roots != 1 || count != sizeof(standard) - 1 ||
		    memcmp(cmdline + start, standard, count))
			return -1;
		root = start;
	}
	if (roots != 1)
		return -1;
	extra = (selected == 2 ? sizeof(userdata) - sizeof(standard) : 0) +
		(slot ? 1 + slot_bytes : 0) + (vrr ? 1 + vrr_bytes : 0);
	if (capacity - length <= extra)
		return -1;
	if (selected == 2) {
		memmove(cmdline + root + sizeof(userdata) - 1,
			cmdline + root + sizeof(standard) - 1,
			length - root - (sizeof(standard) - 1) + 1);
		memcpy(cmdline + root, userdata, sizeof(userdata) - 1);
		length += sizeof(userdata) - sizeof(standard);
	}
	if (slot) {
		cmdline[length++] = ' ';
		memcpy(cmdline + length, slot, slot_bytes);
		length += slot_bytes;
	}
	if (vrr) {
		cmdline[length++] = ' ';
		memcpy(cmdline + length, vrr, vrr_bytes);
		length += vrr_bytes;
	}
	cmdline[length] = 0;
	return selected == 2;
}
#endif
