/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual extracted functions; all DRM, locking and transport actors are synthetic. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint64_t atomic64_t;
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define MIPI_DSI_DCS_SHORT_WRITE_PARAM 0x15
#define IS_ENABLED(x) 1
#define EXPORT_SYMBOL_GPL(x)
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
struct mutex { int held; };
static void mutex_lock(struct mutex *m) { assert(!m->held);m->held=1; }
static void mutex_unlock(struct mutex *m) { assert(m->held);m->held=0; }
#define lockdep_assert_held(m) assert((m)->held)
static uint64_t atomic64_read(atomic64_t *v) { return *v; }
struct device { const char *of_node; };
struct mipi_dsi_device { void *host;struct device dev; };
struct drm_panel { int unused; };
struct o82_panel {
 struct drm_panel panel;
 struct mipi_dsi_device *dsi[2];
 struct mutex lock,abm_lock;
 unsigned applied_abm_level,requested_abm_level;
 bool abm_valid,removing,gesture_retained,prepared;
 atomic64_t touch_state;
};
static unsigned sends,reports,touch_calls,faults;
static u8 payload[16][2];
#define dev_err(dev,...) ((void)(dev),reports++)
#define drm_err_ratelimited(dev,...) ((void)(dev),reports++)
#include "panel-types.inc"
static int o82_send(struct o82_panel *c,const struct o82_command *cmd,bool lpm)
{
 assert(c->prepared&&c->abm_valid&&lpm&&cmd->len==2);
 assert(cmd->type==MIPI_DSI_DCS_SHORT_WRITE_PARAM);
 assert(cmd->data[0]==0xff||cmd->data[0]==0x55);
 assert(sends<15);memcpy(payload[++sends],cmd->data,2);
 return (faults&(1U<<sends))?-EIO:0;
}
static void o82_touch_state(struct o82_panel *c,bool reset,bool ready)
{
 assert(!reset&&ready&&c->abm_lock.held&&!c->lock.held);
 c->touch_state|=1;touch_calls++;
}
#include "panel-functions.inc"
struct msm_dsi { void *host; };
static struct msm_dsi master;
static bool have_master=true,bonded=true,sync_mode=true,board=true,soc=true,dfps_fault;
#define DSI_CLOCK_MASTER 0
#define IS_BONDED_DSI() bonded
#define IS_SYNC_NEEDED() sync_mode
#define IS_MASTER_DSI_LINK(id) ((id)==0)
static struct msm_dsi *dsi_mgr_get_dsi(int id) { assert(id==0);return have_master?&master:NULL; }
static bool of_machine_is_compatible(const char *s)
{ if(!strcmp(s,"xiaomi,uke"))return board;assert(!strcmp(s,"qcom,sm7675"));return soc; }
static bool of_device_is_compatible(const char *node,const char *s) { return node&&!strcmp(node,s); }
static bool msm_dsi_manager_uke_dfps_failed(void) { return dfps_fault; }
static struct {
 struct drm_panel *uke_abm_panel;
 int (*uke_abm_apply)(struct drm_panel *,unsigned);
} msm_dsim_glb;
static struct mutex uke_dfps_panel_lock;
static const int dsi_mgr_bridge_funcs=1,foreign_funcs=2;
struct drm_bridge { const void *funcs; };
struct dsi_bridge { struct drm_bridge base;int id;bool powered,video_enabled;struct drm_panel *o82_panel; };
struct drm_encoder { struct drm_bridge *bridge; };
static unsigned references;
static struct drm_bridge *drm_bridge_chain_get_first_bridge(struct drm_encoder *e)
{ if(e->bridge)references++;return e->bridge; }
static void drm_bridge_put(struct drm_bridge *b) { if(b){assert(references);references--;} }
#define to_dsi_bridge(p) container_of(p,struct dsi_bridge,base)
#include "registry-functions.inc"
struct drm_crtc { int unused; };
struct drm_crtc_state { bool active,modeset;unsigned encoder_mask; };
struct drm_connector { void *abm_level_property; };
struct drm_connector_state { struct drm_crtc *crtc;unsigned abm_level; };
struct drm_device { struct drm_encoder *encoder; };
struct drm_atomic_commit {
 struct drm_device *dev;struct drm_connector *connector;
 struct drm_connector_state old,new;
 struct drm_crtc_state crtc;
};
#define for_each_oldnew_connector_in_state(s,c,o,n,i) \
 for((i)=0;(i)<1&&((c)=(s)->connector,(o)=&(s)->old,(n)=&(s)->new,1);(i)++)
