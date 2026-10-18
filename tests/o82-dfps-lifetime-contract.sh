#!/usr/bin/env bash
# Execute the production quarantine label and bridge-reference exit paths.
set -Eeuo pipefail
atomic=${1:?Pass prepared msm_atomic.c}
manager=${2:?Pass prepared dsi_manager.c}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#define EOPNOTSUPP 95
struct drm_display_mode { int unused; };
struct drm_panel { bool prepared; };
struct drm_bridge { const void *funcs; int refs; };
struct dsi_bridge { struct drm_bridge base; int id; struct drm_panel *o82_panel; bool powered,video_enabled; };
struct drm_encoder { struct drm_bridge *bridge; };
struct msm_dsi { int *host; };
struct qcom_uke_o82_dfps_ops {
    bool (*check)(struct drm_panel *,const struct drm_display_mode *,const struct drm_display_mode *);
    int (*apply)(struct drm_panel *,const struct drm_display_mode *,const struct drm_display_mode *,bool);
};
static struct { struct drm_panel *uke_dfps_panel; const struct qcom_uke_o82_dfps_ops *uke_dfps_ops; } msm_dsim_glb;
static int dsi_mgr_bridge_funcs,foreign_funcs,uke_dfps_panel_lock;
static bool bonded,synced,failed,live,check_ok,missing_master,missing_slave;
static int host[2],queue_error,queued,cancelled,applied;
static struct msm_dsi links[2]={{&host[0]},{&host[1]}};
#define IS_BONDED_DSI() bonded
#define IS_SYNC_NEEDED() synced
#define IS_MASTER_DSI_LINK(id) ((id)==0)
static struct drm_bridge *drm_bridge_chain_get_first_bridge(struct drm_encoder *e) {
    if(e->bridge)++e->bridge->refs;
    return e->bridge;
}
static void drm_bridge_put(struct drm_bridge *b) { if(b){assert(b->refs>0);--b->refs;} }
static struct dsi_bridge *to_dsi_bridge(struct drm_bridge *b) { return (struct dsi_bridge *)b; }
static void mutex_lock(int *m) { assert(!*m);*m=1; }
static void mutex_unlock(int *m) { assert(*m);*m=0; }
static bool msm_dsi_manager_uke_dfps_failed(void) { return failed; }
static bool qcom_uke_o82_live_change(const struct drm_display_mode *a,const struct drm_display_mode *b) {
    assert(a&&b);return live;
}
static struct msm_dsi *dsi_mgr_get_dsi(int id) { assert(id==0);return missing_master?NULL:&links[0]; }
static struct msm_dsi *dsi_mgr_get_other_dsi(int id) { assert(id==0);return missing_slave?NULL:&links[1]; }
static bool msm_dsi_host_uke_dfps_pending(int *h) { assert(h==&host[0]||h==&host[1]);return true; }
static int msm_dsi_host_uke_dfps_queue(int *h,const struct drm_display_mode *a,const struct drm_display_mode *b) {
    assert(a&&b);++queued;return queue_error==(h==&host[0]?1:2)?-1:0;
}
static void msm_dsi_host_uke_dfps_cancel(int *h) { assert(h==&host[0]);++cancelled; }
static bool check(struct drm_panel *p,const struct drm_display_mode *a,const struct drm_display_mode *b) {
    assert(p&&a&&b&&uke_dfps_panel_lock);return check_ok;
}
static int apply(struct drm_panel *p,const struct drm_display_mode *a,const struct drm_display_mode *b,bool before) {
    assert(p&&a&&b&&uke_dfps_panel_lock);(void)before;++applied;return 0;
}
C
{
for signature in 'int msm_dsi_manager_uke_dfps_panel(' 'bool msm_dsi_manager_uke_dfps_pending(' 'bool msm_dsi_manager_uke_dfps_prepare('; do
    awk -v signature="$signature" 'index($0,signature)==1 {emit=1;found=1} emit {print} emit&&/^}/ {exit} END {if(!found)exit 1}' "$manager"
done
cat <<'C'
struct msm_kms;
struct kms_funcs { void (*disable_commit)(struct msm_kms *); };
struct msm_kms { struct kms_funcs *funcs; };
struct drm_device { int unused; };
struct drm_atomic_commit { unsigned refs,old_pins,new_pins,old_fb_refs,hw_done; };
static unsigned unlocked,disabled,cleanups,traced;
static void unlock_crtcs(struct msm_kms *k,unsigned mask) { assert(k&&mask==1);++unlocked; }
static void disable_commit(struct msm_kms *k) { assert(k);++disabled; }
static void drm_atomic_helper_commit_hw_done(struct drm_atomic_commit *s) { ++s->hw_done; }
static void drm_atomic_helper_cleanup_planes(struct drm_device *d,struct drm_atomic_commit *s) {
    (void)d;++cleanups;--s->old_pins;
}
static struct drm_atomic_commit *drm_atomic_commit_get(struct drm_atomic_commit *s) { ++s->refs;return s; }
static void drm_atomic_commit_put(struct drm_atomic_commit *s) {
    assert(s->refs);if(!--s->refs)--s->old_fb_refs;
}
#define trace_msm_atomic_commit_tail_finish(a,m) ((void)(a),(void)(m),++traced)
static void quarantined_tail(struct drm_atomic_commit *state) {
    struct kms_funcs funcs={disable_commit};struct msm_kms k={&funcs},*kms=&k;
    struct drm_device device,*dev=&device;unsigned crtc_mask=1;bool async=false;
    (void)dev;
    goto quarantined;
C
awk '/^quarantined:/ {emit=1;found=1} emit {print} emit&&/^}/ {exit} END {if(!found)exit 1}' "$atomic"
cat <<'C'
int main(void) {
    struct drm_display_mode old={0},next={0};struct drm_panel panel;
    struct qcom_uke_o82_dfps_ops ops={check,apply};
    struct dsi_bridge b;struct drm_encoder e;
    for(unsigned gate=0;gate<19;++gate) {
        b=(struct dsi_bridge){.base={.funcs=&dsi_mgr_bridge_funcs},.id=0,.o82_panel=&panel,.powered=true,.video_enabled=true};
        e.bridge=&b.base;panel.prepared=true;msm_dsim_glb.uke_dfps_panel=&panel;msm_dsim_glb.uke_dfps_ops=&ops;
        bonded=synced=live=check_ok=true;failed=missing_master=missing_slave=false;
        queue_error=queued=cancelled=applied=0;
        switch(gate) {
        case 1:e.bridge=NULL;break;case 2:b.base.funcs=&foreign_funcs;break;
        case 3:bonded=false;break;case 4:synced=false;break;case 5:failed=true;break;
        case 6:b.id=1;break;case 7:b.o82_panel=NULL;break;case 8:panel.prepared=false;break;
        case 9:b.powered=false;break;case 10:b.video_enabled=false;break;
        case 11:msm_dsim_glb.uke_dfps_panel=NULL;break;case 12:msm_dsim_glb.uke_dfps_ops=NULL;break;
        case 13:check_ok=false;break;case 14:missing_master=true;break;case 15:missing_slave=true;break;
        case 16:queue_error=1;break;case 17:queue_error=2;break;case 18:live=false;break;
        }
        bool prepared=msm_dsi_manager_uke_dfps_prepare(&e,&old,&next);
        assert(prepared==(gate==0)&&b.base.refs==0&&!uke_dfps_panel_lock);
        assert(cancelled==(gate==17));
        (void)msm_dsi_manager_uke_dfps_pending(&e);
        assert(b.base.refs==0&&!uke_dfps_panel_lock);
        (void)msm_dsi_manager_uke_dfps_panel(&e,&old,&next,false);
        assert(b.base.refs==0&&!uke_dfps_panel_lock);
    }
    /* Both an immediate failure and already-swapped queued commits retain pins. */
    for(unsigned i=0;i<3;++i) {
        struct drm_atomic_commit state={.refs=1,.old_pins=1,.new_pins=1,.old_fb_refs=1};
        quarantined_tail(&state);
        assert(state.refs==2&&state.hw_done==1&&state.old_pins==1&&state.new_pins==1);
        drm_atomic_commit_put(&state);
        assert(state.refs==1&&state.old_fb_refs==1&&state.old_pins==1&&state.new_pins==1);
    }
    assert(unlocked==3&&disabled==3&&traced==3&&!cleanups);
    (void)drm_atomic_helper_cleanup_planes;
    (void)drm_atomic_commit_get;
    (void)drm_bridge_put;
}
C
} >> "$work/check.c"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/check.c" -o "$work/check"
"$work/check"
printf 'Actual DFPS quarantine retains scanout pins; all 19 bridge exit gates balance references\n'
