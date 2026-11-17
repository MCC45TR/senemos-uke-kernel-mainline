// SPDX-License-Identifier: GPL-2.0-only
// Real common callback and gen3 dispatch; control/link and hardware calls modeled.
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint8_t u8;
#define BIT(n) (1U << (n))
#define MSM_CSID_MAX_SRC_STREAMS 4
#define MSM_CSID_PAD_SINK 0
#define CSID_PAYLOAD_MODE_DISABLED 0
#define dev_err(...) ((void)0)
struct csid_device;
struct csid_hw_ops {void (*configure_stream)(struct csid_device *,u8);};
struct csid_resources {const struct csid_hw_ops *hw_ops;};
struct media_pad {bool linked;};
struct v4l2_ctrl_handler {int error;};
struct csid_phy_config {unsigned en_vc;bool need_vc_update;};
struct csid_device {
 struct csid_resources *res;struct csid_phy_config phy;
 struct {unsigned nmodes;bool enabled;} testgen;
 struct v4l2_ctrl_handler ctrls;struct media_pad pads[1];
};
struct v4l2_subdev {struct csid_device *data;};
static unsigned controls,links,wrappers,rxs,rdis,ctrls,running,generation,configured[4];
static bool powered;
static struct csid_device *v4l2_get_subdevdata(struct v4l2_subdev *sd){return sd->data;}
static int v4l2_ctrl_handler_setup(struct v4l2_ctrl_handler *c){controls++;return c->error;}
static struct media_pad *media_pad_remote_pad_first(struct media_pad *p){links++;return p->linked?p:NULL;}
static void __csid_configure_wrapper(struct csid_device *c){(void)c;assert(powered);wrappers++;}
static void __csid_configure_rdi_stream(struct csid_device *c,u8 enable,u8 port,u8 vc){
 assert(powered&&port<4&&vc==0&&(c->phy.en_vc&BIT(port)));(void)enable;
 configured[port]=generation;rdis++;
}
static void __csid_configure_rx(struct csid_device *c,struct csid_phy_config *phy,int vc){assert(powered&&phy==&c->phy&&vc==0);rxs++;}
static void __csid_ctrl_rdi(struct csid_device *c,int enable,u8 port){
 assert(powered&&port<4&&(c->phy.en_vc&BIT(port)));ctrls++;
 if(enable)running|=BIT(port);else running&=~BIT(port);
}
#include "actual-stream.h"
static const struct csid_hw_ops ops={.configure_stream=csid_configure_stream};
static struct csid_resources resources={.hw_ops=&ops};
static struct csid_device csid={.res=&resources};
static struct v4l2_subdev sd={.data=&csid};
static void reset(unsigned mask,bool flag){
 memset(&csid,0,sizeof(csid));csid.res=&resources;csid.phy.en_vc=mask;
 csid.phy.need_vc_update=flag;csid.pads[0].linked=true;
 controls=links=wrappers=rxs=rdis=ctrls=running=generation=0;
 memset(configured,0,sizeof(configured));powered=true;
}
static void entries(bool print){
 const int errors[]={0,-EIO,-ETIMEDOUT,-EREMOTEIO};unsigned cases=0;
 for(unsigned mode=0;mode<3;mode++)for(unsigned generated=0;generated<2;generated++)for(unsigned link=0;link<2;link++)for(unsigned e=0;e<4;e++){
  reset(1,true);csid.testgen.nmodes=mode;csid.testgen.enabled=generated;csid.pads[0].linked=link;csid.ctrls.error=errors[e];
  int expected=mode&&errors[e]?errors[e]:!generated&&!link?-ENOLINK:0;
  assert(csid_set_stream(&sd,1)==expected);
  assert(controls==(mode?1U:0U));
  assert(links==(unsigned)(!(mode&&errors[e])&&!generated));
  assert(wrappers==(expected?0U:1U));assert(csid.phy.need_vc_update==(expected!=0));
  if(print)printf("entry:%u:%u:%u:%u:%d:%u:%u:%u:%u\n",mode,generated,link,e,expected,controls,links,wrappers,(unsigned)csid.phy.need_vc_update);
  cases++;
 }
 assert(cases==48);
}
int main(int argc,char **argv){
 if(argc==2&&!strcmp(argv[1],"--entries")){entries(true);return 0;}
 assert(argc==1);
 // The original callback starts once, then skips STREAMOFF without a link change.
 reset(1,true);assert(!csid_set_stream(&sd,1)&&running==1);
 assert(!csid_set_stream(&sd,0)&&running==0&&wrappers==2);
 unsigned cycles=0;
 for(unsigned mask=0;mask<16;mask++)for(unsigned initial=0;initial<2;initial++){
  reset(mask,initial);
  for(unsigned cycle=0;cycle<64;cycle++){
   generation=cycle+1;
   if(cycle&&cycle%8==0){powered=false;assert(!running);powered=true;csid.phy.need_vc_update=true;}
   unsigned old=wrappers;
   assert(!csid_set_stream(&sd,1));assert(wrappers==old+1&&running==mask&&!csid.phy.need_vc_update);
   for(unsigned port=0;port<4;port++)if(mask&BIT(port))assert(configured[port]==generation);
   // Changed format must be programmed even while the media links remain fixed.
   generation+=1000;
   assert(!csid_set_stream(&sd,0));assert(wrappers==old+2&&running==0);
   csid.pads[0].linked=false;csid.ctrls.error=-EIO;
   old=wrappers;assert(!csid_set_stream(&sd,0)&&wrappers==old+1&&!running);
   csid.pads[0].linked=true;csid.ctrls.error=0;
   cycles++;
  }
 }
 entries(false);assert(cycles==2048);
 puts("PASS: CSID stream: 2048 unchanged-link reopen/format/resume cycles, repeated stop, actual gen3 dispatch and 48 retained entry/refusal cases; no hardware");
 return 0;
}
