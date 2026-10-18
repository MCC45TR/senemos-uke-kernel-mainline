#!/usr/bin/env bash
# Execute actual completion/timeout callbacks, including completion before arm.
set -Eeuo pipefail
encoder=${1:?Pass prepared kernel}/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
typedef uint32_t u32;
struct timer_list {bool pending;};
struct drm_encoder {void *dev;};
struct dpu_encoder_phys {int intf_mode;struct {int idx;} *hw_intf,*hw_wb;};
struct dpu_encoder_virt {
 struct drm_encoder base;struct timer_list frame_done_timer;
 unsigned long frame_busy_mask[1];unsigned num_phys_encs;
 struct dpu_encoder_phys *phys_encs[2];void *crtc;
 int frame_done_timeout_cnt;
};
#define to_dpu_encoder_virt(e) ((struct dpu_encoder_virt *)(e))
#define timer_container_of(v,t,member) ((struct dpu_encoder_virt *)((char *)(t)-offsetof(struct dpu_encoder_virt,member)))
#define DPU_ENCODER_FRAME_EVENT_DONE 1
#define DPU_ENCODER_FRAME_EVENT_ERROR 2
#define DPU_ENCODER_FRAME_EVENT_PANEL_DEAD 4
#define DPU_ENC_RC_EVENT_FRAME_DONE 1
#define DRMID(e) (0)
#define DRM_DEBUG_KMS(...) ((void)0)
static unsigned errors,timeouts,snapshots,events,done;
#define DPU_ERROR(...) (++errors)
#define DPU_ERROR_ENC_RATELIMITED(...) (++errors)
#define trace_dpu_enc_frame_done_timeout(...) (++timeouts)
#define trace_dpu_enc_frame_done_cb_not_busy(...) ((void)0)
#define trace_dpu_enc_frame_done_cb(...) ((void)0)
static void clear_bit(unsigned i,unsigned long *bits) {*bits&=~(1UL<<i);}
static void timer_delete(struct timer_list *t) {t->pending=false;}
static int atomic_inc_return(int *value) {return ++*value;}
static void msm_disp_snapshot_state(void *dev) {assert(dev);++snapshots;}
static void dpu_crtc_frame_event_cb(void *crtc,u32 event) {assert(crtc&&event);++events;}
static void dpu_encoder_resource_control(struct drm_encoder *enc,int event) {assert(enc&&event==DPU_ENC_RC_EVENT_FRAME_DONE);++done;}
C
for signature in 'void dpu_encoder_frame_done_callback(' 'static void dpu_encoder_frame_done_timeout('; do
 awk -v signature="$signature" 'index($0,signature)==1 {emit=1;found=1} emit {print} emit&&/^}/ {exit} END {if(!found)exit 1}' "$encoder" >> "$work/check.c"
done
cat >> "$work/check.c" <<'C'
static void expire(struct dpu_encoder_virt *e) {
 assert(e->frame_done_timer.pending);e->frame_done_timer.pending=false;
 dpu_encoder_frame_done_timeout(&e->frame_done_timer);
}
int main(void) {
 struct dpu_encoder_phys p[2]={0};
 struct dpu_encoder_virt e={.base={&e},.frame_busy_mask={1},.num_phys_encs=2,.phys_encs={&p[0],&p[1]},.crtc=&e};
 /* The real completion clears busy before the caller arms the timer. */
 dpu_encoder_frame_done_callback(&e.base,&p[0],DPU_ENCODER_FRAME_EVENT_DONE);
 assert(!e.frame_busy_mask[0]&&done==1&&events==1);
 e.frame_done_timer.pending=true;expire(&e);
 assert(!errors&&!timeouts&&!snapshots);
 /* An ordinary armed completion still cancels the pending timer. */
 e.frame_busy_mask[0]=1;e.frame_done_timer.pending=true;
 dpu_encoder_frame_done_callback(&e.base,&p[0],DPU_ENCODER_FRAME_EVENT_DONE);
 assert(!e.frame_done_timer.pending&&done==2&&events==2);
 /* A genuinely busy frame still reports and snapshots its first timeout. */
 e.frame_busy_mask[0]=1;e.frame_done_timer.pending=true;expire(&e);
 assert(errors==1&&timeouts==1&&snapshots==1&&events==3);
 e.frame_done_timer.pending=true;expire(&e);
 assert(errors==2&&timeouts==2&&snapshots==1&&events==4);
 /* Both physical completions are required before cancelling a busy pair. */
 e.frame_busy_mask[0]=3;e.frame_done_timer.pending=true;
 dpu_encoder_frame_done_callback(&e.base,&p[0],DPU_ENCODER_FRAME_EVENT_DONE);
 assert(e.frame_busy_mask[0]==2&&e.frame_done_timer.pending);
 dpu_encoder_frame_done_callback(&e.base,&p[1],DPU_ENCODER_FRAME_EVENT_DONE);
 assert(!e.frame_busy_mask[0]&&!e.frame_done_timer.pending&&done==3&&events==5);
 dpu_encoder_frame_done_callback(&e.base,&p[1],DPU_ENCODER_FRAME_EVENT_DONE);
 assert(events==5&&done==3);
 e.base.dev=NULL;e.frame_done_timer.pending=true;expire(&e);assert(errors==3);
 return 0;
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/check.c" -o "$work/check"
"$work/check"
printf '%s\n' 'Actual watchdog callbacks: completion-before-arm is idle; busy timeouts still report, snapshot and notify; bonded completion cancels once'
