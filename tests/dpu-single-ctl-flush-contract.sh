#!/usr/bin/env bash
# Exercise actual kickoff, counter updates and modern CTL MMIO writers.
set -Eeuo pipefail
kernel=${1:?Pass the prepared native kernel source}
dpu=$kernel/drivers/gpu/drm/msm/disp/dpu1
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
#include <climits>
#include <cstdint>
#include <string>
#include <tuple>
#include <vector>
using u32=uint32_t;
#define BIT(n) (1U<<(n))
enum role {ENC_ROLE_SOLO,ENC_ROLE_MASTER,ENC_ROLE_SLAVE};
enum {DRM_MODE_ENCODER_DSI=6,DRM_MODE_ENCODER_VIRTUAL=5};
CPP
{
    for type in dpu_intf dpu_intf_type dpu_intf_mode dpu_dspp dpu_dsc; do
        sed -n "/^enum $type {/,/^};/p" "$dpu/dpu_hw_mdss.h"
    done
    sed -n '/^enum dpu_enc_enable_state {/,/^};/p' "$dpu/dpu_encoder_phys.h"
    # Keep register offsets and aggregate mask indices identical to the real writer.
    awk '/^#define[ \t]+(CTL_(MERGE_3D_FLUSH|DSC_FLUSH|WB_FLUSH|CWB_FLUSH|INTF_FLUSH|CDM_FLUSH|PERIPH_FLUSH|DSPP_n_FLUSH|FLUSH)[ \t(]|(MERGE_3D|DSC|WB|CWB|INTF|CDM|PERIPH|DSPP)_IDX[ \t])/' "$dpu/dpu_hw_ctl.c"
    cat <<'CPP'
struct dpu_mdss_version {int core_major_ver;};
struct dpu_mdss_cfg {const dpu_mdss_version *mdss_ver;};
static const dpu_mdss_version modern{10},legacy{4};
static const dpu_mdss_cfg dpu_sm7675_cfg{&modern},other_catalog{&modern},old_catalog{&legacy};
struct dpu_kms {const dpu_mdss_cfg *catalog;};
struct drm_encoder {int encoder_type{DRM_MODE_ENCODER_DSI};};
struct dpu_hw_blk_reg_map {std::array<u32,256> regs{};};
struct dpu_hw_ctl;
struct ctl_ops {
    void (*trigger_flush)(dpu_hw_ctl *){};
    void (*update_pending_flush)(dpu_hw_ctl *,u32){};
    u32 (*get_pending_flush)(dpu_hw_ctl *){};
};
struct dpu_hw_ctl {
    int idx{};ctl_ops ops{};dpu_hw_blk_reg_map hw{};
    u32 pending_flush_mask{},pending_intf_flush_mask{},pending_dsc_flush_mask{},
        pending_merge_3d_flush_mask{},pending_wb_flush_mask{},pending_cwb_flush_mask{},
        pending_periph_flush_mask{},pending_cdm_flush_mask{};
    std::array<u32,DSPP_MAX-DSPP_0> pending_dspp_flush_mask{};
};
struct dpu_hw_mdp;
struct split_pipe_cfg {};
struct dpu_hw_mdp {struct {void (*setup_split_pipe)(dpu_hw_mdp *,split_pipe_cfg *);} ops;};
struct dpu_hw_intf {dpu_intf idx;};
struct dpu_hw_pingpong {};
struct dpu_hw_wb {int idx;};
struct dpu_encoder_phys;
struct dpu_encoder_phys {
    drm_encoder *parent{};struct dpu_kms *dpu_kms{};role split_role{};
    dpu_intf_mode intf_mode{};dpu_hw_intf *hw_intf{};dpu_hw_ctl *hw_ctl{};
    dpu_hw_mdp *hw_mdptop{};dpu_hw_pingpong *hw_pp{};dpu_hw_wb *hw_wb{};
    dpu_enc_enable_state enable_state{DPU_ENC_ENABLED};
    struct {bool (*needs_single_flush)(dpu_encoder_phys *){};
            void (*trigger_start)(dpu_encoder_phys *){};} ops;
    int pending_ctlstart_cnt{},pending_kickoff_cnt{};
};
struct dpu_encoder_virt {
    drm_encoder base;dpu_encoder_phys *phys_encs[2]{};unsigned num_phys_encs{2};
    dpu_encoder_phys *cur_master{},*cur_slave{};int enc_spinlock{};
    unsigned long frame_busy_mask[1]{};unsigned cwb_mask{};
    struct {dpu_intf_type intf_type{INTF_DSI};bool is_cmd_mode{};
            unsigned num_of_h_tiles{2};unsigned h_tile_instance[2]{0,1};} disp_info;
};
static bool root_uke=true,root_sm7675=true;
static int starts{},errors{};
static std::vector<std::tuple<const dpu_hw_blk_reg_map *,u32,u32>> writes;
static std::vector<int> flush_interfaces;
static dpu_encoder_virt *to_dpu_encoder_virt(drm_encoder *p) {
    return reinterpret_cast<dpu_encoder_virt *>(p);
}
static bool of_machine_is_compatible(const char *n) {
    if(std::string(n)=="xiaomi,uke")return root_uke;
    if(std::string(n)=="qcom,sm7675")return root_sm7675;
    assert(false);return false;
}
static void register_write(dpu_hw_blk_reg_map *hw,u32 offset,u32 value) {
    hw->regs.at(offset/4)=value;writes.emplace_back(hw,offset,value);
}
static int atomic_inc_return(int *p) {return ++*p;}
static void set_bit(unsigned i,unsigned long *p) {*p|=1UL<<i;}
static int dpu_encoder_helper_get_intf_type(dpu_intf_mode mode) {return mode;}
static void record_flush(int,int,int intf,int,int,int,u32,u32) {
    flush_interfaces.emplace_back(intf);
}
static void split_setup(dpu_hw_mdp *,split_pipe_cfg *) {}
static void start(dpu_encoder_phys *p) {assert(p->split_role!=ENC_ROLE_SLAVE);++starts;}
#define DRMID(...) 0
#define DPU_REG_WRITE(hw,offset,value) register_write(hw,offset,value)
#define DPU_ERROR(...) (++errors)
#define DPU_DEBUG(...) ((void)0)
#define trace_dpu_enc_trigger_flush(...) record_flush(__VA_ARGS__)
#define trace_dpu_hw_ctl_update_pending_flush(...) ((void)0)
#define spin_lock_irqsave(lock,flags) do {(void)(lock);(flags)=0;}while(0)
#define spin_unlock_irqrestore(lock,flags) do {(void)(lock);(void)(flags);}while(0)
CPP
    extract "$dpu/dpu_hw_ctl.c" 'static inline void dpu_hw_ctl_update_pending_flush(struct dpu_hw_ctl *ctx,'
    extract "$dpu/dpu_hw_ctl.c" 'static u32 dpu_hw_ctl_get_pending_flush(struct dpu_hw_ctl *ctx)'
    extract "$dpu/dpu_hw_ctl.c" 'static void dpu_hw_ctl_update_pending_flush_intf_v1(struct dpu_hw_ctl *ctx,'
    extract "$dpu/dpu_hw_ctl.c" 'static void dpu_hw_ctl_update_pending_flush_dsc_v1(struct dpu_hw_ctl *ctx,'
    extract "$dpu/dpu_hw_ctl.c" 'static inline void dpu_hw_ctl_trigger_flush_v1(struct dpu_hw_ctl *ctx)'
    extract "$dpu/dpu_encoder_phys.h" 'static inline int dpu_encoder_phys_inc_pending(struct dpu_encoder_phys *phys)'
    extract "$dpu/dpu_encoder_phys_vid.c" 'static bool dpu_encoder_phys_vid_needs_single_flush('
    extract "$dpu/dpu_encoder.c" 'static bool dpu_encoder_uke_split_flush(struct dpu_encoder_phys *phys_enc)'
    extract "$dpu/dpu_encoder.c" 'static void _dpu_encoder_trigger_flush(struct drm_encoder *drm_enc,'
    extract "$dpu/dpu_encoder.c" 'static void _dpu_encoder_trigger_start(struct dpu_encoder_phys *phys)'
    extract "$dpu/dpu_encoder.c" 'static void _dpu_encoder_kickoff_phys(struct dpu_encoder_virt *dpu_enc)'
    cat <<'CPP'
struct fixture {
    dpu_kms kms{&dpu_sm7675_cfg};dpu_encoder_virt v;
    dpu_hw_ctl ctl{},other_ctl{};dpu_hw_mdp mdp{{split_setup}};
    dpu_hw_intf intfs[2]{{INTF_1},{INTF_2}};dpu_hw_pingpong pp[2];
    dpu_encoder_phys p[2];
    fixture() {
        for(auto *c:{&ctl,&other_ctl})
            c->ops={dpu_hw_ctl_trigger_flush_v1,dpu_hw_ctl_update_pending_flush,
                    dpu_hw_ctl_get_pending_flush};
        for(unsigned i=0;i<2;i++) {
            v.phys_encs[i]=&p[i];p[i].parent=&v.base;p[i].dpu_kms=&kms;
            p[i].split_role=i ? ENC_ROLE_SLAVE:ENC_ROLE_MASTER;
            p[i].intf_mode=INTF_MODE_VIDEO;p[i].hw_intf=&intfs[i];
            p[i].hw_ctl=&ctl;p[i].hw_mdptop=&mdp;p[i].hw_pp=&pp[i];
            p[i].ops={dpu_encoder_phys_vid_needs_single_flush,start};
        }
        v.cur_master=&p[0];v.cur_slave=&p[1];
    }
    void prepare() {
        ctl.pending_flush_mask=BIT(0)|BIT(6)|BIT(17); // plane/mixer/CTL bits survive
        dpu_hw_ctl_update_pending_flush_intf_v1(&ctl,INTF_1);
        dpu_hw_ctl_update_pending_flush_intf_v1(&ctl,INTF_2);
        dpu_hw_ctl_update_pending_flush_dsc_v1(&ctl,DSC_0);
        dpu_hw_ctl_update_pending_flush_dsc_v1(&ctl,DSC_1);
        assert(ctl.pending_intf_flush_mask==6 && ctl.pending_dsc_flush_mask==3);
        assert(ctl.pending_flush_mask==(BIT(31)|BIT(22)|BIT(17)|BIT(6)|BIT(0)));
        writes.clear();flush_interfaces.clear();starts=errors=0;
    }
    void verify(unsigned count,int master_count,int slave_count) {
        unsigned flush_count=0,intf_count=0,dsc_count=0;
        for(const auto &[hw,offset,value]:writes) {
            if(hw!=&ctl.hw)continue;
            if(offset==CTL_FLUSH){++flush_count;assert(value==ctl.pending_flush_mask);}
            if(offset==CTL_INTF_FLUSH){++intf_count;assert(value==6);}
            if(offset==CTL_DSC_FLUSH){++dsc_count;assert(value==3);}
        }
        assert(flush_count==count && intf_count==count && dsc_count==count);
        assert(p[0].pending_kickoff_cnt==master_count && p[0].pending_ctlstart_cnt==master_count);
        assert(p[1].pending_kickoff_cnt==slave_count && p[1].pending_ctlstart_cnt==slave_count);
        assert(ctl.pending_intf_flush_mask==6 && ctl.pending_dsc_flush_mask==3);
    }
};
int main() {
    // First enable and steady-state frames: actual masks, actual single MMIO
    // submission and both actual counter types. Repeated kickoffs remain balanced.
    for(auto a:{DPU_ENC_ENABLING,DPU_ENC_ENABLED})
    for(auto b:{DPU_ENC_ENABLING,DPU_ENC_ENABLED}) {
        fixture f;f.p[0].enable_state=a;f.p[1].enable_state=b;f.prepare();
        for(int frame=1;frame<=3;frame++) {
            writes.clear();flush_interfaces.clear();
            _dpu_encoder_kickoff_phys(&f.v);f.verify(1,frame,frame);
            assert(flush_interfaces==std::vector<int>{INTF_1});
            assert(f.v.frame_busy_mask[0]==1 && starts==frame);
        }
    }
    // Disabled/disabling/reset-needed state combinations retain old submission
    // semantics unless both paths are in an admitted operational state.
    for(auto a:{DPU_ENC_DISABLING,DPU_ENC_DISABLED,DPU_ENC_ENABLING,DPU_ENC_ENABLED,DPU_ENC_ERR_NEEDS_HW_RESET})
    for(auto b:{DPU_ENC_DISABLING,DPU_ENC_DISABLED,DPU_ENC_ENABLING,DPU_ENC_ENABLED,DPU_ENC_ERR_NEEDS_HW_RESET}) {
        fixture f;f.p[0].enable_state=a;f.p[1].enable_state=b;f.prepare();
        _dpu_encoder_kickoff_phys(&f.v);
        const bool paired=(a==DPU_ENC_ENABLING || a==DPU_ENC_ENABLED) &&
                          (b==DPU_ENC_ENABLING || b==DPU_ENC_ENABLED);
        const int master=a!=DPU_ENC_DISABLED,slave=b!=DPU_ENC_DISABLED;
        f.verify(paired ? 1:master+slave,master,slave);
        assert(starts==master && f.v.frame_busy_mask[0]==unsigned(master));
    }
    {fixture f;root_uke=false;f.prepare();_dpu_encoder_kickoff_phys(&f.v);f.verify(2,1,1);root_uke=true;}
    {fixture f;root_sm7675=false;f.prepare();_dpu_encoder_kickoff_phys(&f.v);f.verify(2,1,1);root_sm7675=true;}
    {fixture f;f.kms.catalog=&other_catalog;f.prepare();_dpu_encoder_kickoff_phys(&f.v);f.verify(2,1,1);}
    {fixture f;f.v.disp_info.is_cmd_mode=true;f.prepare();_dpu_encoder_kickoff_phys(&f.v);f.verify(2,1,1);}
    {fixture f;f.v.disp_info.h_tile_instance[1]=0;f.prepare();_dpu_encoder_kickoff_phys(&f.v);f.verify(2,1,1);}
    {fixture f;f.v.num_phys_encs=1;f.prepare();_dpu_encoder_kickoff_phys(&f.v);f.verify(1,1,0);}
    {fixture f;f.p[1].hw_ctl=&f.other_ctl;f.prepare();_dpu_encoder_kickoff_phys(&f.v);f.verify(1,1,1);
        assert(flush_interfaces==(std::vector<int>{INTF_1,INTF_2}));}
    {fixture f;f.p[0].hw_pp=nullptr;f.prepare();_dpu_encoder_kickoff_phys(&f.v);f.verify(1,0,1);}
    {fixture f;f.p[1].hw_pp=nullptr;f.prepare();_dpu_encoder_kickoff_phys(&f.v);f.verify(1,1,0);}
    {fixture f;f.ctl.ops.trigger_flush=nullptr;f.prepare();_dpu_encoder_kickoff_phys(&f.v);f.verify(0,0,0);}
    // Existing legacy consolidation is untouched, including its old counter
    // policy. This candidate does not silently repair unrelated legacy paths.
    {fixture f;f.kms.catalog=&old_catalog;f.prepare();_dpu_encoder_kickoff_phys(&f.v);f.verify(1,1,0);}
}
CPP
} >> "$work/check.cpp"
"${CXX:-c++}" -std=c++20 -O2 -Wall -Wextra -Werror \
    -fsanitize=undefined -fsanitize-undefined-trap-on-error \
    "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual shared-CTL kickoff, both counter types and CTL INTF/DSC/aggregate writers: admitted, transitional, unrelated, legacy and repeated frames passed\n'
