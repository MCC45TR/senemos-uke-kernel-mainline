/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual admission/startup/floor bodies; kernel framework boundaries modeled. */
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
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define CAM_CC_CRM_SIZE 0x2000
#define CAM_CC_CRMC_SIZE 0x2000
#define CAM_CC_POWER_RAILS 7
struct mutex {bool held;};
typedef struct {bool held;} spinlock_t;
static void mutex_init(struct mutex *m) {m->held=false;}
static void mutex_lock(struct mutex *m) {assert(!m->held);m->held=true;}
static void mutex_unlock(struct mutex *m) {assert(m->held);m->held=false;}
#define spin_lock_irqsave(l,f) do{(f)=0;assert(!(l)->held);(l)->held=true;}while(0)
#define spin_unlock_irqrestore(l,f) do{(void)(f);assert((l)->held);(l)->held=false;}while(0)
#include "camcc-sm7675-crm-clock.h"
static u32 primary[CAM_CC_CRM_SIZE/4],rom[CAM_CC_CRMC_SIZE/4];
static int device;
static struct {void *dev,*transport_context;bool publication_started;int fault,primary_error;int (*after_resume)(void *);} cam_cc_power;
static struct {bool checked,firmware_enabled,owned;void *base;} cam_cc_crm_guard;
static struct {bool owned;void *base,*dev;} cam_cc_crmc_resource;
static struct {bool probe_pm_held;u32 proxy_votes;} cam_cc_native;
static bool cam_cc_clocks_ready,cam_cc_crm_passive_attached;
struct clk_hw {unsigned id;};
struct clk_regmap {struct clk_hw hw;int vdd_data;};
struct clk_rcg2 {struct clk_regmap clkr;};
struct cam_cc_clock {struct clk_regmap *clock;};
static struct clk_rcg2 rcgs[8];
static struct cam_cc_clock clocks[8];
static struct {struct clk_rcg2 *rcg;u32 kind,resource;} cam_cc_crm_rcgs[8];
static int cam_cc_crm_passive[30];
struct cam_cc_crm_transport {
 struct mutex transaction;spinlock_t lock;struct cam_cc_crm_caps caps;
 bool ready,quiesced;int fault;
};
static struct cam_cc_crm_transport cam_cc_crm_owner_transport;
static unsigned reads,accesses,voltage_checks,rom_calls,binds,attaches,snapshots,sends,resumes;
static unsigned fail_access,fail_voltage,fail_rom,fail_snapshot,fail_send;
static int passive_error,ccf_error,bind_error,attach_error,resume_error;
static bool changed_startup,changed_caps;
static const char *phase;
static void cam_cc_native_probe_phase(const char *p) {phase=p;}
static int cam_cc_power_access(void *context,unsigned reg)
{
 assert(context==&cam_cc_power && !reg);accesses++;
 if(cam_cc_power.fault)return cam_cc_power.fault;
 return accesses==fail_access?-EREMOTEIO:0;
}
static u32 readl(const volatile void *address)
{
 uintptr_t p=(uintptr_t)address,a=(uintptr_t)primary,b=(uintptr_t)rom;
 assert(!cam_cc_power.fault && cam_cc_native.probe_pm_held);
 assert((p>=a && p<a+sizeof(primary))||(p>=b && p<b+sizeof(rom)));
 assert(!(p&3));reads++;return *(const volatile u32 *)address;
}
static struct cam_cc_clock *cam_cc_clock_find(struct clk_hw *hw)
{
 for(unsigned i=0;i<8;i++)if(hw==&rcgs[i].clkr.hw)return &clocks[i];
 return NULL;
}
static int clk_find_vdd_level(struct clk_hw *hw,void *vdd,u64 hz)
{
 assert(hw && vdd && hz>=100000000 && hz<=300000000);
 voltage_checks++;return voltage_checks==fail_voltage?-ERANGE:0;
}
static int cam_cc_crm_rom_load(u32 client,cam_cc_crm_lut_read_fn read,void *context,struct cam_cc_crm_lut *out)
{
 u32 a,b;rom_calls++;
 if(rom_calls==fail_rom)return -EREMOTEIO;
 int ret=read(context,client*8,&a);if(!ret)ret=read(context,client*8+4,&b);
 if(ret)return ret;
 assert(a==client+1 && b==client+2);
 *out=(struct cam_cc_crm_lut){.count=3};
 for(unsigned i=0;i<3;i++)out->rates[i]=(struct cam_cc_crm_rate){.hz=(i+1)*100000000ULL,.source=0};
 return 0;
}
static int cam_cc_crm_passive_preflight(void)
{
 assert(rom_calls==8 && voltage_checks==24 && !binds && !attaches);
 assert(!strcmp(phase,"crm-topology"));return passive_error;
}
static int cam_cc_crm_ccf_preflight(struct cam_cc_crm_clock clients[8])
{
 assert(!binds && !attaches);
 for(unsigned i=0;i<8;i++)assert(clients[i].send && clients[i].desired==100000000);
 return ccf_error;
}
static int cam_cc_crm_owner_fail(int error)
{
 if(!cam_cc_power.fault){cam_cc_power.primary_error=error;cam_cc_power.fault=-EIO;}
 cam_cc_crm_owner_transport.fault=error;
 cam_cc_crm_owner_transport.ready=false;
 return -EIO;
}
static int cam_cc_crm_owner_transport_bind(void)
{
 assert(!strcmp(phase,"crm-transport") && !attaches && reads>=16+2+72);
 binds++;if(bind_error)return cam_cc_crm_owner_fail(bind_error);
 cam_cc_crm_owner_transport.ready=true;
 assert(!cam_cc_crm_decode_caps(primary[1],primary[2],&cam_cc_crm_owner_transport.caps));
 if(changed_caps)cam_cc_crm_owner_transport.caps.perf_vcds++;
 if(changed_startup)primary[0x1060/4]=1;
 cam_cc_power.transport_context=&cam_cc_crm_owner_transport;
 return 0;
}
static int cam_cc_crm_managed_attach(struct cam_cc_crm_clock clients[8])
{
 assert(!strcmp(phase,"crm-attach") && binds==1 && !attaches && clients);
 attaches++;if(attach_error)return attach_error;
 cam_cc_crm_passive_attached=true;return 0;
}
static int cam_cc_crm_passive_snapshot(u32 index)
{
 assert(index<30 && cam_cc_crm_owner_transport.quiesced);
 snapshots++;return snapshots==fail_snapshot?-EREMOTEIO:0;
}
static int cam_cc_crm_transport_resume(struct cam_cc_crm_transport *t)
{
 assert(t==&cam_cc_crm_owner_transport && t->quiesced && snapshots==30);
 resumes++;if(resume_error)return resume_error;t->quiesced=false;return 0;
}
static int cam_cc_crm_transport_vote(struct cam_cc_crm_transport *t,u32 kind,u32 resource,u32 value)
{
 assert(t==&cam_cc_crm_owner_transport && cam_cc_crm_owned(kind,resource));
 assert(t->ready && !t->fault && value<=(kind?0x3fffU:7U));
 sends++;return sends==fail_send?-ETIMEDOUT:0;
}
#include "camcc-sm7675-crm-native.h"
static void reset(void)
{
 memset(primary,0,sizeof(primary));memset(rom,0,sizeof(rom));
 memset(&cam_cc_power,0,sizeof(cam_cc_power));
 memset(&cam_cc_crm_owner_transport,0,sizeof(cam_cc_crm_owner_transport));
 memset(&cam_cc_crm_native_floor,0,sizeof(cam_cc_crm_native_floor));
 memset(cam_cc_crm_native_tables,0,sizeof(cam_cc_crm_native_tables));
 memset(cam_cc_crm_native_clients,0,sizeof(cam_cc_crm_native_clients));
 memset(cam_cc_crm_native_rom_words,0,sizeof(cam_cc_crm_native_rom_words));
 cam_cc_crm_native_started=cam_cc_crm_native_ready=cam_cc_crm_passive_attached=false;
 cam_cc_power.dev=&device;cam_cc_clocks_ready=true;
 cam_cc_native.probe_pm_held=true;cam_cc_native.proxy_votes=7;
 cam_cc_crm_guard.checked=cam_cc_crm_guard.firmware_enabled=cam_cc_crm_guard.owned=true;
 cam_cc_crm_guard.base=primary;
 cam_cc_crmc_resource.owned=true;cam_cc_crmc_resource.base=rom;cam_cc_crmc_resource.dev=&device;
 primary[1]=(1U<<24)|(1U<<20)|(8U<<8);primary[2]=1U<<26;
 static const u32 resources[8]={0,1,2,3,4,6,7,0};
 for(unsigned i=0;i<8;i++){
  rom[i*2]=i+1;rom[i*2+1]=i+2;
  cam_cc_crm_rcgs[i].rcg=&rcgs[i];cam_cc_crm_rcgs[i].kind=i==7;cam_cc_crm_rcgs[i].resource=resources[i];
  clocks[i].clock=&rcgs[i].clkr;
  for(unsigned state=0;state<3;state++)primary[((i==7?0x1400:0x1060+resources[i]*4)+state*0x40)/4]=i==7?(0xe0000000U|200):2;
 }
 reads=accesses=voltage_checks=rom_calls=binds=attaches=snapshots=sends=resumes=0;
 fail_access=fail_voltage=fail_rom=fail_snapshot=fail_send=0;
 passive_error=ccf_error=bind_error=attach_error=resume_error=0;
 changed_startup=changed_caps=false;phase=NULL;
}
int main(void)
{
 reset();assert(!cam_cc_crm_native_admit());
 assert(cam_cc_crm_native_ready && binds==1 && attaches==1 && !sends);
 assert(cam_cc_power.after_resume==cam_cc_crm_native_resume);
 for(unsigned i=0;i<8;i++)assert(cam_cc_crm_native_floor.minimum[i]==(i==7?200U:2U));
 assert(cam_cc_crm_native_admit()==-EBUSY);
 assert(!cam_cc_crm_native_sync() && sends==8 && cam_cc_crm_native_floor.released);
 assert(!cam_cc_crm_native_sync() && sends==8);
 reset();cam_cc_native.proxy_votes=3;assert(cam_cc_crm_native_admit()==-EINVAL && !reads && !binds);
 for(unsigned i=1;i<=8;i++){reset();fail_rom=i;assert(cam_cc_crm_native_admit()==-EREMOTEIO && !binds && !attaches);}
 for(unsigned i=1;i<=24;i++){reset();fail_voltage=i;assert(cam_cc_crm_native_admit()==-ERANGE && !binds && !attaches);}
 for(unsigned i=0;i<2;i++){reset();if(i)ccf_error=-EINVAL;else passive_error=-EINVAL;assert(cam_cc_crm_native_admit()==-EINVAL && !binds && !attaches);}
 reset();changed_startup=true;assert(cam_cc_crm_native_admit()==-EIO && cam_cc_power.primary_error==-EAGAIN && !attaches);
 reset();changed_caps=true;assert(cam_cc_crm_native_admit()==-EIO && cam_cc_power.primary_error==-EUCLEAN && !attaches);
 reset();attach_error=-EINVAL;assert(cam_cc_crm_native_admit()==-EIO && !cam_cc_crm_native_ready);
 for(unsigned i=1;i<=8;i++){
  reset();assert(!cam_cc_crm_native_admit());fail_send=i;
  assert(cam_cc_crm_native_sync()==-EIO && sends==i && !cam_cc_crm_native_floor.released);
  assert(cam_cc_native.probe_pm_held && cam_cc_native.proxy_votes==7 && cam_cc_power.transport_context);
  assert(cam_cc_crm_native_sync()==-EIO && sends==i);
 }
 reset();assert(!cam_cc_crm_native_admit());cam_cc_crm_owner_transport.quiesced=true;
 assert(!cam_cc_crm_native_resume(&cam_cc_crm_owner_transport) && snapshots==30 && resumes==1);
 reset();assert(!cam_cc_crm_native_admit());cam_cc_crm_owner_transport.quiesced=true;rom[0]++;
 assert(cam_cc_crm_native_resume(&cam_cc_crm_owner_transport)==-EIO && !snapshots && !resumes);
 for(unsigned i=1;i<=30;i++){
  reset();assert(!cam_cc_crm_native_admit());cam_cc_crm_owner_transport.quiesced=true;fail_snapshot=i;
  assert(cam_cc_crm_native_resume(&cam_cc_crm_owner_transport)==-EIO && snapshots==i && !resumes);
 }
 reset();assert(!cam_cc_crm_native_admit());cam_cc_crm_owner_transport.quiesced=true;resume_error=-EUCLEAN;
 assert(cam_cc_crm_native_resume(&cam_cc_crm_owner_transport)==-EIO && resumes==1);
 puts("PASS: camera native composition: complete preflight before owner binding, stable startup, voltage refusal, eight partial floor faults, ROM/resume quarantine; synthetic boundaries only");
 return 0;
}
