/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual codec/runtime/STOP callbacks; independent I2C and DSP drain peers. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <limits.h>
#ifndef UKE_TEST_HZ
#define UKE_TEST_HZ 1000
#endif
static unsigned long jiffies;
#define time_before(a,b) ((long)((a)-(b)) < 0)
#define BIT(n) (1U << (n))
#define GENMASK(h,l) (((~0U) << (l)) & ((~0U) >> (31-(h))))
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
#define spin_lock_irqsave(p,f) do{(void)(p);(f)=0;}while(0)
#define spin_unlock_irqrestore(p,f) do{(void)(p);(void)(f);}while(0)
#include "uke-fs19xx-safety.h"
#include "native-stop-definitions.inc"
#ifndef FS19XX_STOP_DRAIN_MS
#define FS19XX_STOP_DRAIN_MS 6000
#endif
enum { UKE_FS_EMPTY,UKE_FS_STAGING,UKE_FS_READY,UKE_FS_PREPARED,UKE_FS_RUNNING,UKE_FS_FAULT };
struct mutex { bool held; };
static void mutex_lock(struct mutex *m){assert(!m->held);m->held=true;}
static void mutex_unlock(struct mutex *m){assert(m->held);m->held=false;}
static struct mutex *take_mutex(struct mutex *m){mutex_lock(m);return m;}
static void drop_mutex(struct mutex **m){mutex_unlock(*m);}
#define guard(t) struct mutex *scope_guard __attribute__((cleanup(drop_mutex)))=take_mutex
struct notifier_block { unsigned unused; };
struct work_struct { unsigned unused; };
struct delayed_work { struct work_struct work; unsigned delay,rearms; bool pending; };
#define to_delayed_work(p) container_of(p,struct delayed_work,work)
struct gpio_desc { bool reset; };
struct regmap { unsigned value[256]; };
struct fs19xx_priv {
 struct mutex lock;
 struct notifier_block protection_listener;
 struct regmap *regmap;
 struct gpio_desc *gpio_reset;
 struct delayed_work unmute_work;
 bool draining; unsigned long stop_deadline; void *preset;
 bool powered,unmuted,stream_active,speaker_enabled,suspended,removing;
 bool require_protection;
 unsigned pll_polls,volume;
 void *dev;
};
struct audioreach_graph { unsigned start_count; };
struct q6apm_fs19xx {
 struct mutex lock;
 struct { unsigned status; unsigned char cache[96]; } data;
 struct audioreach_graph *owner;
 bool removing,admitted;
};
struct q6apm { struct q6apm_fs19xx *fs19xx; };
struct q6apm_graph { struct q6apm *apm; struct audioreach_graph *ar_graph; unsigned id; };
static struct fs19xx_priv amps[4];
static struct regmap maps[4];
static struct gpio_desc gpios[4];
static struct q6apm_graph *current_graph;
static struct audioreach_graph *expected_owner;
static struct mutex fs19xx_listeners_lock;
static unsigned fs19xx_positions=15,fs19xx_guard_lock,fs19xx_listeners;
static struct uke_fs_guard fs19xx_guard;
static unsigned io_calls,fail_io,notifications,dsp_calls,erases;
static int dsp_error;
static bool ignore_mute,refusal_expected,simulate_stall,fault_queued;
static unsigned interleave_mask, mute_interleave_mask, fault_during_mute;
static struct work_struct fs19xx_fault_work;
#define system_highpri_wq NULL
static bool queue_work(void *queue,struct work_struct *work)
{assert(!queue&&work==&fs19xx_fault_work);fault_queued=true;return true;}
#include "native-idle-query.inc"
static int regmap_read(struct regmap *m,unsigned reg,unsigned *v)
{
 assert(reg<256);if(++io_calls==fail_io)return -EIO;*v=m->value[reg];return 0;
}
static int regmap_write(struct regmap *m,unsigned reg,unsigned value)
{
 assert(reg<256);if(++io_calls==fail_io)return -EIO;
 if(!(ignore_mute&&reg==FS19XX_REG_DACCTRL))m->value[reg]=value;
 return 0;
}
static void msleep(unsigned n){assert(n==10);}
static void gpiod_set_value_cansleep(struct gpio_desc *g,int v){assert(v==1);g->reset=true;}
#define system_percpu_wq NULL
#define msecs_to_jiffies(n) (((unsigned long)(n)*UKE_TEST_HZ+999)/1000)
static int mod_delayed_work(void *queue,struct delayed_work *w,unsigned delay)
{assert(!queue&&((delay>0&&delay<=msecs_to_jiffies(FS19XX_STOP_DRAIN_MS))));bool previous=w->pending;w->delay=delay;w->rearms++;w->pending=true;return previous;}
static bool cancel_delayed_work(struct delayed_work *w)
{assert(container_of(w,struct fs19xx_priv,unmute_work)->lock.held);bool previous=w->pending;w->pending=false;w->delay=0;return previous;}
static int fs19xx_chip_init(struct fs19xx_priv *a){(void)a;return 0;}
static int fs19xx_chip_start(struct fs19xx_priv *a){(void)a;return 0;}
static bool q6apm_fs19xx_running(void){return uke_fs_guard_running(&fs19xx_guard);}
static bool q6apm_fs19xx_configured(void){return uke_fs_guard_configured(&fs19xx_guard);}
static void q6apm_fs19xx_fault(void){uke_fs_guard_trip(&fs19xx_guard);fault_queued=true;}
#define dev_err(...) ((void)0)
static int notifier_from_errno(int n){return n;}
static int notifier_to_errno(int n){return n;}
#include "native-stop-codec.inc"
#include "uke-fs19xx-muted-stop.h"
#include "native-stop-event.inc"
static int blocking_notifier_call_chain(unsigned *head,unsigned mode,void *data)
{
 assert(head==&fs19xx_listeners&&!data);notifications++;
 for(unsigned i=0;i<4;i++){
  /* The scheduler can run another amp worker before its off notifier. */
  if(mode==0&&!fs19xx_guard.faulted)for(unsigned j=i;j<4;j++)if(amps[j].powered&&(interleave_mask&BIT(j))){
   amps[j].unmute_work.pending=false;
   fs19xx_unmute_work(&amps[j].unmute_work.work);
   assert(!amps[j].powered&&!amps[j].unmuted&&gpios[j].reset&&!fault_queued);
   assert(!fs19xx_guard.faulted&&!fs19xx_guard.mode);
  }
  if(mode==1&&!fs19xx_guard.faulted)for(unsigned j=0;j<4;j++)if(amps[j].powered&&(mute_interleave_mask&BIT(j))){
   amps[j].unmute_work.pending=false;fs19xx_unmute_work(&amps[j].unmute_work.work);
   assert(amps[j].powered&&!gpios[j].reset&&!fault_queued&&!fs19xx_guard.faulted);
   assert(amps[j].unmuted!=amps[j].draining);
  }
  int r=fs19xx_protection_event(&amps[i].protection_listener,mode,NULL);
  if(mode==1&&i+1==fault_during_mute)q6apm_fs19xx_fault();
  if(r)return r;
 }
 return 0;
}
static void uke_fs19xx_erase(void *data)
{assert(data==&current_graph->apm->fs19xx->data);memset(data,0,sizeof(current_graph->apm->fs19xx->data));erases++;}
#include "native-stop-runtime.inc"
static int audioreach_graph_mgmt_cmd(struct audioreach_graph *graph,unsigned command)
{
 assert(graph==current_graph->ar_graph&&command==0x01001003);dsp_calls++;
 if(q6apm_fs19xx_graph(current_graph)){
  if(refusal_expected)return -EREMOTEIO;
  if(current_graph->apm->fs19xx->data.status==UKE_FS_FAULT){
   for(unsigned i=0;i<4;i++)assert(!amps[i].powered&&gpios[i].reset);
   return -ETIMEDOUT;
  }
  /* Independent peer cannot drain VI after its transport was reset. */
  for(unsigned i=0;i<4;i++)if(!amps[i].powered||gpios[i].reset)return -ETIMEDOUT;
  assert(fs19xx_guard.mode==1&&!fs19xx_guard.faulted);
  for(unsigned i=0;i<4;i++){
   assert(!amps[i].unmuted&&(maps[i].value[FS19XX_REG_DACCTRL]&FS19XX_DACCTRL_MUTE_BIT));
   assert(maps[i].value[FS19XX_REG_PWRCTRL]==FS19XX_PWRCTRL_RUN);
   assert(maps[i].value[FS19XX_REG_SYSCTRL]==0xef);
   assert(maps[i].value[FS19XX_REG_I2SCTRL]==0x9c08);
   assert(maps[i].value[FS19XX_REG_VOLCTRL]==0xdfc0);
   /* Four forced pending-worker visits each rearm once; mute arms once. */
   assert(amps[i].unmute_work.rearms==1+((mute_interleave_mask&BIT(i))?4u:0u));
   assert(amps[i].unmute_work.pending&&amps[i].pll_polls==0);
  }
  if(simulate_stall){
   for(unsigned poll=1;poll<=FS19XX_LOCK_POLL_COUNT;poll++){
    jiffies=msecs_to_jiffies(poll*FS19XX_LOCK_POLL_MS);
    assert(amps[0].unmute_work.pending);amps[0].unmute_work.pending=false;
    fs19xx_unmute_work(&amps[0].unmute_work.work);
    assert(!amps[0].unmuted&&amps[0].powered&&!gpios[0].reset&&!fault_queued);
   }
   jiffies=msecs_to_jiffies(5000);
   fs19xx_unmute_work(&amps[0].unmute_work.work);
   assert(amps[0].powered&&!amps[0].unmuted&&!fault_queued);
   jiffies=msecs_to_jiffies(FS19XX_STOP_DRAIN_MS)-1;
   fs19xx_unmute_work(&amps[0].unmute_work.work);
   assert(amps[0].powered&&!amps[0].unmuted&&!fault_queued);
   jiffies++;
   fs19xx_unmute_work(&amps[0].unmute_work.work);
   assert(!amps[0].powered&&gpios[0].reset&&fault_queued&&fs19xx_guard.faulted);
   /* Execute the queued physical-mute sink outside the codec mutex. */
   assert(!amps[0].lock.held);assert(!fs19xx_gate(0));
   return -ETIMEDOUT;
  }
 }
 return dsp_error;
}
#include "native-stop-graph.inc"
static void fresh(struct q6apm_graph *graph)
{
 jiffies=0;current_graph=graph;memset(amps,0,sizeof(amps));memset(maps,0,sizeof(maps));memset(gpios,0,sizeof(gpios));
 memset(graph->apm->fs19xx,0,sizeof(*graph->apm->fs19xx));
 struct q6apm_fs19xx *fs=graph->apm->fs19xx;
 fs->owner=graph->ar_graph;fs->admitted=true;fs->data.status=UKE_FS_RUNNING;
 expected_owner=fs->owner;
 memset(fs->data.cache,0x5a,sizeof(fs->data.cache));
 fs19xx_guard=(struct uke_fs_guard){.generation=7,.mode=2};
 interleave_mask=mute_interleave_mask=fault_during_mute=0;io_calls=fail_io=notifications=dsp_calls=erases=0;dsp_error=0;ignore_mute=refusal_expected=simulate_stall=fault_queued=false;fs19xx_positions=15;
 graph->ar_graph->start_count=1;graph->id=40;
 for(unsigned i=0;i<4;i++){
  amps[i].preset=&maps[i];amps[i].regmap=&maps[i];amps[i].gpio_reset=&gpios[i];amps[i].powered=amps[i].unmuted=true;
  amps[i].stream_active=amps[i].speaker_enabled=true;amps[i].pll_polls=17;
  amps[i].require_protection=true;amps[i].volume=0xdf;
  amps[i].unmute_work.pending=true;amps[i].unmute_work.delay=FS19XX_HEALTH_POLL_MS;
  maps[i].value[FS19XX_REG_STATUS]=FS19XX_STATUS_PLLS;maps[i].value[FS19XX_REG_TSCTRL]=FS19XX_TSCTRL_TSEN;
  maps[i].value[FS19XX_REG_DACCTRL]=0x210;maps[i].value[FS19XX_REG_PWRCTRL]=FS19XX_PWRCTRL_RUN;
  maps[i].value[FS19XX_REG_SYSCTRL]=0xef;maps[i].value[FS19XX_REG_I2SCTRL]=0x9c08;maps[i].value[FS19XX_REG_VOLCTRL]=0xdfc0;
 }
}
static void finished(bool failed)
{
 struct q6apm_fs19xx *fs=current_graph->apm->fs19xx;
 assert(dsp_calls==1&&!current_graph->ar_graph->start_count&&fs->owner==expected_owner);
 for(unsigned i=0;i<4;i++)assert(!amps[i].powered&&!amps[i].unmuted&&gpios[i].reset&&!amps[i].unmute_work.pending);
 assert(fs->data.status==(failed?UKE_FS_FAULT:UKE_FS_PREPARED));
 for(unsigned i=0;i<sizeof(fs->data.cache);i++)assert(fs->data.cache[i]==(failed?0:0x5a));
 assert(erases==(failed?1u:0u)|| (failed&&erases==2));
}
int main(void)
{
 struct q6apm_fs19xx fs;struct q6apm apm={&fs};struct audioreach_graph ar;
 struct q6apm_graph graph={&apm,&ar,40};unsigned cases=0;

 for(unsigned mask=1;mask<16;mask++){
  fresh(&graph);interleave_mask=mask;assert(!q6apm_graph_stop(&graph));finished(false);
  assert(!fault_queued&&!fs19xx_guard.faulted&&!fs19xx_guard.mode);cases++;
 }
 for(unsigned mask=1;mask<16;mask++){
  fresh(&graph);interleave_mask=mask;fs19xx_guard.mode=0;
  for(unsigned i=0;i<4;i++)if(mask&BIT(i)){
   amps[i].unmuted=true;amps[i].unmute_work.pending=false;
   fs19xx_unmute_work(&amps[i].unmute_work.work);
   assert(!amps[i].powered&&!amps[i].unmuted&&gpios[i].reset&&!fault_queued);
  }
  assert(!fs19xx_guard.faulted);cases++;
 }
 fresh(&graph);q6apm_fs19xx_fault();assert(fault_queued&&fs19xx_guard.faulted);cases++;
 for(unsigned mode=0;mode<3;mode++){
  fresh(&graph);fs19xx_guard.mode=mode;fs19xx_guard.faulted=true;
  amps[0].unmute_work.pending=false;fs19xx_unmute_work(&amps[0].unmute_work.work);
  assert(fault_queued&&!amps[0].powered&&!amps[0].unmuted&&gpios[0].reset);cases++;
 }
 fresh(&graph);assert(!q6apm_graph_stop(&graph));finished(false);cases++;
 fresh(&graph);fs.data.status=UKE_FS_PREPARED;assert(!q6apm_graph_stop(&graph));finished(false);cases++;
 for(unsigned count=0;count<=4;count++)if(count!=1){
  fresh(&graph);ar.start_count=count;assert(!q6apm_graph_stop(&graph));
  assert(!dsp_calls&&!notifications&&!io_calls&&ar.start_count==(count?count-1:0));cases++;
 }
 for(unsigned fault=1;fault<=20;fault++){
  fresh(&graph);fail_io=fault;assert(q6apm_graph_stop(&graph)==-EIO);finished(true);cases++;
 }
 fresh(&graph);ignore_mute=true;assert(q6apm_graph_stop(&graph)==-EIO);finished(true);cases++;
 for(unsigned e=0;e<2;e++){
  fresh(&graph);dsp_error=e?-EREMOTEIO:-ETIMEDOUT;
  assert(q6apm_graph_stop(&graph)==dsp_error);finished(true);cases++;
 }
 fresh(&graph);simulate_stall=true;assert(q6apm_graph_stop(&graph)==-ETIMEDOUT);finished(true);cases++;
 fresh(&graph);fs19xx_positions=7;assert(q6apm_graph_stop(&graph)==-ENODEV);finished(true);cases++;
 for(unsigned kind=0;kind<7;kind++){
  fresh(&graph);refusal_expected=true;
  if(kind==0)fs.removing=true;else if(kind==1)fs.owner=expected_owner=NULL;else fs.data.status=kind==6?UKE_FS_FAULT:kind-2;
  if(kind==5)fs.data.status=UKE_FS_READY;
  assert(q6apm_graph_stop(&graph)==-ENODATA);finished(true);cases++;
 }
 for(unsigned kind=0;kind<2;kind++){
  fresh(&graph);if(kind)fs.admitted=false;else graph.id=41;
  assert(!q6apm_graph_stop(&graph)&&dsp_calls==1&&!notifications&&!io_calls&&fs.data.status==UKE_FS_RUNNING);cases++;
 }
 for(unsigned i=0;i<4;i++){
  fresh(&graph);assert(!q6apm_fs19xx_stopping(&graph));
  assert(amps[i].draining&&!amps[i].unmuted);
  jiffies=msecs_to_jiffies(2000);unsigned previous=amps[i].pll_polls;
  fs19xx_unmute_work(&amps[i].unmute_work.work);
  assert(amps[i].powered&&!amps[i].unmuted&&amps[i].pll_polls==previous&&!fault_queued);
  assert(fs19xx_power_on(&amps[i])==-EBUSY);
  q6apm_fs19xx_fault();fs19xx_unmute_work(&amps[i].unmute_work.work);
  assert(!amps[i].powered&&!amps[i].unmuted&&!amps[i].draining&&gpios[i].reset);cases++;
 }
 fresh(&graph);jiffies=ULONG_MAX-msecs_to_jiffies(1000);
 assert(!q6apm_fs19xx_stopping(&graph));unsigned long deadline=amps[0].stop_deadline;
 jiffies=deadline-1;fs19xx_unmute_work(&amps[0].unmute_work.work);
 assert(amps[0].powered&&!fault_queued&&amps[0].unmute_work.delay==1);
 jiffies=deadline;fs19xx_unmute_work(&amps[0].unmute_work.work);
 assert(!amps[0].powered&&fault_queued&&!amps[0].draining);cases++;
 fresh(&graph);assert(!q6apm_fs19xx_stopping(&graph));
 mutex_lock(&amps[0].lock);fs19xx_power_off(&amps[0]);mutex_unlock(&amps[0].lock);assert(!amps[0].draining&&!amps[0].unmute_work.pending);cases++;
 for(unsigned mask=1;mask<16;mask++){
  fresh(&graph);mute_interleave_mask=mask;assert(!q6apm_graph_stop(&graph));finished(false);
  assert(!fault_queued&&!fs19xx_guard.faulted&&!fs19xx_guard.mode);cases++;
 }
 for(unsigned i=1;i<=4;i++){
  fresh(&graph);fault_during_mute=i;
  assert(q6apm_graph_stop(&graph)==-EIO);finished(true);assert(fs19xx_guard.faulted&&fault_queued);cases++;
 }
 fresh(&graph);fs19xx_guard.mode=0;for(unsigned i=0;i<4;i++)amps[i].powered=amps[i].unmuted=false;
 assert(!fs19xx_gate(1)&&fs19xx_guard.mode==1&&!fault_queued);cases++;
 printf("Actual muted STOP deadline and sequential publication: %u cases, readback mute before DSP drain, retained VI/clock/gain, post-reply poweroff, all20 I2C faults, ignored write, absolute deadline across HZ/wrap, stale pending workers, restart refusal, active fault, remote/timeout, reference and refusal paths passed; synthetic only.\n",cases);
}
