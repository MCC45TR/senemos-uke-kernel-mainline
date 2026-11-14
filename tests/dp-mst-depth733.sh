#!/usr/bin/bash
# COPR only: actual MST/DPU callbacks; controlled DRM allocation/slot providers.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
mst=${MST_DEPTH_SOURCE:-$kernel/drivers/gpu/drm/msm/dp/dp_mst_drm.c}
utils=$kernel/drivers/gpu/drm/msm/dp/dp_utils.c
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
cat > "$work/test.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
typedef uint64_t u64; typedef uint32_t u32;
#define container_of(p,type,member) ((type *)((char *)(p)-offsetof(type,member)))
#define to_dp_mst_connector(p) container_of(p,struct msm_dp_mst_connector,connector)
#define to_mst_state(p) container_of(p,struct msm_dp_mst_connector_state,base)
#define DIV_ROUND_UP_ULL(n,d) (((n)+(d)-1)/(d))
#define round_down(n,d) ((n)/(d)*(d))
#define min3(a,b,c) ((a)<(b)?((a)<(c)?(a):(c)):((b)<(c)?(b):(c)))
#define max(a,b) ((a)>(b)?(a):(b))
#define IS_ERR(p) ((uintptr_t)(p)>=(uintptr_t)-4095)
#define PTR_ERR(p) ((int)(intptr_t)(p))
#define ERR_PTR(e) ((void *)(intptr_t)(e))
#define GFP_KERNEL 0
#define DP_MAX_PIXEL_CLK_KHZ 675000
struct drm_connector; struct drm_crtc; struct drm_atomic_commit;
struct drm_connector_funcs { unsigned identity; };
static const struct drm_connector_funcs msm_dp_drm_mst_connector_funcs={1},other_funcs={2};
struct drm_display_mode { int clock; bool y420; };
struct drm_display_info { unsigned bpc,max_tmds_clock; bool is_hdmi; };
struct drm_connector_state { struct drm_connector *connector; struct drm_crtc *crtc; unsigned max_requested_bpc,max_bpc; void *hdr_output_metadata; int colorspace; };
struct drm_connector { struct drm_connector_state *state; const struct drm_connector_funcs *funcs; struct drm_display_info display_info; };
struct drm_dp_mst_port { int full_pbn; };
struct msm_dp { bool mst_active; };
struct msm_dp_link_info { unsigned rate,num_lanes; };
struct msm_dp_link { struct msm_dp_link_info link_caps; };
struct drm_dp_mst_topology_mgr { int unused; };
struct drm_dp_mst_topology_state { struct {unsigned full;} pbn_div; };
struct msm_dp_mst { struct msm_dp *msm_dp; struct msm_dp_link *link; struct drm_dp_mst_topology_mgr mst_mgr; };
struct msm_dp_mst_connector { struct drm_connector connector; struct drm_dp_mst_port *mst_port; struct msm_dp_mst *dp_mst; };
struct msm_dp_mst_connector_state { struct drm_connector_state base; unsigned bpp; };
struct drm_crtc_state { struct drm_atomic_commit *state; struct drm_display_mode adjusted_mode; bool active,mode_changed,needs_modeset; };
struct drm_crtc { struct drm_crtc_state *next; };
struct drm_encoder { int unused; };
struct drm_atomic_commit { struct drm_connector_state *old,*next; struct drm_dp_mst_topology_state *topology; };
static unsigned allocations,frees,duplicates,destroys,slot_calls,releases,last_pbn;
static bool fail_alloc;static int slot_error,state_error;
static void *alloc(size_t n){if(fail_alloc)return NULL;void *p=calloc(1,n);assert(p);allocations++;return p;}
#define kzalloc_obj(object) alloc(sizeof(object))
static void *kmemdup(const void *p,size_t n,int flags){(void)flags;void *q=alloc(n);if(q)memcpy(q,p,n);return q;}
static void kfree(void *p){if(p){frees++;free(p);}}
static void __drm_atomic_helper_connector_reset(struct drm_connector *c,struct drm_connector_state *s){c->state=s;s->connector=c;}
static void __drm_atomic_helper_connector_duplicate_state(struct drm_connector *c,struct drm_connector_state *s){*s=*c->state;duplicates++;}
static void __drm_atomic_helper_connector_destroy_state(struct drm_connector_state *s){assert(s);destroys++;}
static bool drm_mode_is_420_only(const struct drm_display_info *i,const struct drm_display_mode *m){(void)i;return m->y420;}
static int drm_dp_calc_pbn_mode(int clock,int bpp){assert(clock>0 && (bpp==24*16||bpp==30*16));return (int)(((u64)clock*bpp+16*1000-1)/(16*1000));}
static struct drm_connector_state *drm_atomic_get_old_connector_state(struct drm_atomic_commit *s,struct drm_connector *c){(void)c;return s->old;}
static struct drm_connector_state *drm_atomic_get_new_connector_state(struct drm_atomic_commit *s,struct drm_connector *c){(void)c;return s->next;}
static struct drm_crtc_state *drm_atomic_get_crtc_state(struct drm_atomic_commit *s,struct drm_crtc *c){(void)s;return state_error?ERR_PTR(state_error):c->next;}
static int drm_dp_atomic_release_time_slots(struct drm_atomic_commit *s,struct drm_dp_mst_topology_mgr *m,struct drm_dp_mst_port *p){(void)s;(void)m;(void)p;releases++;return 0;}
static bool drm_atomic_crtc_needs_modeset(struct drm_crtc_state *s){return s->mode_changed||s->needs_modeset;}
static struct drm_dp_mst_topology_state *drm_atomic_get_mst_topology_state(struct drm_atomic_commit *s,struct drm_dp_mst_topology_mgr *m){(void)m;return state_error?ERR_PTR(state_error):s->topology;}
static typeof(((struct drm_dp_mst_topology_state *)0)->pbn_div) drm_dp_get_vc_payload_bw(unsigned rate,unsigned lanes){return (typeof(((struct drm_dp_mst_topology_state *)0)->pbn_div)){rate*lanes};}
static int drm_dp_atomic_find_time_slots(struct drm_atomic_commit *s,struct drm_dp_mst_topology_mgr *m,struct drm_dp_mst_port *p,int pbn){(void)s;(void)m;(void)p;slot_calls++;last_pbn=pbn;return slot_error?slot_error:10;}
C
extract() {
 awk -v name="$1" '
  $0~("^(static )?(unsigned int|int|u32|bool|void) "name"\\("){copy=1}
  copy{print} copy&&/^}/{exit}' "$2"
}
for name in msm_dp_utils_link_fits msm_dp_utils_tmds_fits msm_dp_utils_select_bpp;do extract "$name" "$utils" >> "$work/test.c";done
for name in msm_dp_mst_connector_destroy_state msm_dp_mst_connector_reset;do extract "$name" "$mst" >> "$work/test.c";done
awk '/^msm_dp_mst_connector_duplicate_state\(/ {print "static struct drm_connector_state *";copy=1}copy{print}copy&&/^}/{exit}' "$mst" >> "$work/test.c"
for name in msm_dp_mst_output_bpc msm_dp_mst_connector_atomic_check msm_dp_mst_select_bpp msm_dp_mst_stream_atomic_check;do extract "$name" "$mst" >> "$work/test.c";done
cat >> "$work/test.c" <<'C'
static bool uke_board=true;
enum {INTF_DP=1,DRM_FORMAT_YUV420=10,DRM_FORMAT_XRGB2101010=30,DRM_FORMAT_RGB888=24};
struct drm_device {void *dev_private;};
struct drm_encoder_full {struct drm_device *dev;};
struct msm_kms {struct msm_dp *dp[2];};
struct msm_drm_private {struct msm_kms *kms;};
struct dpu_encoder_virt {struct drm_encoder_full base;struct drm_connector *connector;struct {unsigned h_tile_instance[2];}disp_info;};
struct dpu_encoder_phys {struct drm_encoder_full *parent;struct drm_display_mode cached_mode;struct {struct {int type;}*cap;}*hw_intf;};
#define drm_encoder drm_encoder_full
#define to_dpu_encoder_virt(p) container_of(p,struct dpu_encoder_virt,base)
static bool of_machine_is_compatible(const char *s){assert(!strcmp(s,"xiaomi,uke"));return uke_board;}
static unsigned sst_bpc=8,sst_calls;
static unsigned msm_dp_output_bpc(const struct msm_dp *p,const struct drm_display_mode *m){(void)p;(void)m;sst_calls++;return sst_bpc;}
C
extract dpu_encoder_get_drm_fmt "$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c" >> "$work/test.c"
cat >> "$work/test.c" <<'C'
int main(void){
 struct msm_dp dp={.mst_active=true},other={.mst_active=true};
 struct msm_dp_link link={.link_caps={540000,4}};
 struct msm_dp_mst mst={.msm_dp=&dp,.link=&link};struct drm_dp_mst_port port={.full_pbn=30000};
 struct msm_dp_mst_connector conn={.connector={.funcs=&msm_dp_drm_mst_connector_funcs,.display_info={.bpc=10}},.mst_port=&port,.dp_mst=&mst};
 msm_dp_mst_connector_reset(&conn.connector);assert(conn.connector.state&&to_mst_state(conn.connector.state)->bpp==24);
 struct drm_connector_state *cs=conn.connector.state;cs->max_requested_bpc=10;
 struct drm_display_mode mode={.clock=301850};
 assert(msm_dp_mst_select_bpp(cs,&mode,&link.link_caps,30000)==30);
 assert(msm_dp_mst_select_bpp(cs,&mode,&link.link_caps,8000)==24);
 assert(msm_dp_mst_select_bpp(cs,&mode,&link.link_caps,7000)==-ENOSPC);
 cs->max_requested_bpc=8;assert(msm_dp_mst_select_bpp(cs,&mode,&link.link_caps,30000)==24);
 cs->max_requested_bpc=0;assert(msm_dp_mst_select_bpp(cs,&mode,&link.link_caps,30000)==24);
 cs->max_requested_bpc=10;link.link_caps.num_lanes=2;assert(msm_dp_mst_select_bpp(cs,&mode,&link.link_caps,30000)==24);
 link.link_caps.num_lanes=4;conn.connector.display_info.bpc=8;assert(msm_dp_mst_select_bpp(cs,&mode,&link.link_caps,30000)==24);
 conn.connector.display_info.bpc=0;assert(msm_dp_mst_select_bpp(cs,&mode,&link.link_caps,30000)==24);
 conn.connector.display_info.bpc=10;conn.connector.display_info.is_hdmi=true;conn.connector.display_info.max_tmds_clock=320000;
 assert(msm_dp_mst_select_bpp(cs,&mode,&link.link_caps,30000)==24);
 conn.connector.display_info.is_hdmi=false;
 for(unsigned n=0;n<3;n++){cs->hdr_output_metadata=n==0?&dp:NULL;cs->colorspace=n==1;mode.y420=n==2;assert(msm_dp_mst_select_bpp(cs,&mode,&link.link_caps,30000)==-EOPNOTSUPP);}
 cs->hdr_output_metadata=NULL;cs->colorspace=0;mode.y420=false;
 for(int clock=-1;clock<=0;clock++){mode.clock=clock;assert(msm_dp_mst_select_bpp(cs,&mode,&link.link_caps,30000)==-EINVAL);}
 mode.clock=675001;assert(msm_dp_mst_select_bpp(cs,&mode,&link.link_caps,30000)==-EINVAL);mode.clock=301850;
 assert(msm_dp_mst_select_bpp(cs,&mode,&link.link_caps,0)==-EINVAL);
 struct drm_dp_mst_topology_state topo={0};struct drm_atomic_commit commit={.next=cs,.topology=&topo};
 struct drm_crtc_state crtc_state={.state=&commit,.active=true,.needs_modeset=true,.adjusted_mode=mode};
 struct drm_crtc crtc={.next=&crtc_state};cs->crtc=&crtc;
 assert(!msm_dp_mst_stream_atomic_check(NULL,&crtc_state,cs));
 assert(to_mst_state(cs)->bpp==30&&last_pbn==9056&&slot_calls==1);
 assert(msm_dp_mst_output_bpc(&dp,&conn.connector)==10);
 assert(!msm_dp_mst_output_bpc(&other,&conn.connector));
 conn.connector.funcs=&other_funcs;assert(!msm_dp_mst_output_bpc(&dp,&conn.connector));conn.connector.funcs=&msm_dp_drm_mst_connector_funcs;
 dp.mst_active=false;assert(!msm_dp_mst_output_bpc(&dp,&conn.connector));dp.mst_active=true;
 struct drm_connector_state *duplicate=msm_dp_mst_connector_duplicate_state(&conn.connector);
 assert(duplicate&&duplicate!=cs&&to_mst_state(duplicate)->bpp==30&&duplicates==1);
 to_mst_state(duplicate)->bpp=24;assert(to_mst_state(cs)->bpp==30);
 struct msm_dp_mst_connector peer={.connector={.funcs=&msm_dp_drm_mst_connector_funcs},.dp_mst=&mst};
 peer.connector.state=duplicate;assert(msm_dp_mst_output_bpc(&dp,&peer.connector)==8);
 slot_error=-ENOSPC;cs->max_requested_bpc=8;
 assert(msm_dp_mst_stream_atomic_check(NULL,&crtc_state,cs)==-ENOSPC&&to_mst_state(cs)->bpp==30);slot_error=0;
 state_error=-EDEADLK;assert(msm_dp_mst_stream_atomic_check(NULL,&crtc_state,cs)==-EDEADLK&&to_mst_state(cs)->bpp==30);state_error=0;
 struct drm_connector_state old=*cs;old.max_requested_bpc=10;commit.old=&old;
 crtc_state.mode_changed=false;assert(!msm_dp_mst_connector_atomic_check(&conn.connector,&commit)&&crtc_state.mode_changed&&releases==1);
 state_error=-EDEADLK;assert(msm_dp_mst_connector_atomic_check(&conn.connector,&commit)==-EDEADLK&&releases==1);state_error=0;
 struct msm_kms kms={.dp={&dp}};struct msm_drm_private priv={.kms=&kms};struct drm_device dev={.dev_private=&priv};
 struct dpu_encoder_virt enc={.base={.dev=&dev},.connector=&conn.connector};
 typeof(*((struct dpu_encoder_phys*)0)->hw_intf->cap) cap={.type=INTF_DP};
 typeof(*((struct dpu_encoder_phys*)0)->hw_intf) intf={.cap=&cap};
 struct dpu_encoder_phys phys={.parent=&enc.base,.cached_mode=mode,.hw_intf=&intf};
 assert(dpu_encoder_get_drm_fmt(&phys)==DRM_FORMAT_XRGB2101010&&!sst_calls);
 enc.connector=&peer.connector;assert(dpu_encoder_get_drm_fmt(&phys)==DRM_FORMAT_RGB888&&!sst_calls);
 enc.connector=&conn.connector;dp.mst_active=false;sst_bpc=10;assert(dpu_encoder_get_drm_fmt(&phys)==DRM_FORMAT_XRGB2101010&&sst_calls==1);
 sst_bpc=8;assert(dpu_encoder_get_drm_fmt(&phys)==DRM_FORMAT_RGB888&&sst_calls==2);
 phys.cached_mode.y420=true;assert(dpu_encoder_get_drm_fmt(&phys)==DRM_FORMAT_YUV420&&sst_calls==2);phys.cached_mode.y420=false;
 uke_board=false;assert(dpu_encoder_get_drm_fmt(&phys)==DRM_FORMAT_RGB888&&sst_calls==2);uke_board=true;
 fail_alloc=true;assert(!msm_dp_mst_connector_duplicate_state(&conn.connector));fail_alloc=false;
 msm_dp_mst_connector_destroy_state(&peer.connector,duplicate);peer.connector.state=NULL;
 fail_alloc=true;msm_dp_mst_connector_reset(&conn.connector);assert(!conn.connector.state);fail_alloc=false;
 assert(allocations==frees&&destroys==frees);
 puts("Actual MST stream depth: sink/route/TMDS/port admission, atomic PBN/deadlock/slot refusal, state lifetime and two-connector DPU packing passed; controlled DRM providers, no physical MST.");
}
C
flags=(-O2)
[[ ${SANITIZE:-0} == 0 ]] || flags=(-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
"${CC:-gcc}" -std=gnu11 -Wall -Wextra -Werror -Wno-unused-parameter "${flags[@]}" "$work/test.c" -o "$work/test"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/test"