#define drm_for_each_encoder_mask(e,d,m) \
 for((e)=((m)&1)?(d)->encoder:NULL;(e);(e)=NULL)
static struct drm_crtc_state *drm_atomic_get_new_crtc_state(struct drm_atomic_commit *s,struct drm_crtc *c)
{ assert(c==s->new.crtc);return &s->crtc; }
static bool drm_atomic_crtc_needs_modeset(struct drm_crtc_state *s) { return s->modeset; }
#include "commit-functions.inc"
static struct mipi_dsi_device dsi;
static struct o82_panel context;
static void fresh(unsigned level)
{
 assert(!context.lock.held&&!context.abm_lock.held&&!uke_dfps_panel_lock.held&&!references);
 memset(&context,0,sizeof(context));context.dsi[0]=&dsi;
 context.prepared=context.abm_valid=true;context.touch_state=11;
 context.applied_abm_level=context.requested_abm_level=level;
 sends=reports=touch_calls=faults=0;memset(payload,0,sizeof(payload));
}
int main(void)
{
 static char host;
 const u8 modes[]={0,1,1,2,3};
 unsigned cases=0;
 master.host=dsi.host=&host;dsi.dev.of_node="xiaomi,o82-42-02-0b";
 for(unsigned old=0;old<5;old++)for(unsigned level=0;level<5;level++) {
  fresh(old);assert(!o82_abm_update(&context.panel,level));
  assert(context.applied_abm_level==level&&context.abm_valid&&context.prepared);
  assert(sends==(old==level?0U:2U));
  if(sends)assert(payload[1][0]==0xff&&payload[1][1]==0x10&&payload[2][0]==0x55&&payload[2][1]==modes[level]);
  assert(!context.lock.held&&!context.abm_lock.held);cases++;
 }
 fresh(1);assert(o82_abm_update(&context.panel,5)==-EINVAL&&!sends);cases++;
 fresh(1);context.prepared=false;assert(o82_abm_update(&context.panel,2)==-EHOSTDOWN&&!sends);cases++;
 fresh(1);context.removing=true;assert(o82_abm_update(&context.panel,2)==-ESHUTDOWN&&!sends);cases++;
 fresh(1);context.gesture_retained=true;assert(o82_abm_update(&context.panel,2)==-ESHUTDOWN&&!sends);cases++;
 for(unsigned failure=1;failure<=2;failure++) {
  fresh(1);faults=1U<<failure;assert(o82_abm_update(&context.panel,4)==-EIO);
  assert(sends==failure+2&&context.applied_abm_level==1&&context.abm_valid);cases++;
 }
 fresh(1);faults=(1U<<1)|(1U<<2);assert(o82_abm_update(&context.panel,4)==-EIO);
 assert(sends==2&&!context.abm_valid&&reports==1);
 assert(o82_abm_update(&context.panel,3)==-EIO&&sends==2);cases++;
 fresh(0);context.touch_state=10;assert(!o82_abm_update(&context.panel,4)&&!sends);
 assert(context.applied_abm_level==0&&context.requested_abm_level==4);
 o82_abm_first_frame_complete(&context);
 assert(sends==2&&context.applied_abm_level==4&&context.touch_state==11&&touch_calls==1);
 assert(!o82_abm_update(&context.panel,4)&&sends==2);cases++;
 fresh(0);context.touch_state=10;faults=1U<<1;
 assert(!o82_abm_update(&context.panel,3));o82_abm_first_frame_complete(&context);
 assert(context.touch_state==11&&context.applied_abm_level==0&&context.abm_valid&&reports==1);cases++;

 fresh(0);struct drm_panel stranger={0};
 assert(!qcom_uke_dsi_abm_register(&dsi,&context.panel,o82_abm_update));cases++;
 assert(qcom_uke_dsi_abm_register(&dsi,&stranger,o82_abm_update)==-EBUSY);
 assert(qcom_uke_dsi_abm_register(&dsi,&stranger,NULL)==-EBUSY);
 assert(msm_dsim_glb.uke_abm_panel==&context.panel);cases++;
 board=false;assert(qcom_uke_dsi_abm_register(&dsi,&context.panel,o82_abm_update)==-EOPNOTSUPP);board=true;cases++;
 soc=false;assert(qcom_uke_dsi_abm_register(&dsi,&context.panel,o82_abm_update)==-EOPNOTSUPP);soc=true;cases++;
 have_master=false;assert(qcom_uke_dsi_abm_register(&dsi,&context.panel,o82_abm_update)==-EOPNOTSUPP);have_master=true;cases++;
 bonded=false;assert(qcom_uke_dsi_abm_register(&dsi,&context.panel,o82_abm_update)==-EOPNOTSUPP);bonded=true;cases++;
 sync_mode=false;assert(qcom_uke_dsi_abm_register(&dsi,&context.panel,o82_abm_update)==-EOPNOTSUPP);sync_mode=true;cases++;
 dsi.dev.of_node="foreign";assert(qcom_uke_dsi_abm_register(&dsi,&context.panel,o82_abm_update)==-EOPNOTSUPP);
 dsi.dev.of_node="xiaomi,o82-36-02-0a";assert(!qcom_uke_dsi_abm_register(&dsi,&context.panel,o82_abm_update));cases++;
 assert(qcom_uke_dsi_abm_register(NULL,&context.panel,o82_abm_update)==-EOPNOTSUPP);cases++;
 struct dsi_bridge bridge={.base={&dsi_mgr_bridge_funcs},.powered=true,.video_enabled=true,.o82_panel=&context.panel};
 struct drm_encoder encoder={&bridge.base};
 assert(!msm_dsi_manager_uke_abm_apply(&encoder,2)&&context.applied_abm_level==2&&!references);cases++;
 const unsigned previous_sends=sends;
 bridge.powered=false;assert(msm_dsi_manager_uke_abm_apply(&encoder,3)==-EOPNOTSUPP);bridge.powered=true;
 bridge.video_enabled=false;assert(msm_dsi_manager_uke_abm_apply(&encoder,3)==-EOPNOTSUPP);bridge.video_enabled=true;
 bridge.id=1;assert(msm_dsi_manager_uke_abm_apply(&encoder,3)==-EOPNOTSUPP);bridge.id=0;
 bridge.base.funcs=&foreign_funcs;assert(msm_dsi_manager_uke_abm_apply(&encoder,3)==-EOPNOTSUPP);bridge.base.funcs=&dsi_mgr_bridge_funcs;
 dfps_fault=true;assert(msm_dsi_manager_uke_abm_apply(&encoder,3)==-EOPNOTSUPP);dfps_fault=false;
 assert(msm_dsi_manager_uke_abm_apply(&encoder,5)==-EOPNOTSUPP);
 assert(sends==previous_sends&&!references);cases+=6;
 assert(!qcom_uke_dsi_abm_register(&dsi,&context.panel,NULL));
 assert(msm_dsi_manager_uke_abm_apply(&encoder,3)==-EOPNOTSUPP&&!references);cases++;

 fresh(0);assert(!qcom_uke_dsi_abm_register(&dsi,&context.panel,o82_abm_update));
 struct drm_crtc crtc={0},other={0};struct drm_device device={&encoder};
 struct drm_connector connector={&host};
 struct drm_atomic_commit commit={.dev=&device,.connector=&connector,.old={&crtc,0},.new={&crtc,4},.crtc={true,false,1}};
 assert(msm_uke_abm_changed(&commit,&crtc));msm_uke_abm_commit(&commit);
 assert(context.applied_abm_level==4&&sends==2);cases++;
 fresh(0);commit.crtc.modeset=true;msm_uke_abm_commit(&commit);assert(!sends);cases++;
 commit.crtc.modeset=false;commit.crtc.active=false;msm_uke_abm_commit(&commit);assert(!sends);cases++;
 commit.crtc.active=true;commit.new.crtc=&other;msm_uke_abm_commit(&commit);assert(!sends);cases++;
 commit.new.crtc=&crtc;commit.new.abm_level=commit.old.abm_level;assert(!msm_uke_abm_changed(&commit,&crtc));msm_uke_abm_commit(&commit);assert(!sends);cases++;
 commit.new.abm_level=4;connector.abm_level_property=NULL;assert(!msm_uke_abm_changed(&commit,&crtc));msm_uke_abm_commit(&commit);assert(!sends);cases++;
 assert(!qcom_uke_dsi_abm_register(&dsi,&context.panel,NULL));
 printf("PASS: native ABM %u actual-function cases; CABC, rollback, first-frame handoff, ownership, power and atomic filtering; synthetic only\n",cases);
}
