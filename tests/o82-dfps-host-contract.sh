#!/usr/bin/env bash
# Exercise the actual queued/paired timing functions without MMIO or a tablet.
set -Eeuo pipefail
host=${1:?Pass prepared dsi_host.c}
header=${2:?Pass src/display/o82-mode.h}
modes=${3:?Pass src/display/o82-data.h}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/linux" "$work/drm"
cp "$header" "$work/o82-mode.h"
printf '#define EINVAL 22\n' > "$work/linux/errno.h"
cat > "$work/drm/drm_modes.h" <<'CPP'
struct drm_display_mode {
    int clock,hdisplay,hsync_start,hsync_end,htotal,vdisplay,vsync_start,vsync_end,vtotal;
    unsigned int width_mm,height_mm,flags=0,hskew=0; int vscan=0;
};
CPP
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cstdint>
#include <vector>
#include <cstring>
#include "o82-mode.h"
using u32=uint32_t;
#define ARRAY_SIZE(v) (sizeof(v)/sizeof(v[0]))
#define DIV_ROUND_UP(n,d) (((n)+(d)-1)/(d))
#define READ_ONCE(v) (v)
#define ENOMEM 12
#define EOPNOTSUPP 95
#define EPIPE 32
#define DSI_6G_REG_SHIFT 4
#define DSI_0 0
#define DSI_1 1
#define SINGLE_DEPTH_NESTING 1
#define DSI_TOTAL_H_TOTAL(v) (v)
#define DSI_TOTAL_V_TOTAL(v) ((v)<<16)
#define REG_DSI_TOTAL 0x28
struct mutex {bool locked=false;};
static void mutex_lock(mutex *m) {assert(!m->locked);m->locked=true;}
static void mutex_unlock(mutex *m) {assert(m->locked);m->locked=false;}
static void mutex_lock_nested(mutex *m,int depth) {assert(depth==1);mutex_lock(m);}
struct mipi_dsi_host {void *owner;};
struct msm_dsi_host {
    mipi_dsi_host base;mutex dev_mutex,cmd_mutex;void *dev=nullptr,*vm=nullptr;
    drm_display_mode *mode=nullptr,*uke_dfps_mode=nullptr;
    bool uke_dfps_staged=false,power_on=true,enabled=true,cmd_dma_blocked=false,scope=true;
    int id;
};
struct o82_timing {unsigned int group;drm_display_mode mode;};
static bool oom=false;
static unsigned allocations=0;
static msm_dsi_host *to_msm_dsi_host(mipi_dsi_host *h) {return static_cast<msm_dsi_host*>(h->owner);}
static drm_display_mode *drm_mode_duplicate(void*,const drm_display_mode *m) {
    if(oom)return nullptr; ++allocations; return new drm_display_mode(*m);
}
static void drm_mode_destroy(void*,drm_display_mode *m) {assert(m&&allocations);--allocations;delete m;}
static bool drm_mode_equal(const drm_display_mode *a,const drm_display_mode *b) {
    return !std::memcmp(a,b,sizeof(*a));
}
static bool dsi_uke_o82_refresh_modes(msm_dsi_host *h,const drm_display_mode *m) {
    return h->scope&&qcom_uke_o82_mode(m);
}
struct write {int id;u32 reg,value;};
static std::vector<write> writes;
static unsigned barriers=0;
static void dsi_write(msm_dsi_host *h,u32 reg,u32 value) {
    assert(h->dev_mutex.locked);writes.push_back({h->id,reg+DSI_6G_REG_SHIFT,value});
}
static void wmb(){++barriers;}
CPP
extract() {
    awk -v signature="$1" 'index($0,signature)==1 {emit=1;found=1} emit {print} emit && /^}/ {exit} END {if (!found) exit 1}' "$host"
}
{
    sed -n '/^static const struct o82_timing o82_modes\[\] = {/,/^};/p' "$modes"
    extract 'static u32 dsi_uke_o82_total('
    sed -n '/^#define DSI_UKE_TIMING_DB_/p' "$host"
    extract 'int msm_dsi_host_uke_dfps_queue('
    extract 'bool msm_dsi_host_uke_dfps_pending('
    extract 'void msm_dsi_host_uke_dfps_cancel('
    extract 'int msm_dsi_host_uke_dfps_pair('
} >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
static void clear(msm_dsi_host &h) {
    if(h.uke_dfps_mode)drm_mode_destroy(h.dev,h.uke_dfps_mode);
    if(h.mode)drm_mode_destroy(h.dev,h.mode);
    h.mode=h.uke_dfps_mode=nullptr;h.uke_dfps_staged=false;
}
int main() {
    static_assert(DSI_UKE_TIMING_DB_TRIGGER+DSI_6G_REG_SHIFT==0x1e4);
    static_assert(DSI_UKE_TIMING_DB_MODE+DSI_6G_REG_SHIFT==0x1e8);
    msm_dsi_host a,b;a.id=0;b.id=1;a.base.owner=&a;b.base.owner=&b;a.vm=b.vm=&a;
    for(unsigned i=0;i<ARRAY_SIZE(o82_modes);++i) for(unsigned j=0;j<ARRAY_SIZE(o82_modes);++j) {
        a.mode=drm_mode_duplicate(nullptr,&o82_modes[i].mode);b.mode=drm_mode_duplicate(nullptr,&o82_modes[i].mode);
        writes.clear();barriers=0;
        bool valid=qcom_uke_o82_live_change(&o82_modes[i].mode,&o82_modes[j].mode);
        int ra=msm_dsi_host_uke_dfps_queue(&a.base,a.mode,&o82_modes[j].mode);
        int rb=msm_dsi_host_uke_dfps_queue(&b.base,b.mode,&o82_modes[j].mode);
        assert((ra==0)==valid&&(rb==0)==valid&&writes.empty());
        if(valid) {
            assert(msm_dsi_host_uke_dfps_pending(&a.base)&&msm_dsi_host_uke_dfps_pending(&b.base));
            assert(msm_dsi_host_uke_dfps_pair(&a.base,&b.base,false)==0);
            assert(writes.size()==6&&barriers==3);
            assert(writes[0].id==0&&writes[0].reg==0x1e8&&writes[0].value==1);
            assert(writes[1].id==1&&writes[1].reg==0x1e8&&writes[1].value==1);
            assert(writes[2].id==0&&writes[2].reg==0x2c);
            assert(writes[3].id==1&&writes[3].reg==0x2c);
            assert(writes[4].id==0&&writes[4].reg==0x1e4&&writes[4].value==1);
            assert(writes[5].id==1&&writes[5].reg==0x1e4&&writes[5].value==1);
            assert(drm_mode_equal(a.mode,&o82_modes[i].mode));
            assert(!msm_dsi_host_uke_dfps_pending(&a.base));
            unsigned count=writes.size();
            assert(msm_dsi_host_uke_dfps_pair(&a.base,&b.base,false)==-EPIPE&&writes.size()==count);
            assert(msm_dsi_host_uke_dfps_pair(&a.base,&b.base,true)==0);
            assert(writes.size()==8&&writes[6].value==0&&writes[7].value==0);
            assert(drm_mode_equal(a.mode,&o82_modes[j].mode)&&drm_mode_equal(b.mode,a.mode));
            assert(!a.uke_dfps_mode&&!b.uke_dfps_mode&&!a.uke_dfps_staged&&!b.uke_dfps_staged);
        }
        clear(a);clear(b);assert(allocations==0);
    }
    // Every runtime refusal is checked before either timing database is touched.
    for(int failure=0;failure<10;++failure) {
        a.mode=drm_mode_duplicate(nullptr,&o82_modes[0].mode);b.mode=drm_mode_duplicate(nullptr,a.mode);
        assert(!msm_dsi_host_uke_dfps_queue(&a.base,a.mode,&o82_modes[1].mode));
        assert(!msm_dsi_host_uke_dfps_queue(&b.base,b.mode,&o82_modes[1].mode));
        writes.clear();barriers=0;
        switch(failure) {
        case 0:b.power_on=false;break;
        case 1:b.enabled=false;break;
        case 2:b.cmd_dma_blocked=true;break;
        case 3:b.scope=false;break;
        case 4:b.uke_dfps_staged=true;break;
        case 5:b.uke_dfps_mode->vdisplay--;break;
        case 6:b.mode->vdisplay--;break;
        case 7:b.id=0;break;
        case 8:b.vm=nullptr;break;
        case 9:b.vm=&b;break;
        }
        assert(msm_dsi_host_uke_dfps_pair(&a.base,&b.base,false)<0);
        assert(writes.empty()&&barriers==0);
        b.power_on=b.enabled=b.scope=true;b.cmd_dma_blocked=false;b.id=1;b.vm=&a;
        clear(a);clear(b);assert(!allocations);
    }
    a.mode=drm_mode_duplicate(nullptr,&o82_modes[0].mode);
    oom=true;assert(msm_dsi_host_uke_dfps_queue(&a.base,a.mode,&o82_modes[1].mode)==-ENOMEM);oom=false;
    assert(!a.uke_dfps_mode);assert(!msm_dsi_host_uke_dfps_queue(&a.base,a.mode,&o82_modes[1].mode));
    msm_dsi_host_uke_dfps_cancel(&a.base);assert(!a.uke_dfps_mode);clear(a);assert(!allocations);
}
CPP
"${CXX:-c++}" -std=c++20 -Wall -Wextra -Werror -Wno-misleading-indentation -fsanitize=undefined -fsanitize-undefined-trap-on-error -I "$work" "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual paired O82 DFPS: mode matrix, ordered shadow/trigger/release, pre-MMIO failures and allocation cleanup passed\n'
