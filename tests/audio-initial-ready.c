/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual wait helper and control/shutdown callbacks, deterministic peers. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <limits.h>
typedef uint8_t u8;
typedef unsigned int uke_fs_generation;
enum { UKE_FS_EMPTY, UKE_FS_STAGING, UKE_FS_READY, UKE_FS_PREPARED,
       UKE_FS_RUNNING, UKE_FS_FAULT };
#define UKE_FS19XX_FRAME_BYTES 8
#define UKE_FS_BEGIN 42
#define CAP_SYS_RAWIO 1
#define READ_ONCE(v) (v)
#define time_after_eq(a,b) ((long)((a)-(b))>=0)
#define msecs_to_jiffies(n) ((unsigned long)(n))
struct mutex { bool locked; };
struct wait_queue_head { unsigned int wakes; };
struct q6apm_fs19xx {
 struct mutex lock;
 struct wait_queue_head ready_wait;
 unsigned long ready_deadline;
 bool ready_wait_started;
 struct { unsigned int status; } data;
 void *owner;
 bool removing;
 uke_fs_generation provision_generation;
};
struct q6apm { struct q6apm_fs19xx *fs19xx; };
struct snd_soc_component { void *dev; };
struct snd_kcontrol { struct snd_soc_component *component; };
struct snd_ctl_elem_value { struct { struct { u8 data[8]; } bytes; } value; };
static unsigned long jiffies;
static struct q6apm_fs19xx *current;
static unsigned int waits,mode,gates;
static bool privileged=true;
static int guard_error;
static struct { unsigned int generation; } fs19xx_guard={7};
static int fs19xx_guard_lock,fs19xx_fault_work;
static void mutex_lock(struct mutex *m){assert(!m->locked);m->locked=true;}
static void mutex_unlock(struct mutex *m){assert(m->locked);m->locked=false;}
static void unlock_guard(struct mutex **m){mutex_unlock(*m);}
#define guard(t) struct mutex *scope_guard __attribute__((cleanup(unlock_guard)))=mutex_lock_for_guard
static struct mutex *mutex_lock_for_guard(struct mutex *m){mutex_lock(m);return m;}
#define spin_lock_irqsave(p,f) do{(void)(p);(f)=0;}while(0)
#define spin_unlock_irqrestore(p,f) do{(void)(p);(void)(f);}while(0)
static bool capable(int cap){assert(cap==CAP_SYS_RAWIO);return privileged;}
static void *snd_kcontrol_chip(struct snd_kcontrol *c){return c->component;}
static void *dev_get_drvdata(void *p){return p;}
static void wake_up_all(struct wait_queue_head *q){q->wakes++;}
static void flush_work(int *w){assert(w==&fs19xx_fault_work);}
static int uke_fs_guard_reprovision(void *g,unsigned int generation){assert(g==&fs19xx_guard&&generation==7);return guard_error;}
static void uke_fs19xx_erase(void *data){memset(data,0,sizeof(current->data));}
static unsigned int uke_fs19xx_word(const u8 *p){return p[0];}
static bool fs19xx_verify(void *context,unsigned int slot,const u8 *data,size_t bytes){(void)context;(void)slot;(void)data;(void)bytes;return true;}
static int uke_fs19xx_provision(void *data,u8 *frame,size_t bytes,bool owner,
 bool (*verify)(void *,unsigned int,const u8 *,size_t),void *context)
{
 assert(data==&current->data&&bytes==8&&verify==fs19xx_verify&&context==current);
 if(owner)return -EBUSY;
 current->data.status=frame[0];return 0;
}
static void memzero_explicit(void *p,size_t n){memset(p,0,n);}
static int fs19xx_gate(unsigned int mode){assert(!mode);gates++;return 0;}
#include "native-ready-publish.inc"
static long mock_wait(unsigned long ticks);
#define wait_event_timeout(q,condition,ticks) ((condition)?1:mock_wait(ticks))
#include "uke-fs19xx-initial-ready.h"
static void publish(unsigned int status)
{
 struct q6apm apm={current};struct snd_soc_component component={&apm};
 struct snd_kcontrol control={&component};struct snd_ctl_elem_value value={0};
 value.value.bytes.data[0]=status;
 if(status==UKE_FS_STAGING)value.value.bytes.data[4]=UKE_FS_BEGIN;
 int result=fs19xx_control_put(&control,&value);
 assert(result==(guard_error&&status==UKE_FS_READY?guard_error:1));
 for(unsigned i=0;i<8;i++)assert(!value.value.bytes.data[i]);
}
static long mock_wait(unsigned long ticks)
{
 assert(current&&!current->lock.locked&&ticks>0&&ticks<=2000);
 assert(++waits<=32);
 unsigned before=current->ready_wait.wakes;
 if(mode==0){jiffies+=ticks;return 0;}
 if(mode==1||mode==3){
  publish(UKE_FS_STAGING);publish(UKE_FS_READY);jiffies+=63;
 }else if(mode==2){
  struct q6apm apm={current};q6apm_fs19xx_shutdown(&apm);jiffies+=7;
 }else if(mode==4){
  jiffies+=ticks<100?ticks:100;return 1; /* spurious wake shares one budget */
 }else assert(false);
 if(current->ready_wait.wakes==before)jiffies+=ticks-63;
 return 1;
}
static struct q6apm_fs19xx fresh(unsigned int status)
{
 struct q6apm_fs19xx fs={0};fs.data.status=status;
 waits=gates=0;guard_error=0;privileged=true;mode=0;jiffies=100;
 return fs;
}
int main(void)
{
 unsigned cases=0;
 for(unsigned state=0;state<7;state++){
  struct q6apm_fs19xx fs=fresh(state);current=&fs;
  int result=fs19xx_wait_initial_ready(&fs);
  assert(result==(state==UKE_FS_READY?0:-ENODATA));
  assert(waits==(state==UKE_FS_EMPTY||state==UKE_FS_STAGING?1u:0u));cases++;
 }
 for(unsigned initial=0;initial<=1;initial++){
  struct q6apm_fs19xx fs=fresh(initial);current=&fs;mode=1;
  assert(!fs19xx_wait_initial_ready(&fs));
  assert(jiffies==163&&waits==1&&fs.data.status==UKE_FS_READY&&fs.ready_wait.wakes==2&&!fs.lock.locked);cases++;
  fs=fresh(initial);current=&fs;mode=3;guard_error=-EIO;
  assert(fs19xx_wait_initial_ready(&fs)==-ENODATA&&fs.data.status==UKE_FS_FAULT&&jiffies==163);cases++;
  fs=fresh(initial);current=&fs;mode=2;
  assert(fs19xx_wait_initial_ready(&fs)==-ENODATA&&fs.removing&&gates==1&&waits==1&&jiffies==107);cases++;
  fs=fresh(initial);current=&fs;mode=4;
  assert(fs19xx_wait_initial_ready(&fs)==-ENODATA&&jiffies==2100&&waits==20);
  unsigned prior=waits;assert(fs19xx_wait_initial_ready(&fs)==-ENODATA&&waits==prior&&fs.ready_deadline==2100);cases++;
 }
 for(unsigned state=0;state<=5;state++)for(unsigned which=0;which<2;which++){
  struct q6apm_fs19xx fs=fresh(state);current=&fs;
  if(which)fs.removing=true;else fs.owner=&fs;
  assert(fs19xx_wait_initial_ready(&fs)==-ENODATA&&waits==0);cases++;
 }
 {
  struct q6apm_fs19xx fs=fresh(UKE_FS_EMPTY);current=&fs;mode=1;
  jiffies=ULONG_MAX-31;unsigned long initial=jiffies;
  assert(!fs19xx_wait_initial_ready(&fs)&&jiffies-initial==63&&waits==1);cases++;
 }
 {
  struct q6apm_fs19xx fs=fresh(UKE_FS_STAGING);current=&fs;mode=0;
  jiffies=ULONG_MAX-31;unsigned long initial=jiffies;
  assert(fs19xx_wait_initial_ready(&fs)==-ENODATA&&jiffies-initial==2000&&waits==1);cases++;
 }
 printf("Actual initial-ready wait: %u cases, pre-DSP publication, unlocked writer, one deadline, fault/owner/shutdown and wrap passed; synthetic only.\n",cases);
 return 0;
}
