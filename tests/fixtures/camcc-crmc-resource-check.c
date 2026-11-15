/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual callbacks; only Linux allocation/lookup boundaries are modeled. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#define __iomem
#define IORESOURCE_MEM 1
typedef uint64_t resource_size_t;
struct device { int unused; };
struct platform_device { struct device dev; };
struct resource { resource_size_t start, end; };
static struct platform_device device, other;
static struct resource resource;
static struct { struct device *dev; void *transport_context; } cam_cc_power;
static struct { bool owned; void *base; } cam_cc_crm_guard;
static bool missing, busy, fail_map, reserved, mapped, owner_busy;
static int irq;
static unsigned int lookups, irq_lookups, requests, maps, releases, unmaps;
static uint32_t words[0x2000 / 4];
static const char *dev_name(struct device *dev)
{ assert(dev == &device.dev); return "model"; }
static bool cam_cc_owner_busy(void) { return owner_busy; }
static struct resource *platform_get_resource_byname(struct platform_device *pdev, int type, const char *name)
{
	assert(pdev == &device && type == IORESOURCE_MEM && !strcmp(name, "crmc"));
	lookups++; return missing ? NULL : &resource;
}
static int platform_get_irq_byname(struct platform_device *pdev, const char *name)
{ assert(pdev == &device && !strcmp(name, "crm")); irq_lookups++; return irq; }
static resource_size_t resource_size(struct resource *res) { return res->end - res->start + 1; }
static struct resource *request_mem_region(resource_size_t start, resource_size_t size, const char *name)
{
	assert(start == 0xadda000 && size == 0x2000 && !strcmp(name, "model"));
	requests++; if (busy || reserved) return NULL; reserved = true; return &resource;
}
static void *ioremap(resource_size_t start, resource_size_t size)
{
	assert(start == 0xadda000 && size == 0x2000 && reserved && !mapped);
	maps++; if (fail_map) return NULL; mapped = true; return words;
}
static void iounmap(void *base)
{ assert(base == words && mapped && reserved); mapped = false; unmaps++; }
static void release_mem_region(resource_size_t start, resource_size_t size)
{ assert(start == 0xadda000 && size == 0x2000 && reserved && !mapped); reserved = false; releases++; }
#include "crmc-resource.h"
static void reset(void)
{
	assert(!reserved && !mapped);
	memset(&cam_cc_crmc_resource, 0, sizeof(cam_cc_crmc_resource));
	memset(words, 0xa5, sizeof(words));
	cam_cc_power.dev = &device.dev; cam_cc_power.transport_context = NULL;
	cam_cc_crm_guard.owned = true; cam_cc_crm_guard.base = words;
	resource = (struct resource){0xadda000, 0xaddbfff}; irq = 409;
	missing = busy = fail_map = owner_busy = false;
	lookups = irq_lookups = requests = maps = releases = unmaps = 0;
}
int main(void)
{
	for (unsigned int invalid = 0; invalid < 4; invalid++) {
		reset();
		if (!invalid) cam_cc_power.dev = NULL;
		if (invalid == 1) cam_cc_power.dev = &other.dev;
		if (invalid == 2) cam_cc_crm_guard.owned = false;
		if (invalid == 3) cam_cc_crm_guard.base = NULL;
		assert(cam_cc_crmc_resource_map(&device) == -ENODEV && !lookups && !requests);
	}
	for (unsigned int invalid = 0; invalid < 4; invalid++) {
		reset();
		if (!invalid) missing = true;
		if (invalid == 1) resource.start += 4;
		if (invalid == 2) resource.end--;
		if (invalid == 3) resource.end++;
		assert(cam_cc_crmc_resource_map(&device) == -EINVAL && !irq_lookups && !requests);
	}
	const int errors[] = {-517, -ENXIO, -EINVAL, 0};
	for (unsigned int i = 0; i < sizeof(errors) / sizeof(errors[0]); i++) {
		reset(); irq = errors[i];
		assert(cam_cc_crmc_resource_map(&device) == (irq ? irq : -ENXIO));
		assert(irq_lookups == 1 && !requests && !maps);
	}
	reset(); busy = true;
	assert(cam_cc_crmc_resource_map(&device) == -EBUSY && requests == 1 && !maps && !releases);
	reset(); fail_map = true;
	assert(cam_cc_crmc_resource_map(&device) == -ENOMEM && maps == 1 && releases == 1 && !reserved);
	cam_cc_crmc_resource_put(); assert(!unmaps && releases == 1);
	reset();
	uint32_t before[sizeof(words) / sizeof(words[0])]; memcpy(before, words, sizeof(words));
	assert(!cam_cc_crmc_resource_map(&device));
	assert(mapped && reserved && cam_cc_crmc_resource.owned && cam_cc_crmc_resource.base == words);
	assert(cam_cc_crmc_resource.dev == &device.dev && cam_cc_crmc_resource.irq == 409);
	assert(!memcmp(before, words, sizeof(words)));
	assert(cam_cc_crmc_resource_map(&device) == -EBUSY && lookups == 1 && requests == 1 && maps == 1);
	owner_busy = true; cam_cc_crmc_resource_put();
	assert(mapped && reserved && !unmaps && !releases);
	owner_busy = false; cam_cc_power.dev = &other.dev; cam_cc_crmc_resource_put();
	assert(mapped && reserved && !unmaps && !releases);
	cam_cc_power.dev = &device.dev; cam_cc_power.transport_context = words; cam_cc_crmc_resource_put();
	assert(mapped && reserved && !unmaps && !releases);
	cam_cc_power.transport_context = NULL; cam_cc_crmc_resource_put();
	assert(!mapped && !reserved && unmaps == 1 && releases == 1);
	assert(!cam_cc_crmc_resource.dev && !cam_cc_crmc_resource.base && !cam_cc_crmc_resource.owned && !cam_cc_crmc_resource.irq);
	cam_cc_crmc_resource_put(); assert(unmaps == 1 && releases == 1);
	assert(!memcmp(before, words, sizeof(words)));
	assert(!cam_cc_crmc_resource_map(&device)); cam_cc_crmc_resource_put();
	assert(unmaps == 2 && releases == 2);
	puts("Actual CRMC resources: exact owner/window/IRQ/defer, exclusive passive mapping, clean retry and busy/foreign/transport retention pass; no register or IRQ activation");
	return 0;
}
