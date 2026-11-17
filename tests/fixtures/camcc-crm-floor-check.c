/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint32_t u32;
typedef uint64_t u64;
#define READ_ONCE(v) (v)
#define WRITE_ONCE(v,n) ((v)=(n))
struct mutex {bool locked;};
static void mutex_init(struct mutex *m) {m->locked=false;}
static void mutex_lock(struct mutex *m) {assert(!m->locked);m->locked=true;}
static void mutex_unlock(struct mutex *m) {assert(m->locked);m->locked=false;}
#include "camcc-sm7675-crm-core.h"
#include "camcc-sm7675-crm-floor.h"

struct model {
    struct cam_cc_crm_floor *owner;
    unsigned calls,fail_at;
    int error;
    u32 values[8],kinds[8],resources[8];
};
static int send(void *context,u32 kind,u32 resource,u32 value)
{
    struct model *m=context;
    assert(m->owner->lock.locked);
    int index=cam_cc_crm_floor_index(kind,resource);
    assert(index>=0 && index<8);
    ++m->calls;
    if(m->calls==m->fail_at)return m->error;
    m->values[index]=value;m->kinds[index]=kind;m->resources[index]=resource;
    return 0;
}
int main(void)
{
    struct cam_cc_crm_floor floor={0},before;
    struct model m={.owner=&floor,.error=-EREMOTEIO};
    u32 minimum[8]={6,0,0,0,0,0,0,0};
    assert(cam_cc_crm_floor_vote(&floor,0,0,1)==-ENODEV && !m.calls);
    assert(cam_cc_crm_floor_sync(&floor)==-ENODEV && !m.calls);
    assert(!cam_cc_crm_floor_init(&floor,minimum,send,&m) && !m.calls);
    assert(cam_cc_crm_floor_init(&floor,minimum,send,&m)==-EBUSY && !m.calls);
    assert(!cam_cc_crm_floor_vote(&floor,0,0,2) && m.values[0]==6 && floor.requested[0]==2);
    assert(!cam_cc_crm_floor_vote(&floor,0,0,7) && m.values[0]==7 && floor.requested[0]==7);
    unsigned calls=m.calls;
    assert(!cam_cc_crm_floor_sync(&floor) && m.calls==calls && floor.released);
    assert(!cam_cc_crm_floor_vote(&floor,0,0,0) && m.values[0]==0);
    assert(!cam_cc_crm_floor_sync(&floor) && m.calls==calls+1);
    assert(cam_cc_crm_floor_vote(&floor,0,5,0)==-EINVAL && !floor.fault);
    assert(cam_cc_crm_floor_vote(&floor,1,1,0)==-EINVAL && !floor.fault);
    assert(cam_cc_crm_floor_vote(&floor,0,0,8)==-ERANGE && !floor.fault);
    assert(cam_cc_crm_floor_vote(&floor,1,0,0x4000)==-ERANGE && !floor.fault);
    static const u32 resources[8]={0,1,2,3,4,6,7,0};
    for(unsigned i=0;i<8;i++)minimum[i]=i==7?600:i+1;
    memset(&floor,0,sizeof(floor));memset(&m,0,sizeof(m));m.owner=&floor;
    assert(!cam_cc_crm_floor_init(&floor,minimum,send,&m));
    for(unsigned i=0;i<8;i++) {
        assert(!cam_cc_crm_floor_vote(&floor,i==7,resources[i],0));
        assert(m.values[i]==minimum[i] && !floor.requested[i]);
    }
    calls=m.calls;
    assert(!cam_cc_crm_floor_sync(&floor) && floor.released && m.calls==calls+8);
    for(unsigned i=0;i<8;i++) {
        assert(!m.values[i]);
        assert(!cam_cc_crm_floor_vote(&floor,i==7,resources[i],1) && m.values[i]==1);
    }
    // Every partial withdrawal failure stays latched; neither votes nor sync retry.
    for(unsigned failure=1;failure<=8;failure++) {
        memset(&floor,0,sizeof(floor));memset(&m,0,sizeof(m));m.owner=&floor;
        assert(!cam_cc_crm_floor_init(&floor,minimum,send,&m));
        m.fail_at=failure;m.error=failure&1?-EREMOTEIO:1;
        int expected=failure&1?-EREMOTEIO:-EIO;
        assert(cam_cc_crm_floor_sync(&floor)==expected && !floor.released && m.calls==failure);
        assert(cam_cc_crm_floor_sync(&floor)==expected && m.calls==failure);
        assert(cam_cc_crm_floor_vote(&floor,0,0,1)==expected && m.calls==failure);
    }
    memset(&floor,0,sizeof(floor));memset(&m,0,sizeof(m));m.owner=&floor;
    assert(!cam_cc_crm_floor_init(&floor,minimum,send,&m));m.fail_at=1;m.error=-EHOSTDOWN;
    assert(cam_cc_crm_floor_vote(&floor,0,0,2)==-EHOSTDOWN && !floor.requested[0]);
    assert(cam_cc_crm_floor_sync(&floor)==-EHOSTDOWN && m.calls==1);
    for(unsigned i=0;i<8;i++) {
        memset(&floor,0,sizeof(floor));memcpy(&before,&floor,sizeof(floor));
        u32 saved=minimum[i];minimum[i]=i==7?0x4000:8;
        assert(cam_cc_crm_floor_init(&floor,minimum,send,&m)==-ERANGE);
        assert(!memcmp(&floor,&before,sizeof(floor)));minimum[i]=saved;
    }
    puts("PASS: camera inherited floors: all8 voter identities, retained minima, software requests, zero extra writes for unnecessary release, idempotence and all8 partial withdrawal faults; no hardware");
}
