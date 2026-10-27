#!/usr/bin/env bash
# Real MST DSC atomic selection and shared decoder/passthrough lifetime; no AUX hardware.
set -Eeuo pipefail
ulimit -c 0
source=${1:?Pass prepared dp_mst_drm.c}
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$root/build"
work=$(mktemp -d "$root/build/mst-dsc-fixture.XXXXXX")
trap 'rm -r -- "$work"' EXIT
{
cat <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
typedef uint8_t u8;typedef uint32_t u32;typedef uint64_t u64;
#define BIT(n) (1U<<(n))
#define DP_DSC_RECEIVER_CAP_SIZE 16
#define DP_DSC_ENABLE 0x160
#define DP_DECOMPRESSION_EN 1
#define DP_DSC_PASSTHROUGH_EN 2
#define DIV_ROUND_UP_ULL(n,d) (((n)+(d)-1)/(d))
#define max(a,b) ((a)>(b)?(a):(b))
#define min(a,b) ((a)<(b)?(a):(b))
#define min3(a,b,c) min(min(a,b),c)
#define round_down(a,b) ((a)/(b)*(b))
#define dfixed_const(n) ((n)<<12)
#define IS_ERR(p) ((uintptr_t)(p)>(uintptr_t)-4096)
#define PTR_ERR(p) ((int)(intptr_t)(p))
#define DRM_DP_BW_OVERHEAD_DSC 1
#define DRM_DP_BW_OVERHEAD_FEC 2
#define DRM_DP_BW_OVERHEAD_MST 4
struct drm_dp_aux {u8 value;unsigned reads,writes;int fail_read,fail_write;};
struct drm_display_mode {int clock,hdisplay;bool only420;};
struct drm_display_info {unsigned bpc,max_tmds_clock;bool is_hdmi;};
struct drm_connector_state;
struct drm_connector {const void *funcs;struct drm_display_info display_info;struct drm_connector_state *state;};
struct drm_connector_state {struct drm_connector *connector;void *crtc,*hdr_output_metadata;unsigned colorspace,max_requested_bpc;};
struct drm_dsc_config {unsigned bits_per_pixel,slice_count;};
struct msm_dp_dsc_config {struct drm_dsc_config dsc;};
struct msm_dp_bridge_state {unsigned bpp;struct msm_dp_dsc_config dsc;};
struct msm_dp_mst_connector_state {struct drm_connector_state base;struct msm_dp_bridge_state color;};
struct fixed20_12 {unsigned full;};
struct drm_dp_mst_topology_state {struct fixed20_12 pbn_div;};
struct drm_atomic_commit {struct drm_dp_mst_topology_state topology;};
struct drm_crtc_state {struct drm_atomic_commit *state;bool active,modeset;struct drm_display_mode mode;};
struct drm_encoder {void *dev;};
struct drm_dp_mst_port {unsigned full_pbn,pbn,slots;bool dsc;};
struct msm_dp_panel {struct msm_dp_dsc_config dsc;bool dsc_active;struct drm_dp_aux *dsc_aux,*passthrough_aux;};
struct msm_dp_mst_encoder {struct msm_dp_panel *dp_panel;};
struct msm_dp_link {struct {unsigned rate,num_lanes;} link_caps;};
struct msm_dp {bool requested;u8 fec;};
struct msm_dp_mst {struct msm_dp_mst_encoder mst_encoders[2];unsigned max_streams;struct msm_dp *msm_dp;struct msm_dp_link *link;int mst_mgr;};
struct msm_dp_mst_connector {struct drm_connector connector;struct drm_dp_mst_port *mst_port;struct msm_dp_mst *dp_mst;struct drm_dp_aux *dsc_aux;u8 dsc_caps[16];};
struct drm_connector_list_iter {unsigned index;};
static struct msm_dp_mst_connector *peers[2];
static const int msm_dp_drm_mst_connector_funcs;
#define to_dp_mst_connector(p) ((struct msm_dp_mst_connector*)(p))
#define to_mst_state(p) ((struct msm_dp_mst_connector_state*)(p))
#define drm_for_each_connector_iter(p,it) for((it)->index=0;(it)->index<2&&((p)=&peers[(it)->index]->connector);(it)->index++)
static void drm_connector_list_iter_begin(void *dev,struct drm_connector_list_iter *it) {(void)dev;it->index=0;}
static void drm_connector_list_iter_end(struct drm_connector_list_iter *it) {(void)it;}
static struct drm_connector_state *drm_atomic_get_new_connector_state(struct drm_atomic_commit *s,struct drm_connector *c) {(void)s;return c->state;}
static bool drm_atomic_crtc_needs_modeset(struct drm_crtc_state *s) {return s->modeset;}
static bool drm_mode_is_420_only(const struct drm_display_info *i,const struct drm_display_mode *m) {(void)i;return m->only420;}
static bool msm_dp_display_dsc_requested(struct msm_dp *dp,u8 *fec) {*fec=dp->fec;return dp->requested;}
static int msm_dp_dsc_prepare_bpp(const u8 *caps,u8 fec,const struct drm_display_mode *m,unsigned bpc,unsigned rate,unsigned lanes,unsigned max_wire,struct msm_dp_dsc_config *out) {
 (void)m;(void)rate;(void)lanes;memset(out,0,sizeof(*out));if(!fec||!caps[0])return -EOPNOTSUPP;
 const unsigned rates[]={15,12,10,8};
 for(unsigned i=0;i<4;i++)if(rates[i]*16<=max_wire&&(bpc==10?rates[i]!=12:rates[i]==12||rates[i]==8)) {
  out->dsc.bits_per_pixel=rates[i]*16;out->dsc.slice_count=1;return 0;
 }
 return -ENOSPC;
}
static int drm_dp_calc_pbn_mode(int clock,int bpp) {return DIV_ROUND_UP_ULL((u64)clock*bpp,108000);}
static unsigned drm_dp_bw_overhead(unsigned lanes,int width,unsigned slices,unsigned bpp,unsigned flags) {
 assert(lanes&&width&&slices&&bpp&&flags);return 1030000;
}
static struct fixed20_12 drm_dp_get_vc_payload_bw(unsigned rate,unsigned lanes) {return (struct fixed20_12){(u64)rate*lanes*4096/54000};}
static bool msm_dp_utils_tmds_fits(unsigned clock,unsigned bpp,unsigned limit,bool yuv) {(void)yuv;return !limit||(u64)clock*bpp<=(u64)limit*24;}
static struct drm_dp_mst_topology_state *drm_atomic_get_mst_topology_state(struct drm_atomic_commit *s,int *mgr) {(void)mgr;return &s->topology;}
static int allocation_fault;
static int drm_dp_atomic_find_time_slots(struct drm_atomic_commit *s,int *mgr,struct drm_dp_mst_port *p,int pbn) {
 (void)mgr;if(allocation_fault)return -ENOMEM;p->pbn=pbn;p->slots=DIV_ROUND_UP_ULL((u64)pbn<<12,s->topology.pbn_div.full);return p->slots;
}
static int drm_dp_mst_atomic_enable_dsc(struct drm_atomic_commit *s,struct drm_dp_mst_port *p,int pbn,bool enable) {(void)s;assert(pbn==(int)p->pbn);p->dsc=enable;return p->slots;}
static int drm_dp_dpcd_read_byte(struct drm_dp_aux *a,unsigned reg,u8 *v) {assert(reg==DP_DSC_ENABLE);if(++a->reads==(unsigned)a->fail_read)return -EIO;*v=a->value;return 0;}
static int drm_dp_dpcd_write_byte(struct drm_dp_aux *a,unsigned reg,u8 v) {assert(reg==DP_DSC_ENABLE);if(++a->writes==(unsigned)a->fail_write)return -EIO;a->value=v;return 0;}
C
for name in msm_dp_mst_dsc_flag msm_dp_mst_set_dsc msm_dp_mst_stream_atomic_check; do
    awk -v name="$name" '$0 ~ "^(static )?int " name "\\(" {emit=1;found=1} emit{print} emit&&/^}/{exit} END{if(!found)exit 1}' "$source"
done
cat <<'C'
int main(void) {
 struct drm_dp_aux decoder={.value=0x80},pass={.value=0x40};
 struct msm_dp_panel panels[2]={0};struct msm_dp dp={true,1};struct msm_dp_link link={.link_caps={540000,2}};
 struct msm_dp_mst mst={.mst_encoders={{&panels[0]},{&panels[1]}},.max_streams=2,.msm_dp=&dp,.link=&link};
 for(unsigned i=0;i<2;i++) {panels[i].dsc.dsc.bits_per_pixel=128;panels[i].dsc_aux=&decoder;panels[i].passthrough_aux=&pass;}
 assert(!msm_dp_mst_set_dsc(&mst,&panels[0],true)&&panels[0].dsc_active&&decoder.value==0x81&&pass.value==0x42);
 unsigned writes=decoder.writes+pass.writes;
 assert(!msm_dp_mst_set_dsc(&mst,&panels[1],true)&&panels[1].dsc_active&&decoder.writes+pass.writes==writes);
 assert(!msm_dp_mst_set_dsc(&mst,&panels[0],false)&&!panels[0].dsc_active&&decoder.value==0x81&&pass.value==0x42);
 assert(!msm_dp_mst_set_dsc(&mst,&panels[1],false)&&!panels[1].dsc_active&&decoder.value==0x80&&pass.value==0x40);
 for(unsigned fault=0;fault<4;fault++) {
  decoder=(struct drm_dp_aux){.value=0x80};pass=(struct drm_dp_aux){.value=0x40};
  if(fault==0)decoder.fail_read=1;if(fault==1)decoder.fail_write=1;
  if(fault==2)pass.fail_read=1;if(fault==3)pass.fail_write=1;
  assert(msm_dp_mst_set_dsc(&mst,&panels[0],true)<0&&!panels[0].dsc_active);
  assert(decoder.value==0x80&&pass.value==0x40);
 }
 struct drm_dp_mst_port ports[2]={{.full_pbn=1280},{.full_pbn=1280}};
 struct msm_dp_mst_connector conn[2]={0};struct msm_dp_mst_connector_state states[2]={0};
 struct drm_atomic_commit commit={0};struct drm_encoder encoder={0};
 struct drm_crtc_state crtc={.state=&commit,.active=true,.modeset=true,.mode={299890,2560,false}};
 for(unsigned i=0;i<2;i++) {
  peers[i]=&conn[i];conn[i].connector.funcs=&msm_dp_drm_mst_connector_funcs;
  conn[i].connector.display_info.bpc=10;conn[i].connector.state=&states[i].base;
  conn[i].mst_port=&ports[i];conn[i].dp_mst=&mst;conn[i].dsc_aux=&decoder;conn[i].dsc_caps[0]=1;
  states[i].base.connector=&conn[i].connector;states[i].base.crtc=&crtc;states[i].base.max_requested_bpc=10;
 }
 for(unsigned order=0;order<2;order++)for(unsigned j=0;j<2;j++) {
  unsigned i=j^order;
  assert(!msm_dp_mst_stream_atomic_check(&encoder,&crtc,&states[i].base));
  assert(states[i].color.bpp==30&&states[i].color.dsc.dsc.bits_per_pixel==160&&ports[i].dsc&&ports[i].slots<=31);
 }
 assert(ports[0].slots+ports[1].slots<=63);
 states[1].base.crtc=NULL;
 assert(!msm_dp_mst_stream_atomic_check(&encoder,&crtc,&states[0].base)&&states[0].color.dsc.dsc.bits_per_pixel==240);
 ports[0].full_pbn=1;assert(msm_dp_mst_stream_atomic_check(&encoder,&crtc,&states[0].base)==-ENOSPC);ports[0].full_pbn=1280;
 dp.fec=0;assert(msm_dp_mst_stream_atomic_check(&encoder,&crtc,&states[0].base)==-ENOSPC);dp.fec=1;
 allocation_fault=1;assert(msm_dp_mst_stream_atomic_check(&encoder,&crtc,&states[0].base)==-ENOMEM);allocation_fault=0;
 states[0].base.hdr_output_metadata=&commit;
 assert(msm_dp_mst_stream_atomic_check(&encoder,&crtc,&states[0].base)==-EOPNOTSUPP);states[0].base.hdr_output_metadata=NULL;
 conn[0].dsc_aux=NULL;dp.requested=false;
 states[0].base.max_requested_bpc=6;
 assert(msm_dp_mst_stream_atomic_check(&encoder,&crtc,&states[0].base)==-EINVAL);
 states[0].base.max_requested_bpc=8;
 assert(!msm_dp_mst_stream_atomic_check(&encoder,&crtc,&states[0].base)&&!ports[0].dsc&&states[0].color.bpp==24);
 crtc.modeset=false;states[0].color.bpp=30;
 assert(!msm_dp_mst_stream_atomic_check(&encoder,&crtc,&states[0].base)&&states[0].color.bpp==30);
 puts("Production MST DSC: atomic per-stream state, fair slot/rate selection, refusal/allocation errors, shared AUX references and fault rollback: PASS; host only.");
}
C
} > "$work/test.c"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-sign-compare -Wno-misleading-indentation -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/test.c" -o "$work/test"
"$work/test"
