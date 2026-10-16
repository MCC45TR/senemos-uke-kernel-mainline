#!/usr/bin/env bash
# Execute actual video timing, lifecycle, IRQ and virtual kickoff functions on the host.
set -Eeuo pipefail
kernel=${1:?Pass the prepared native kernel source}
file=$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder_phys_vid.c
encoder=$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
extract() {
    awk -v signature="$2" '
        $0 == signature { emit=1; found=1 }
        emit { print }
        emit && /^}/ { exit }
        END { if (!found) exit 1 }
    ' "$1"
}
cat > "$work/check.cpp" <<'CPP'
#include <array>
#include <cassert>
#include <cerrno>
#include <cstdint>
#include <string>
#include <vector>
using u32=uint32_t; using u8=uint8_t;
enum role {ENC_ROLE_SOLO,ENC_ROLE_MASTER,ENC_ROLE_SLAVE};
CPP
{
sed -n '/^enum dpu_enc_enable_state {/,/^};/p' \
    "$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder_phys.h"
cat <<'CPP'
enum {INTR_IDX_VSYNC,INTR_IDX_UNDERRUN,INTF_0=0,CTL_0=0,KICKOFF_TIMEOUT_MS=84,
      CDM_CDWN_OUTPUT_HDMI=0};
struct dpu_mdss_version {int core_major_ver;};
struct dpu_mdss_cfg {const dpu_mdss_version *mdss_ver;};
static const dpu_mdss_version modern{10},legacy{4};
static const dpu_mdss_cfg dpu_sm7675_cfg{&modern},other_catalog{&modern},old_catalog{&legacy};
struct dpu_kms {const dpu_mdss_cfg *catalog;int base;};
struct drm_device {};
struct drm_encoder {drm_device *dev;};
struct dpu_hw_intf_status {bool is_en;};
struct dpu_hw_intf;
struct intf_ops {
    void (*enable_timing)(dpu_hw_intf *,u8);
    void (*get_status)(dpu_hw_intf *,dpu_hw_intf_status *);
};
struct dpu_hw_intf {int idx;intf_ops ops;bool enabled;};
struct dpu_hw_ctl;
struct ctl_ops {
    void (*update_pending_flush_intf)(dpu_hw_ctl *,int);
    void (*update_pending_flush_merge_3d)(dpu_hw_ctl *,int);
    void (*update_pending_flush_cdm)(dpu_hw_ctl *,int);
    void (*update_pending_flush_periph)(dpu_hw_ctl *,int);
    u32 (*get_flush_register)(dpu_hw_ctl *);
    u32 (*get_pending_flush)(dpu_hw_ctl *);
};
struct dpu_hw_ctl {int idx;ctl_ops ops;u32 pending,live;};
struct dpu_hw_merge_3d {int idx;};
struct dpu_hw_pingpong {dpu_hw_merge_3d *merge_3d;};
struct dpu_hw_cdm {int idx;};
struct dpu_encoder_phys;
struct physical_ops {bool (*needs_single_flush)(dpu_encoder_phys *);
    void (*handle_post_kickoff)(dpu_encoder_phys *);};
struct dpu_encoder_phys {
    role split_role; dpu_enc_enable_state enable_state; int *enc_spinlock;
    struct dpu_kms *dpu_kms;dpu_hw_intf *hw_intf;dpu_hw_ctl *hw_ctl;
    dpu_hw_pingpong *hw_pp;dpu_hw_cdm *hw_cdm;
    drm_encoder *parent;physical_ops ops;
    int pending_kickoff_cnt,pending_kickoff_wq,vblank_ctl_lock,vblank_refcount;
    unsigned int irq[2];int underrun_cnt;
};
struct dpu_encoder_virt {
    drm_encoder base;dpu_encoder_phys *phys_encs[2];unsigned int num_phys_encs;
    int enc_spinlock;unsigned long frame_busy_mask[1];dpu_encoder_phys *cur_master;
};
struct dpu_encoder_wait_info {int *wq,*atomic_cnt;unsigned int timeout_ms;};
struct msm_format {};
static int setup[3],cleanup[3],wait_calls,irq_registers,irq_unregisters;
static bool irq_timeout;
static std::vector<std::string> events;
#define WARN_ON(c) (c)
#define DPU_DEBUG_VIDENC(...) ((void)0)
#define DPU_ERROR(...) ((void)0)
#define DRM_DEBUG_VBL(...) ((void)0)
#define DRM_ERROR(...) ((void)0)
#define DPU_ERROR_VIDENC(...) ((void)0)
#define DRMID(...) 0
#define trace_dpu_enc_phys_vid_post_kickoff(...) ((void)0)
#define trace_dpu_enc_kickoff(...) ((void)0)
#define DPU_ATRACE_BEGIN(...) ((void)0)
#define DPU_ATRACE_END(...) ((void)0)
#define spin_lock_irqsave(lock,flags) do {(void)(lock);(flags)=0;}while(0)
#define spin_unlock_irqrestore(lock,flags) do {(void)(lock);(void)(flags);}while(0)
#define mutex_lock(lock) ((void)(lock))
#define mutex_unlock(lock) ((void)(lock))
#define atomic_set(counter,value) (*(counter)=(value))
#define wait_event_timeout(wq,condition,ms) ((void)(wq),(void)(ms),(condition)?1:0)
static unsigned int msecs_to_jiffies(unsigned int ms) {return ms;}
static void timing(dpu_hw_intf *intf,u8 enabled) {
    intf->enabled=enabled!=0;
    events.emplace_back("timer"+std::to_string(intf->idx)+"="+std::to_string(enabled));
}
static void status(dpu_hw_intf *intf,dpu_hw_intf_status *out) {out->is_en=intf->enabled;}
static void flush_mask(dpu_hw_ctl *ctl,int idx) {ctl->pending|=1U<<idx;}
static u32 get_live(dpu_hw_ctl *ctl) {return ctl->live;}
static u32 get_pending(dpu_hw_ctl *ctl) {return ctl->pending;}
static void dpu_encoder_phys_vid_setup_timing_engine(dpu_encoder_phys *p) {++setup[p->hw_intf->idx];}
static void dpu_encoder_helper_split_config(dpu_encoder_phys *,int) {}
static void dpu_encoder_helper_phys_setup_cdm(dpu_encoder_phys *,const msm_format *,int) {}
static u32 dpu_encoder_get_drm_fmt(dpu_encoder_phys *) {return 0;}
static const msm_format *mdp_get_format(int *,u32,int) {static msm_format fmt;return &fmt;}
static u32 dpu_encoder_helper_get_3d_blend_mode(dpu_encoder_phys *) {return 0;}
static bool dpu_encoder_needs_periph_flush(dpu_encoder_phys *) {return false;}
static int dpu_encoder_phys_inc_pending(dpu_encoder_phys *p) {return ++p->pending_kickoff_cnt;}
static int dpu_encoder_helper_wait_for_irq(dpu_encoder_phys *p,unsigned int,
                                         void (*)(void *),dpu_encoder_wait_info *info) {
    ++wait_calls;assert(info->atomic_cnt==&p->pending_kickoff_cnt);
    if(irq_timeout)return -ETIMEDOUT;
    *info->atomic_cnt=0;return 0;
}
static void dpu_encoder_helper_report_irq_timeout(dpu_encoder_phys *,int) {}
static void dpu_encoder_phys_vid_vblank_irq(void *) {}
static int dpu_core_irq_register_callback(dpu_kms *,unsigned int,void (*)(void *),void *) {
    ++irq_registers;return 0;
}
static int dpu_core_irq_unregister_callback(dpu_kms *,unsigned int) {++irq_unregisters;return 0;}
static void dpu_encoder_helper_phys_cleanup(dpu_encoder_phys *p) {++cleanup[p->hw_intf->idx];}
static void set_bit(unsigned int n,unsigned long *mask) {*mask|=1UL<<n;}
static void _dpu_encoder_trigger_flush(drm_encoder *,dpu_encoder_phys *p,u32 extra) {
    p->hw_ctl->pending|=extra;
    ++p->pending_kickoff_cnt;
    events.emplace_back("flush"+std::to_string(p->hw_intf->idx));
    p->hw_ctl->live=0; // bounded model of a hardware-accepted flush, not a hardware claim
}
static void _dpu_encoder_trigger_start(dpu_encoder_phys *p) {
    assert(p->split_role!=ENC_ROLE_SLAVE);
    events.emplace_back("start"+std::to_string(p->hw_intf->idx));
}
static dpu_encoder_virt *to_dpu_encoder_virt(drm_encoder *p) {
    return reinterpret_cast<dpu_encoder_virt *>(p);
}
CPP
} >> "$work/check.cpp"
{
    for signature in \
        'static bool dpu_encoder_phys_vid_is_master(' \
        'static bool dpu_encoder_phys_vid_needs_single_flush(' \
        'static int dpu_encoder_phys_vid_control_vblank_irq(' \
        'static void dpu_encoder_phys_vid_enable(struct dpu_encoder_phys *phys_enc)' \
        'static int dpu_encoder_phys_vid_wait_for_tx_complete(' \
        'static int dpu_encoder_phys_vid_wait_for_commit_done(' \
        'static void dpu_encoder_phys_vid_disable(struct dpu_encoder_phys *phys_enc)' \
        'static void dpu_encoder_phys_vid_handle_post_kickoff('; do
        extract "$file" "$signature"
    done
    extract "$encoder" 'static void _dpu_encoder_kickoff_phys(struct dpu_encoder_virt *dpu_enc)'
    extract "$encoder" 'void dpu_encoder_kickoff(struct drm_encoder *drm_enc)'
    cat <<'CPP'
int main() {
    for(const auto *catalog : {&dpu_sm7675_cfg,&other_catalog})
    for(const auto split : {ENC_ROLE_SOLO,ENC_ROLE_MASTER,ENC_ROLE_SLAVE})
    for(const auto initial : {DPU_ENC_DISABLING,DPU_ENC_DISABLED,DPU_ENC_ENABLING,
                             DPU_ENC_ENABLED,DPU_ENC_ERR_NEEDS_HW_RESET}) {
        dpu_kms kms{catalog,0};
        dpu_hw_intf intf{1,{timing,status},false};
        int lock=0;
        dpu_encoder_phys p{};
        p.split_role=split;p.enable_state=initial;p.enc_spinlock=&lock;
        p.dpu_kms=&kms;p.hw_intf=&intf;
        assert(dpu_encoder_phys_vid_is_master(&p)==(split!=ENC_ROLE_SLAVE));
        events.clear();
        const bool expected=initial==DPU_ENC_ENABLING &&
            (catalog!=&dpu_sm7675_cfg || split!=ENC_ROLE_SLAVE);
        dpu_encoder_phys_vid_handle_post_kickoff(&p);
        assert(events.size()==unsigned(expected) && intf.enabled==expected);
        assert(p.enable_state==(initial==DPU_ENC_ENABLING ? DPU_ENC_ENABLED:initial));
        dpu_encoder_phys_vid_handle_post_kickoff(&p);
        assert(events.size()==unsigned(expected));
        p.enable_state=DPU_ENC_ENABLING;events.clear();intf.enabled=false;
        dpu_encoder_phys_vid_handle_post_kickoff(&p);
        assert(p.enable_state==DPU_ENC_ENABLED);
        assert(intf.enabled==(catalog!=&dpu_sm7675_cfg || split!=ENC_ROLE_SLAVE));
    }
    for(const auto *catalog : {&dpu_sm7675_cfg,&other_catalog,&old_catalog}) {
        events.clear();wait_calls=irq_registers=irq_unregisters=0;irq_timeout=false;
        for(auto &v:setup)v=0;
        for(auto &v:cleanup)v=0;
        dpu_kms kms{catalog,0};drm_device device;
        dpu_hw_ctl ctl{0,{flush_mask,nullptr,nullptr,nullptr,get_live,get_pending},0,0};
        dpu_hw_intf intfs[2]{{1,{timing,status},false},{2,{timing,status},false}};
        dpu_hw_pingpong pp{};
        dpu_encoder_virt virt{{&device},{},2,0,{0},nullptr};
        dpu_encoder_phys p[2]{};
        for(int i=0;i<2;i++) {
            p[i].split_role=i ? ENC_ROLE_SLAVE:ENC_ROLE_MASTER;
            p[i].enable_state=DPU_ENC_DISABLED;p[i].enc_spinlock=&virt.enc_spinlock;
            p[i].dpu_kms=&kms;p[i].hw_intf=&intfs[i];p[i].hw_ctl=&ctl;p[i].hw_pp=&pp;
            p[i].parent=&virt.base;p[i].ops.needs_single_flush=dpu_encoder_phys_vid_needs_single_flush;
            p[i].ops.handle_post_kickoff=dpu_encoder_phys_vid_handle_post_kickoff;
            virt.phys_encs[i]=&p[i];
        }
        virt.cur_master=&p[0];
        assert(dpu_encoder_phys_vid_control_vblank_irq(&p[1],true)==0 && !p[1].vblank_refcount);
        assert(dpu_encoder_phys_vid_control_vblank_irq(&p[0],true)==0 && p[0].vblank_refcount==1);
        assert(irq_registers==1);
        assert(dpu_encoder_phys_vid_control_vblank_irq(&p[1],false)==0 && !irq_unregisters);
        for(int cycle=0;cycle<2;cycle++) {
            ctl.pending=0;events.clear();virt.frame_busy_mask[0]=0;
            // Actual virtual-enable caller orders slave setup before master setup.
            dpu_encoder_phys_vid_enable(&p[1]);dpu_encoder_phys_vid_enable(&p[0]);
            assert(setup[1]==cycle+1 && setup[2]==cycle+1);
            assert(p[0].enable_state==DPU_ENC_ENABLING && p[1].enable_state==DPU_ENC_ENABLING);
            assert(!intfs[0].enabled && !intfs[1].enabled);
            assert(ctl.pending==(catalog==&old_catalog ? 2U:6U));
            dpu_encoder_kickoff(&virt.base);
            auto expected_flush=catalog==&old_catalog ?
                std::vector<std::string>{"flush1","start1"}:
                std::vector<std::string>{"flush1","flush2","start1"};
            expected_flush.emplace_back("timer1=1");
            if(catalog!=&dpu_sm7675_cfg)expected_flush.emplace_back("timer2=1");
            assert(events==expected_flush && virt.frame_busy_mask[0]==1);
            assert(p[0].enable_state==DPU_ENC_ENABLED && p[1].enable_state==DPU_ENC_ENABLED);
            assert(intfs[0].enabled);
            assert(intfs[1].enabled==(catalog!=&dpu_sm7675_cfg));
            const auto count=events.size();
            dpu_encoder_phys_vid_handle_post_kickoff(&p[0]);
            dpu_encoder_phys_vid_handle_post_kickoff(&p[1]);
            assert(events.size()==count);
            // Slave TX wait has no vblank dependency, but its CTL commit wait is retained.
            const int before_wait=wait_calls;
            assert(dpu_encoder_phys_vid_wait_for_tx_complete(&p[1])==0 && wait_calls==before_wait);
            assert(dpu_encoder_phys_vid_wait_for_commit_done(&p[1])==0);
            ctl.live=1;
            assert(dpu_encoder_phys_vid_wait_for_commit_done(&p[1])==-ETIMEDOUT);
            ctl.live=0;
            assert(dpu_encoder_phys_vid_wait_for_tx_complete(&p[0])==0 && wait_calls==before_wait+1);
            dpu_encoder_phys_vid_disable(&p[0]);
            const int after_master=wait_calls;
            dpu_encoder_phys_vid_disable(&p[1]);
            assert(wait_calls==after_master && !intfs[0].enabled && !intfs[1].enabled);
            assert(cleanup[1]==cycle+1 && cleanup[2]==cycle+1);
            assert(p[0].enable_state==DPU_ENC_DISABLED && p[1].enable_state==DPU_ENC_DISABLED);
        }
        assert(dpu_encoder_phys_vid_control_vblank_irq(&p[0],false)==0 && !p[0].vblank_refcount);
        assert(irq_unregisters==1);
        if(catalog==&dpu_sm7675_cfg) {
            // The gate deliberately does not clear a previously inherited slave EN1.
            p[1].enable_state=DPU_ENC_ENABLING;intfs[1].enabled=true;
            const auto before=events.size();
            dpu_encoder_phys_vid_handle_post_kickoff(&p[1]);
            assert(p[1].enable_state==DPU_ENC_ENABLED && intfs[1].enabled && events.size()==before);
            dpu_encoder_phys_vid_disable(&p[1]);
            assert(!intfs[1].enabled && p[1].enable_state==DPU_ENC_DISABLED);
        }
        // Master disable IRQ timeout still cleans up and restores DISABLED, as upstream.
        dpu_encoder_phys_vid_enable(&p[0]);dpu_encoder_phys_vid_handle_post_kickoff(&p[0]);
        irq_timeout=true;dpu_encoder_phys_vid_disable(&p[0]);
        assert(p[0].enable_state==DPU_ENC_DISABLED && !intfs[0].enabled && !p[0].pending_kickoff_cnt);
    }
}
CPP
} >> "$work/check.cpp"
"${CXX:-c++}" -std=c++20 -O2 -Wall -Wextra -Werror \
    -fsanitize=undefined -fsanitize-undefined-trap-on-error \
    "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual video timing/lifecycle/IRQ and virtual kickoff: SOLO/MASTER/slave, five source enable states, both-flush, legacy path, re-enable, cleanup, inherited-EN1 limit and master timeout passed\n'
