/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual FS19xx initialization with independent allocation/provider faults. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#define EPROBE_DEFER 517
#define GFP_KERNEL 0
#define IS_ERR(p) ((intptr_t)(p)<0 && (intptr_t)(p)>-4096)
#define PTR_ERR(p) ((int)(intptr_t)(p))
struct device { void *of_node; };
struct q6apm_fs19xx { int lock; bool admitted; void *sha256; };
struct q6apm { struct device *dev; struct q6apm_fs19xx *fs19xx; };
static bool uke=true, protected=true, fail_memory, fail_hash, fail_action;
static int readiness, ready_calls, memory_calls, hash_calls, action_calls, hash_frees;
static void *allocation;
static int hash_object;
static void (*cleanup)(void *);
static void *cleanup_arg;
static bool of_machine_is_compatible(const char *s) { assert(!strcmp(s,"xiaomi,uke")); return uke; }
static bool __attribute__((unused)) of_property_read_bool(void *n,const char *s)
{ assert(n && !strcmp(s,"xiaomi,fs19xx-protected")); return protected; }
static int __attribute__((unused)) q6apm_fs19xx_oob_ready(void) { ready_calls++; return readiness; }
static void *devm_kzalloc(struct device *d,size_t n,int flags)
{
	assert(d && !flags && n==sizeof(struct q6apm_fs19xx)); memory_calls++;
	if(fail_memory) return NULL;
	assert(!allocation); allocation=calloc(1,n); assert(allocation); return allocation;
}
static void mutex_init(int *p) { *p=1; }
static void *crypto_alloc_shash(const char *s,int a,int b)
{
	assert(!strcmp(s,"sha256") && !a && !b); hash_calls++;
	return fail_hash ? (void *)(intptr_t)-ENOMEM : &hash_object;
}
static void fs19xx_free_hash(void *p) { assert(p==&hash_object); hash_frees++; }
static int devm_add_action_or_reset(struct device *d,void (*fn)(void *),void *arg)
{
	assert(d && fn==fs19xx_free_hash); action_calls++;
	if(fail_action) { fn(arg); return -EIO; }
	cleanup=fn; cleanup_arg=arg; return 0;
}
#include "native-startup.inc"
static void reset(void)
{
	if(cleanup) cleanup(cleanup_arg);
	free(allocation); allocation=NULL; cleanup=NULL;
	ready_calls=memory_calls=hash_calls=action_calls=hash_frees=0;
	fail_memory=fail_hash=fail_action=false; readiness=0; uke=protected=true;
}
int main(void)
{
	struct device device={(void *)1}; struct q6apm apm={&device,NULL};
	bool admitted;
#ifdef UKE_FS19XX_CONTROLS_ONLY
	admitted=false;
#else
	admitted=true;
#endif
	readiness=-EPROBE_DEFER;
	int ret=q6apm_fs19xx_init(&apm);
	if(admitted) assert(ret==-EPROBE_DEFER && ready_calls==1 && !memory_calls && !hash_calls && !apm.fs19xx);
	else assert(!ret && !ready_calls && memory_calls==1 && apm.fs19xx);
	reset(); apm.fs19xx=NULL; uke=false;
	assert(!q6apm_fs19xx_init(&apm) && !ready_calls && !memory_calls);
	reset(); apm.fs19xx=NULL; protected=false; readiness=-EPROBE_DEFER;
	assert(!q6apm_fs19xx_init(&apm) && !ready_calls && memory_calls==1);
	assert(apm.fs19xx && !apm.fs19xx->admitted);
	reset(); apm.fs19xx=NULL;
	assert(!q6apm_fs19xx_init(&apm));
	assert(apm.fs19xx && apm.fs19xx->admitted==admitted && apm.fs19xx->lock==1);
	assert(memory_calls==1 && hash_calls==1 && action_calls==1 && ready_calls==(int)admitted);
	reset(); apm.fs19xx=NULL; fail_memory=true;
	assert(q6apm_fs19xx_init(&apm)==(admitted ? -ENOMEM : 0) && !hash_calls && !apm.fs19xx);
	reset(); apm.fs19xx=NULL; fail_hash=true;
	assert(q6apm_fs19xx_init(&apm)==(admitted ? -ENOMEM : 0) && !action_calls && !apm.fs19xx);
	reset(); apm.fs19xx=NULL; fail_action=true;
	assert(q6apm_fs19xx_init(&apm)==(admitted ? -EIO : 0) && hash_frees==1 && !apm.fs19xx);
	reset();
	puts("Actual FS19xx startup: provider defer before allocation, no frontend dependency, foreign/unprotected/controls-only paths and allocation/hash/action faults passed; fake providers only.");
	return 0;
}
