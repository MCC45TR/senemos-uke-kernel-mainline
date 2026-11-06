/* SPDX-License-Identifier: GPL-2.0-only */
/* Compile the actual Linux callback, with DMA/device operations mocked. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
typedef uint32_t u32;
typedef uint64_t u64;
#define FASTRPC_MAX_SESSIONS 14
#define CDSP_DOMAIN_ID 3
#define DMA_BIT_MASK(n) (UINT64_MAX >> (64 - (n)))
struct device { struct device *parent; void *of_node, *data; };
struct platform_device { struct device dev; };
struct fastrpc_soc_data { unsigned dma_addr_bits_default, dma_addr_bits_cdsp; };
struct fastrpc_session_ctx { bool used, valid; struct device *dev; unsigned sid; };
struct fastrpc_channel_ctx {
    unsigned lock;
    int domain_id, sesscount;
    struct fastrpc_soc_data *soc_data;
    struct fastrpc_session_ctx session[FASTRPC_MAX_SESSIONS];
};
static unsigned depth, dma_calls, nsessions, sid, expected_count;
static int dma_error;
static u64 dma_mask;
static struct fastrpc_channel_ctx *active;
static struct fastrpc_session_ctx old_sessions[FASTRPC_MAX_SESSIONS];
static void *dev_get_drvdata(struct device *dev) { return dev->data; }
static void dev_set_drvdata(struct device *dev, void *data)
{
    assert(depth == 1 && dma_calls == 1 && !dma_error);
    dev->data = data;
}
static int of_property_read_u32(void *node, const char *name, void *out)
{
    (void)node;
    if (!strcmp(name, "qcom,nsessions")) *(u32 *)out = nsessions;
    else if (!strcmp(name, "reg")) *(u32 *)out = sid;
    else assert(false);
    return 0;
}
#define spin_lock_irqsave(lock, flags) do { (void)(lock); (flags)=0; assert(!depth); ++depth; } while (0)
#define spin_unlock_irqrestore(lock, flags) do { (void)(lock); (void)(flags); assert(depth==1); --depth; } while (0)
#define dev_err(...) ((void)0)
#define dev_info(...) ((void)0)
static int dma_set_mask(struct device *dev, u64 mask)
{
    (void)dev;
    assert(!depth && dma_calls++ == 0);
    /* A concurrent allocator must not observe a new session yet. */
    assert(active->sesscount == (int)expected_count);
    assert(!memcmp(old_sessions, active->session, sizeof(old_sessions)));
    dma_mask = mask;
    return dma_error;
}
#include "callback.h"

static unsigned cases;
static void check(int domain, unsigned duplicates, unsigned occupied, int failure)
{
    struct fastrpc_soc_data soc = { 32, 34 };
    struct fastrpc_channel_ctx ctx = { .domain_id=domain, .sesscount=occupied, .soc_data=&soc };
    struct device parent = { .data=&ctx };
    struct platform_device device = { .dev={ .parent=&parent } };
    const unsigned slots = duplicates > 1 ? duplicates : 1;
    unsigned added = slots;
    int result;
    if (added > FASTRPC_MAX_SESSIONS - occupied) added = FASTRPC_MAX_SESSIONS - occupied;
    for (unsigned i=0; i<occupied; ++i) {
        ctx.session[i].valid=true; ctx.session[i].used=(i%2)==0;
        ctx.session[i].dev=&parent; ctx.session[i].sid=100+i;
    }
    memcpy(old_sessions, ctx.session, sizeof(old_sessions));
    depth=dma_calls=0; nsessions=duplicates; sid=domain==CDSP_DOMAIN_ID?2:3;
    expected_count=occupied; dma_error=failure; active=&ctx; dma_mask=0;
    result=fastrpc_cb_probe(&device);
    assert(!depth && dma_calls==1);
    assert(dma_mask==DMA_BIT_MASK(domain==CDSP_DOMAIN_ID?34:32));
    if (failure || !added) {
        assert(result==(failure?failure:-ENOSPC));
        assert(ctx.sesscount==(int)occupied && !device.dev.data);
        assert(!memcmp(old_sessions, ctx.session, sizeof(old_sessions)));
    } else {
        assert(result==0 && ctx.sesscount==(int)(occupied+added));
        assert(device.dev.data==&ctx.session[occupied]);
        for(unsigned i=0;i<occupied;++i)
            assert(!memcmp(&old_sessions[i],&ctx.session[i],sizeof(ctx.session[i])));
        for(unsigned i=occupied;i<occupied+added;++i) {
            assert(ctx.session[i].valid && !ctx.session[i].used);
            assert(ctx.session[i].dev==&device.dev && ctx.session[i].sid==sid);
        }
    }
    ++cases;
}
int main(void)
{
    const unsigned duplicates[] = {0,1,2,14,99};
    const unsigned occupied[] = {0,1,12,13,14};
    const int failures[] = {0,-EIO,-EACCES,-ENOMEM};
    for(unsigned domain=0;domain<=3;++domain)
        for(unsigned n=0;n<sizeof(duplicates)/sizeof(*duplicates);++n)
            for(unsigned o=0;o<sizeof(occupied)/sizeof(*occupied);++o)
                for(unsigned f=0;f<sizeof(failures)/sizeof(*failures);++f)
                    check(domain,duplicates[n],occupied[o],failures[f]);
    {
        struct device parent={0};
        struct platform_device device={.dev={.parent=&parent}};
        dma_calls=0;
        assert(fastrpc_cb_probe(&device)==-EINVAL && !dma_calls && !device.dev.data);
    }
    printf("Actual FastRPC CB DMA admission: %u fault/boundary/domain cases passed\n",cases+1);
}
