/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual lease functions, fake DMA/domain provider. No hardware addresses. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
typedef uint32_t u32;
typedef uint64_t u64;
typedef uint64_t dma_addr_t;
#define U32_MAX UINT32_MAX
#define UKE_CONFIG_BYTES 8192
#define GFP_KERNEL 0
#define upper_32_bits(v) ((u32)((u64)(v)>>32))
#define DEFINE_MUTEX(n) int n
struct device { int unused; };
struct uke_audio_config_memory {
	void *area; dma_addr_t dma; u64 dsp_address; u32 bytes, first_token;
};
static dma_addr_t fake_dma = 0x12340000;
static bool domain_ok = true, allocation_failure;
static int alloc_count, free_count, barriers;
static void mutex_lock(int *m) { assert(!*m); *m=1; }
static void mutex_unlock(int *m) { assert(*m); *m=0; }
static void memzero_explicit(void *p, size_t n) { memset(p,0,n); }
static void dma_wmb(void) { barriers++; }
static bool uke_config_same_domain(struct device *dev) { assert(dev); return domain_ok; }
static void *dma_alloc_coherent(struct device *, size_t, dma_addr_t *, int);
static void dma_free_coherent(struct device *, size_t, void *, dma_addr_t);
#include "native-memory.inc"
static void *dma_alloc_coherent(struct device *d, size_t n, dma_addr_t *a, int flags)
{
	assert(d==uke_config_device && n==8192 && !flags && uke_config_lock);
	alloc_count++;
	if(allocation_failure) return NULL;
	*a=fake_dma;
	return calloc(1,n);
}
static void dma_free_coherent(struct device *d, size_t n, void *p, dma_addr_t a)
{
	assert(d==uke_config_device && n==8192 && a==fake_dma && uke_config_lock);
	for(size_t i=0;i<n;i++) assert(!((unsigned char *)p)[i]);
	free_count++;
	free(p);
}
static void fill_private(struct uke_audio_config_memory *m)
{
	assert(m->area && m->bytes==8192 && m->dma==fake_dma);
	assert(m->dsp_address==(fake_dma|(1ULL<<32)) && m->first_token);
	memset(m->area,0xa7,8192);
}
static void fixture_restart(void)
{
	/* Explicit fake system power-off after all ownership assertions. */
	assert(uke_config_busy && uke_config_uncertain && uke_config_lease.area);
	for(size_t i=0;i<8192;i++) assert(!((unsigned char *)uke_config_lease.area)[i]);
	free(uke_config_lease.area);
	memset(&uke_config_lease,0,sizeof(uke_config_lease));
	uke_config_busy=uke_config_uncertain=false;
}
int main(void)
{
	struct device device={0},apm={0};
	struct uke_audio_config_memory a={0},b={0},stale={0};
	u32 prior_token;
	assert(uke_audio_config_acquire(&apm,NULL)==-EINVAL);
	assert(uke_audio_config_acquire(&apm,&a)==-ENODEV);
	uke_config_device=&device;
	domain_ok=false;
	assert(uke_audio_config_acquire(&apm,&a)==-EXDEV && !alloc_count);
	domain_ok=true;
	allocation_failure=true;
	assert(uke_audio_config_acquire(&apm,&a)==-ENOMEM && !uke_config_busy);
	allocation_failure=false;
	const dma_addr_t refused[]={0,3,1ULL<<32,0xfffff000};
	for(unsigned int i=0;i<sizeof(refused)/sizeof(*refused);i++){
		fake_dma=refused[i];
		assert(uke_audio_config_acquire(&apm,&a)==-ERANGE && !uke_config_busy);
	}
	fake_dma=0xffffe000;
	assert(!uke_audio_config_acquire(&apm,&a));
	fill_private(&a);
	prior_token=a.first_token;
	assert(uke_audio_config_acquire(&apm,&b)==-EBUSY);
	uke_audio_config_release(&a,false);
	assert(!uke_config_busy && !a.area && barriers);
	assert(!uke_audio_config_acquire(&apm,&a));
	assert(a.first_token==prior_token+3);
	fill_private(&a);
	int previous_free=free_count;
	uke_audio_config_release(&a,true);
	assert(uke_config_uncertain && uke_config_busy && free_count==previous_free);
	uke_audio_config_release(&a,false);
	assert(uke_config_busy && free_count==previous_free);
	assert(uke_audio_config_acquire(&apm,&b)==-EBUSY);
	fixture_restart();
	for(int malformed=0;malformed<3;malformed++){
		assert(!uke_audio_config_acquire(&apm,&a));
		fill_private(&a); stale=a;
		if(malformed==0) stale.first_token--;
		if(malformed==1) stale.bytes--;
		if(malformed==2) stale.dsp_address^=1;
		previous_free=free_count;
		uke_audio_config_release(&stale,false);
		assert(uke_config_busy && uke_config_uncertain && free_count==previous_free);
		fixture_restart();
	}
	uke_config_next_token=U32_MAX-3;
	assert(!uke_audio_config_acquire(&apm,&a));
	fill_private(&a);
	assert(a.first_token==U32_MAX-3 && uke_config_next_token==U32_MAX);
	uke_audio_config_release(&a,false);
	int previous_alloc=alloc_count;
	assert(uke_audio_config_acquire(&apm,&b)==-EOVERFLOW && alloc_count==previous_alloc);
	assert(!uke_config_busy);
	puts("Actual permanent DMA lease: domain/busy/allocation/address guards,32-bit end boundary, erase-before-free, quarantine retention, stale identities and nonrecycled token exhaustion passed; fake provider only.");
	return 0;
}
