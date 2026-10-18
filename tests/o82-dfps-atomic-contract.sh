#!/usr/bin/env bash
# Execute actual MSM admission, flag masking and vblank completion guards.
set -Eeuo pipefail
source_file=${1:?Pass prepared msm_atomic.c}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
typedef uint64_t u64;
#define CONFIG_DRM_MSM_DSI 1
#define CONFIG_DRM_MSM_DPU 1
#define IS_ENABLED(v) (v)
#define hweight32(v) __builtin_popcount(v)
struct drm_display_mode {int value;};
struct drm_crtc_state {
    bool active,mode_changed,active_changed,connectors_changed,color_mgmt_changed;
    bool vrr_enabled;
    unsigned int encoder_mask;struct drm_display_mode adjusted_mode;
};
struct drm_crtc {unsigned int mask;u64 sequence;bool advance;};
struct drm_encoder {bool admitted,avr_active;};
struct drm_device {struct drm_crtc crtc[2];struct drm_encoder enc[2];};
struct drm_atomic_commit {struct drm_device *dev;struct drm_crtc_state old[2],new_state[2];};
#define for_each_oldnew_crtc_in_state(s,c,o,n,i) \
    for((i)=0;(i)<2&&(((c)=&(s)->dev->crtc[i]),((o)=&(s)->old[i]),((n)=&(s)->new_state[i]),1);++(i))
#define for_each_new_crtc_in_state(s,c,n,i) \
    for((i)=0;(i)<2&&(((c)=&(s)->dev->crtc[i]),((n)=&(s)->new_state[i]),1);++(i))
#define drm_for_each_encoder_mask(e,d,m) \
    for(unsigned int eidx=0;eidx<2;++eidx) \
        for(bool once=!!((m)&(1U<<eidx));once&&(((e)=&(d)->enc[eidx]),1);once=false)
#define for_each_crtc_mask(d,c,m) \
    for(unsigned int cidx=0;cidx<2;++cidx) \
        for(bool once=!!((m)&(1U<<cidx));once&&(((c)=&(d)->crtc[cidx]),1);once=false)
static unsigned int drm_crtc_mask(struct drm_crtc *c){return c->mask;}
static unsigned int admissions,completions,failures,errors;
static bool complete_error;
static bool dpu_encoder_uke_avr_active(struct drm_encoder *e){return e->avr_active;}
static bool msm_dsi_manager_uke_dfps_prepare(struct drm_encoder *e,
        const struct drm_display_mode *old,const struct drm_display_mode *next) {
    assert(old&&next);++admissions;return e->admitted;
}
static int msm_dsi_manager_uke_dfps_complete(void){++completions;return complete_error ? -1:0;}
static void msm_dsi_manager_uke_dfps_fail(void){++failures;}
static u64 drm_crtc_vblank_count(struct drm_crtc *c){return c->sequence;}
static void drm_crtc_wait_one_vblank(struct drm_crtc *c){if(c->advance)++c->sequence;}
#define drm_err(...) ((void)++errors)
C
for signature in 'static unsigned int msm_uke_dfps_prepare(' 'static void msm_uke_dfps_mask(' 'static void msm_uke_dfps_complete('; do
    awk -v signature="$signature" 'index($0,signature)==1 {emit=1;found=1} emit {print} emit&&/^}/ {exit} END {if(!found)exit 1}' "$source_file" >> "$work/check.c"
done
cat >> "$work/check.c" <<'C'
static void reset(struct drm_atomic_commit *s) {
    admissions=completions=failures=errors=0;complete_error=false;
    for(unsigned i=0;i<2;++i) {
        s->old[i]=(struct drm_crtc_state){.active=true,.encoder_mask=1U<<i};
        s->new_state[i]=s->old[i];s->new_state[i].mode_changed=true;
        s->dev->crtc[i]=(struct drm_crtc){.mask=1U<<i,.advance=true};
        s->dev->enc[i].admitted=true;
        s->dev->enc[i].avr_active=true;
    }
}
int main(void) {
    struct drm_device dev;struct drm_atomic_commit s={.dev=&dev};reset(&s);
    assert(msm_uke_dfps_prepare(&s)==3&&admissions==2);
    s.old[0].vrr_enabled=s.new_state[0].vrr_enabled=true;
    admissions=0;
    assert(msm_uke_dfps_prepare(&s)==3&&admissions==2); // Retain working AVR during exact timing update.
    s.new_state[0].vrr_enabled=false;admissions=0;
    assert(msm_uke_dfps_prepare(&s)==3&&admissions==2); // KWin's real modeset may disable AVR after an enabled test.
    s.dev->enc[0].avr_active=false;admissions=0;
    assert(msm_uke_dfps_prepare(&s)==2&&admissions==1); // A failed old AVR cannot enter either live transition.
    s.new_state[0].vrr_enabled=true;admissions=0;
    assert(msm_uke_dfps_prepare(&s)==2&&admissions==1);
    for(unsigned gate=0;gate<9;++gate) {
        reset(&s);
        switch(gate) {
        case 0:s.old[0].active=false;break;
        case 1:s.new_state[0].active=false;break;
        case 2:s.new_state[0].mode_changed=false;break;
        case 3:s.new_state[0].active_changed=true;break;
        case 4:s.new_state[0].connectors_changed=true;break;
        case 5:s.new_state[0].color_mgmt_changed=true;break;
        case 6:s.new_state[0].encoder_mask=2;break;
        case 7:s.old[0].encoder_mask=s.new_state[0].encoder_mask=3;break;
        case 8:s.new_state[0].vrr_enabled=true;break; // Simultaneous VRR entry still needs the ordinary modeset.
        }
        assert(msm_uke_dfps_prepare(&s)==2&&admissions==1);
    }
    reset(&s);dev.enc[0].admitted=false;
    assert(msm_uke_dfps_prepare(&s)==2&&admissions==2);
    // Only proven original mode_changed=true CRTC flags may be masked.
    reset(&s);s.new_state[1].mode_changed=false;
    msm_uke_dfps_mask(&s,1,true);assert(!s.new_state[0].mode_changed&&!s.new_state[1].mode_changed);
    msm_uke_dfps_mask(&s,1,false);assert(s.new_state[0].mode_changed&&!s.new_state[1].mode_changed);
    reset(&s);msm_uke_dfps_complete(&s,3);
    assert(completions==1&&!failures&&!errors&&dev.crtc[0].sequence==1&&dev.crtc[1].sequence==1);
    for(unsigned failure=0;failure<3;++failure) {
        reset(&s);
        if(failure<2)dev.crtc[failure].advance=false;else complete_error=true;
        msm_uke_dfps_complete(&s,3);
        assert(failures==1&&errors==1&&completions==(failure==2));
    }
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/check.c" -o "$work/check"
"$work/check"
printf 'Actual MSM DFPS: scoped admission, original flag preservation and real-vblank/fault completion guards passed\n'
