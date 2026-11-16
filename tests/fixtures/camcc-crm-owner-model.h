/* SPDX-License-Identifier: GPL-2.0-only */
/* Included into the original transport fixture after its model helpers. */
#define __maybe_unused __attribute__((unused))
static struct device owner_device;
static struct {
    struct device *dev;
    void *transport_context;
    int (*before_suspend)(void *);
    int (*after_resume)(void *);
    bool publication_started;
    int fault,primary_error;
} cam_cc_power;
static struct {bool owned,checked,firmware_enabled;void *base;} cam_cc_crm_guard;
static struct {bool owned;void *base;struct device *dev;int irq;} cam_cc_crmc_resource;
static bool cam_cc_clocks_ready;
static unsigned mutate_on_access;
static int cam_cc_power_access(void *context,unsigned reg)
{
    assert(context==&cam_cc_power && reg==0);
    if(cam_cc_power.fault)return cam_cc_power.fault;
    int ret=access_power(memory);
    if(mutate_on_access && access_calls==mutate_on_access)cam_cc_power.publication_started=true;
    return ret;
}
static int cam_cc_power_fail(int primary,int rollback,unsigned uncertain)
{
    assert(!rollback && !uncertain);
    cam_cc_power.primary_error=primary;cam_cc_power.fault=-EIO;return -EIO;
}
#include "camcc-sm7675-crm-pm.h"
#include "camcc-sm7675-crm-owner.h"
static void reset_owner(void)
{
    reset_model(&cam_cc_crm_owner_transport);
    memset(&cam_cc_power,0,sizeof(cam_cc_power));
    cam_cc_power.dev=&owner_device;
    cam_cc_crm_guard.owned=cam_cc_crm_guard.checked=cam_cc_crm_guard.firmware_enabled=true;
    cam_cc_crm_guard.base=memory;
    cam_cc_crmc_resource.owned=true;cam_cc_crmc_resource.base=memory;
    cam_cc_crmc_resource.dev=&owner_device;cam_cc_crmc_resource.irq=121;
    cam_cc_clocks_ready=true;mutate_on_access=0;
}
static void owner_checks(void)
{
    for(unsigned scenario=0;scenario<12;scenario++){
        reset_owner();
        switch(scenario){
        case 0:cam_cc_clocks_ready=false;break;
        case 1:cam_cc_power.publication_started=true;break;
        case 2:cam_cc_crm_guard.owned=false;break;
        case 3:cam_cc_crm_guard.checked=false;break;
        case 4:cam_cc_crm_guard.firmware_enabled=false;break;
        case 5:cam_cc_crmc_resource.owned=false;break;
        case 6:cam_cc_crmc_resource.base=NULL;break;
        case 7:cam_cc_crmc_resource.irq=0;break;
        case 8:cam_cc_crmc_resource.dev=NULL;break;
        case 9:cam_cc_power.transport_context=memory;break;
        case 10:cam_cc_power.before_suspend=cam_cc_crm_pm_idle;break;
        case 11:cam_cc_power.after_resume=cam_cc_crm_pm_resume;break;
        }
        assert(cam_cc_crm_owner_transport_bind()<0 && !reads && !writes && !registered);
    }
    reset_owner();powered=false;
    assert(cam_cc_crm_owner_transport_bind()==-EHOSTDOWN && !reads && !writes && !registered);
    reset_owner();cam_cc_power.fault=-EIO;
    assert(cam_cc_crm_owner_transport_bind()==-EIO && !reads && !writes && !registered);
    reset_owner();
    assert(cam_cc_crm_owner_transport_bind()==0 && enables==8 && votes==0);
    assert(cam_cc_power.transport_context==&cam_cc_crm_owner_transport);
    assert(cam_cc_power.before_suspend==cam_cc_crm_pm_idle && cam_cc_power.after_resume==cam_cc_crm_pm_resume);
    unsigned before=writes;
    assert(cam_cc_crm_owner_transport_bind()==-EBUSY && writes==before);
    assert(cam_cc_power.before_suspend(cam_cc_power.transport_context)==0);
    assert(cam_cc_crm_owner_transport.quiesced && !cam_cc_crm_owner_transport.ready);
    assert(cam_cc_power.after_resume(cam_cc_power.transport_context)==0);
    assert(cam_cc_crm_owner_transport.ready && !freed && !votes);
    /* Existing AP0 votes are retained and refuse power withdrawal. */
    reset_owner();
    for(unsigned state=0;state<3;state++)memory[(0x1060+state*0x40)/4]=3;
    assert(cam_cc_crm_owner_transport_bind()==0 && !votes);
    before=writes;
    assert(cam_cc_power.before_suspend(cam_cc_power.transport_context)==-EBUSY && writes==before);
    for(unsigned state=0;state<3;state++)assert(memory[(0x1060+state*0x40)/4]==3);
    /* Failure at any owned IRQ-enable write retains the powered permanent owner. */
    for(int failure=0;failure<8;failure++){
        reset_owner();enable_failure=failure;
        assert(cam_cc_crm_owner_transport_bind()==-EIO);
        assert(cam_cc_power.fault==-EIO && cam_cc_power.primary_error==-EIO);
        assert(cam_cc_power.transport_context==&cam_cc_crm_owner_transport);
        assert(registered && cam_cc_crm_owner_transport.irq_owned && masks==1 && !freed && !votes);
        before=writes;
        assert(cam_cc_crm_owner_transport_bind()==-EBUSY && writes==before);
    }
    reset_owner();request_error=-EBUSY;
    assert(cam_cc_crm_owner_transport_bind()==-EIO && cam_cc_power.primary_error==-EBUSY);
    assert(!registered && !writes && !freed && cam_cc_power.transport_context==&cam_cc_crm_owner_transport);
    reset_owner();memory[1]=0;
    assert(cam_cc_crm_owner_transport_bind()==-EIO && cam_cc_power.primary_error==-EINVAL);
    assert(!registered && !writes && !freed && cam_cc_power.transport_context==&cam_cc_crm_owner_transport);
    reset_owner();mutate_on_access=3;
    assert(cam_cc_crm_owner_transport_bind()==-EIO && cam_cc_power.primary_error==-EINVAL);
    assert(registered && masks==1 && !freed && cam_cc_power.transport_context==&cam_cc_crm_owner_transport);
    puts("PASS: camera owner exact-resource/power/publication refusals, permanent IRQ+PM binding, inherited AP0 retention, all8 IRQ-enable faults and post-IRQ bind failure retain ownership; synthetic only");
}
