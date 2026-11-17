// SPDX-License-Identifier: GPL-2.0-only
// Actual reset/ISR callbacks; MMIO, IRQ delivery and completion are modeled.
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint32_t u32;
typedef uint8_t u8;
typedef int irqreturn_t;
#define BIT(n) (1U << (n))
#define GENMASK(h,l) ((~0U << (l)) & (~0U >> (31-(h))))
#define IRQ_HANDLED 1
#define MSM_CSID_MAX_SRC_STREAMS 4
#define CSID_RESET_TIMEOUT_MS 500
#define dev_err(...) ((void)0)
enum { CAMSS_7675, CAMSS_8550, CAMSS_8775P, CAMSS_8300 };
struct camss_resources { int version; };
struct camss { struct camss_resources *res; void *dev; };
struct csid_resources { bool is_lite; };
struct completion { bool done; };
struct csid_device {
 struct camss *camss; struct csid_resources *res; void *base;
 struct { u32 en_vc; } phy;
 u32 reg_update; unsigned id; struct completion reset_complete;
};
struct oracle_channel { u32 status,mask,clear,rup,top,update,done; };
struct oracle_irq { u32 top_status,top_mask,top_clear,done_status,done_mask,done_clear,cmd,reset,buf_top,rows;struct oracle_channel channel[4]; };
#include "actual-oracle.h"
static u32 words[0x300/4],pending[0x300/4];
static struct { u32 offset,value; } trace[256];
static unsigned traces,done_calls[4],completions,isrs;
static bool timeout;
static struct csid_device *active;
static const struct oracle_irq *oracle;
static irqreturn_t csid_isr(int,void *);
static bool csid_is_lite(struct csid_device *c) { return c->res->is_lite; }
static u32 offset(const void *p) {
 uintptr_t x=(uintptr_t)p-(uintptr_t)words;assert(x<sizeof(words)&&!(x&3));return x;
}
static u32 readl(const void *p) { return words[offset(p)/4]; }
static void writel(u32 value,void *p) {
 u32 at=offset(p);assert(traces<256);trace[traces].offset=at;trace[traces++].value=value;
 if(at==0x84)pending[0x7c/4]|=value;
 else if(at==0x94)pending[0x8c/4]|=value;
 else if(at>=0xf4&&at<=0x124&&(at-0xf4)%0x10==0)pending[(at-8)/4]|=value;
 else words[at/4]=value;
 if(at==0x14&&value==1)for(unsigned i=0;i<sizeof(words)/sizeof(words[0]);i++){words[i]&=~pending[i];pending[i]=0;}
 if(at==0x10&&value==5&&!timeout&&(words[0x80/4]&1)){
  words[0x7c/4]|=1;++isrs;assert(csid_isr(0,active)==IRQ_HANDLED);
 }
}
static void reinit_completion(struct completion *c) {c->done=false;}
static void complete(struct completion *c) {c->done=true;++completions;}
static unsigned long msecs_to_jiffies(unsigned x) {return x;}
static unsigned long wait_for_completion_timeout(struct completion *c,unsigned long t) {assert(t);return c->done?1:0;}
static void camss_buf_done(struct camss *c,unsigned id,unsigned port) {
 assert(c==active->camss&&id==active->id&&port<4);++done_calls[port];
}
#include "actual-csid.h"
static struct camss_resources resources;
static struct camss camss={.res=&resources};
static struct csid_resources csid_res;
static struct csid_device csid={.camss=&camss,.res=&csid_res,.base=words};
static void init(int version,bool lite,u32 enabled,bool fail) {
 memset(words,0,sizeof(words));memset(pending,0,sizeof(pending));
 memset(done_calls,0,sizeof(done_calls));traces=completions=isrs=0;timeout=fail;
 resources.version=version;csid_res.is_lite=lite;csid.phy.en_vc=enabled;
 csid.reg_update=0;active=&csid;oracle=&oracle_irqs[lite];
}
static void legacy(void) {
 for(int version=CAMSS_8550;version<=CAMSS_8300;version++)for(unsigned lite=0;lite<2;lite++)for(u32 mask=0;mask<16;mask++){
  init(version,lite,mask,false);assert(!csid_reset(&csid));
  printf("legacy:%d:%u:%u:",version,lite,mask);
  for(unsigned i=0;i<traces;i++)printf("%x=%x,",trace[i].offset,trace[i].value);
  puts("");
 }
}
int main(int argc,char **argv) {
 if(argc==2&&!strcmp(argv[1],"--legacy")){legacy();return 0;}
 assert(argc==1);unsigned resets=0,events=0,invalid=0;
 for(unsigned lite=0;lite<2;lite++)for(u32 mask=0;mask<(lite?16U:8U);mask++){
  init(CAMSS_7675,lite,mask,false);assert(!csid_reset(&csid));assert(completions==1&&isrs==1);
  u32 top=oracle->reset,done=0;
  for(unsigned i=0;i<oracle->rows;i++)if(mask&BIT(i)){
   top|=oracle->channel[i].top;done|=oracle->channel[i].done;
   assert(words[oracle->channel[i].mask/4]==oracle->channel[i].rup);
  }
  if(done)top|=oracle->buf_top;
  assert(words[oracle->top_mask/4]==top);assert(words[oracle->done_mask/4]==done);
  assert(words[oracle->top_status/4]==0&&words[oracle->done_status/4]==0);
  assert(trace[0].offset==oracle->top_mask&&trace[0].value==0);
  ++resets;
  for(unsigned kind=0;kind<3;kind++)for(u32 signal=0;signal<16;signal++){
   traces=0;memset(done_calls,0,sizeof(done_calls));csid.reg_update=0;
   words[oracle->top_status/4]=words[oracle->done_status/4]=0;
   for(unsigned i=0;i<oracle->rows;i++){
    csid.reg_update|=oracle->channel[i].update;
    words[oracle->channel[i].status/4]=kind!=2&&(signal&BIT(i))?oracle->channel[i].rup:0;
    if(kind!=1&&(signal&BIT(i)))words[oracle->done_status/4]|=oracle->channel[i].done;
    if(kind!=2&&(signal&BIT(i))&&(words[oracle->channel[i].mask/4]&oracle->channel[i].rup))words[oracle->top_status/4]|=oracle->channel[i].top;
   }
   if(words[oracle->done_status/4]&words[oracle->done_mask/4])words[oracle->top_status/4]|=oracle->buf_top;
   if(words[oracle->top_status/4]&words[oracle->top_mask/4])assert(csid_isr(0,&csid)==IRQ_HANDLED);
   for(unsigned i=0;i<oracle->rows;i++){
    bool expected=(mask&signal&BIT(i))!=0;
    assert(done_calls[i]==(unsigned)(expected&&kind!=1));
    assert(!!(csid.reg_update&oracle->channel[i].update)==!(expected&&kind!=2));
   }
   ++events;
  }
  init(CAMSS_7675,lite,mask,true);assert(csid_reset(&csid)==-EIO&&!completions);++resets;
 }
 for(unsigned lite=0;lite<2;lite++)for(u32 mask=1;mask<256;mask++)if(mask&~(lite?15U:7U)){
  init(CAMSS_7675,lite,mask,false);assert(csid_reset(&csid)==-EINVAL&&traces==0);++invalid;
 }
 assert(resets==48&&events==1152&&invalid==488);
 printf("PASS: CSID IRQ: %u reset/timeout, %u masked frame/RUP deliveries and %u invalid-path refusals; independent full/lite OEM fields, no hardware\n",resets,events,invalid);
 return 0;
}
