// SPDX-License-Identifier: GPL-2.0-only
// Exact kernel helper code operating exclusively on a userspace RAM copy.
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <libfdt.h>
#define UKE_INIT
#define ARRAY_SIZE(value) (sizeof(value) / sizeof((value)[0]))
static int uke_audit_failed_line;
#include "instrumented-camcc.h"
#include "instrumented-front.h"
int uke_audit_camcc(void *fdt, int *line)
{
	int result;
	uke_audit_failed_line = 0;
	result = uke_camcc_controller_graph(fdt);
	*line = uke_audit_failed_line;
	return result;
}
int uke_audit_front(void *fdt, int *line)
{
	int result;
	uke_audit_failed_line = 0;
	result = uke_front_eeprom_graph(fdt);
	*line = uke_audit_failed_line;
	return result;
}
