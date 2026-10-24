#!/usr/bin/env bash
# Run the actual Linux 7.3 split stream lifecycle with injected failures.
set -Eeuo pipefail
kernel=${1:?Pass the prepared kernel}
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstdio>
#define WRITE_ONCE(x,v) ((x)=(v))
#define DRM_ERROR(...) ((void)0)
#define drm_dbg_dp(...) ((void)0)
#define container_of(p,type,member) reinterpret_cast<type*>(p)
struct Guard {
    bool* lock;
    explicit Guard(bool* p):lock(p) {assert(!*lock);*lock=true;}
    ~Guard() {assert(*lock);*lock=false;}
};
#define scoped_guard(x,p) if (Guard held{p}; true)
struct device {void* of_node;};
struct platform_device {device dev;};
struct drm_bridge {};
struct drm_atomic_commit {};
struct msm_dp_bridge_state {};
struct msm_dp_panel {bool hdr_active=true;};
struct msm_dp_ctrl {};
struct Link {unsigned sink_count=1;};
struct msm_dp {
    platform_device* pdev;
    drm_bridge* bridge;
    bool is_edp=false,power_on=false;
    unsigned connector_type=0;
    void* drm_dev=nullptr;
};
struct msm_dp_display_private {
    msm_dp msm_dp_display{};
    Link* link;
    msm_dp_panel* panel;
    msm_dp_ctrl* ctrl;
    bool stream_pm_active=false,stream_link_attempted=false,plugged_lock=false;
    bool link_failed=false,link_status_notified=false,phy_initialized=true;
    int link_status_work=0;
    void* drm_dev=nullptr;
};
static int failure,gets,puts_count,refs,phy_exits,off_links,off_pixels,notifies;
static bool managed;
static msm_dp_bridge_state color;
static bool of_device_is_compatible(void*,const char*) {return managed;}
static msm_dp_bridge_state* drm_atomic_get_new_bridge_state(drm_atomic_commit*,drm_bridge*) {return &color;}
static msm_dp_bridge_state* to_dp_bridge_state(msm_dp_bridge_state* p) {return p;}
static int pm_runtime_resume_and_get(device*) {++gets;if(failure==1)return -EAGAIN;++refs;return 0;}
static void pm_runtime_put_sync(device*) {assert(refs>0);--refs;++puts_count;}
static void msm_dp_hpd_plug_handle(msm_dp_display_private*) {}
static void msm_dp_hpd_unplug_handle(msm_dp_display_private*) {}
static void msm_dp_display_host_phy_init(msm_dp_display_private* p) {p->phy_initialized=true;}
static void msm_dp_display_host_phy_exit(msm_dp_display_private* p) {if(p->phy_initialized){assert(refs>0);++phy_exits;p->phy_initialized=false;}}
static int msm_dp_ctrl_on_link(msm_dp_ctrl*,msm_dp_panel*) {return failure==3?-EIO:0;}
static int msm_dp_ctrl_prepare_stream_on(msm_dp_ctrl*,msm_dp_panel*,bool) {return failure==4?-ETIMEDOUT:0;}
static int msm_dp_display_enable(msm_dp_display_private* p,msm_dp_panel*,const msm_dp_bridge_state* c) {
    assert((c!=nullptr)==managed);if(failure==5)return -ENOSPC;p->msm_dp_display.power_on=true;return 0;
}
static int msm_dp_display_post_enable(msm_dp*) {return failure==6?-EIO:0;}
static void msm_dp_display_audio_notify_disable(msm_dp_display_private*) {}
static void msm_dp_ctrl_off_pixel_clk(msm_dp_ctrl*) {assert(refs>0);++off_pixels;}
static void msm_dp_ctrl_off_link(msm_dp_ctrl*,msm_dp_panel*) {assert(refs>0);++off_links;}
static void msm_dp_display_disable(msm_dp_display_private* p,msm_dp_panel*) {
    assert(refs>0);p->msm_dp_display.power_on=false;
    msm_dp_display_host_phy_exit(p);++off_pixels;++off_links;
}
static void msm_dp_display_unprepare(msm_dp_display_private* p) {pm_runtime_put_sync(&p->msm_dp_display.pdev->dev);}
static void schedule_work(int*) {++notifies;}
CPP
awk '/^static int msm_dp_display_prepare_link\(/ || /^void msm_dp_display_atomic_enable\(/ || /^void msm_dp_display_atomic_post_disable\(/ {emit=1} emit{print} emit&&/^}/{emit=0}' "$kernel/drivers/gpu/drm/msm/dp/dp_display.c" >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
int main() {
    for(bool uke:{false,true})for(int stage=0;stage<=6;++stage) {
        managed=uke;failure=stage;
        gets=puts_count=refs=phy_exits=off_links=off_pixels=notifies=0;
        platform_device pdev{};drm_bridge bridge;drm_atomic_commit commit;
        Link link;msm_dp_panel panel;msm_dp_ctrl ctrl;msm_dp_display_private dp{};
        dp.msm_dp_display.pdev=&pdev;dp.msm_dp_display.bridge=&bridge;
        dp.link=&link;dp.panel=&panel;dp.ctrl=&ctrl;
        if(stage==2)link.sink_count=0;
        msm_dp_display_atomic_enable(&dp.msm_dp_display,&commit);
        assert(gets==1&&!dp.plugged_lock);
        if(!stage) {
            assert(refs==1&&dp.stream_pm_active&&dp.stream_link_attempted&&dp.msm_dp_display.power_on);
            assert(!dp.link_failed&&!notifies);
        } else {
            assert(refs==0&&!dp.stream_pm_active&&!dp.stream_link_attempted&&!dp.msm_dp_display.power_on);
            assert(puts_count==(stage==1?0:1)&&phy_exits==(stage==1?0:1));
            assert(off_links==(stage>=3?1:0)&&off_pixels==off_links);
            assert(dp.link_failed&&notifies==1&&!panel.hdr_active);
        }
        msm_dp_display_atomic_post_disable(&dp.msm_dp_display);
        assert(!refs&&!dp.stream_pm_active&&!dp.stream_link_attempted&&!dp.msm_dp_display.power_on);
        const int released=puts_count,links=off_links;
        msm_dp_display_atomic_post_disable(&dp.msm_dp_display);
        assert(puts_count==released&&off_links==links);
    }
    std::puts("Actual DP split lifecycle: PM, missing sink, link/train/stream/post failures, success and duplicate teardown passed; host only");
}
CPP
"${CXX:-c++}" -include initializer_list -std=c++20 -O2 -Wall -Wextra -Werror "$work/check.cpp" -o "$work/check"
"$work/check"
