#!/usr/bin/env bash
# Exercise the actual diagnostic transaction and its lifecycle lock pairs.
set -Eeuo pipefail
kernel=${1:?Pass the prepared native kernel source}
source=$kernel/drivers/gpu/drm/msm/dsi/dsi_host.c
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
extract() {
    awk -v signature="$1" '
        index($0,signature)==1 {emit=1; found=1}
        emit {print}
        emit && /^}/ {exit}
        END {if (!found) exit 1}
    ' "$source"
}
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <cstdio>
#include <string>
#include <vector>
using u32=uint32_t; using u64=uint64_t;
#define BIT(n) (1U<<(n))
#define CONFIG_DEBUG_FS 1
#define IS_ENABLED(v) (v)
#define READ_ONCE(v) (v)
#define ERESTARTSYS 512
#define DSI_6G_REG_SHIFT 4
#define MSM_DSI_VER_MAJOR_6G 3
#define MSM_DSI_6G_VER_MINOR_V2_8_0 0x20080000
#define MIPI_DSI_MODE_VIDEO BIT(0)
#define REG_DSI_CTRL 0
#define DSI_CTRL_ENABLE BIT(0)
#define DSI_CTRL_VID_MODE_EN BIT(1)
enum {DSI_0,DSI_1};
CPP
sed -n '/^#define UKE_DSI_MISR_CTRL/,/^};/p' "$source" >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
struct mutex {int rank;bool held{};};
static std::vector<int> locks;
static int lock_failure_rank,pm_result,pm_refs,sleeps,interrupt_at,missing_ready,changed_config,changed_engine;
static bool same_board,duplicate_fail;
static u32 regs[256];static std::vector<u32> writes;
struct device {};struct platform_device {device dev;};
struct drm_device {};
struct drm_display_mode {int hdisplay=3200,vdisplay=2136,hz=120;};
struct cfg {int io_offset=4;};
struct handler {int major=3,minor=MSM_DSI_6G_VER_MINOR_V2_8_0;struct cfg *cfg;};
struct mipi_dsi_host {};
struct msm_dsi_host {
    mipi_dsi_host base;platform_device *pdev;drm_device *dev{};int id{};
    handler *cfg_hnd;unsigned ctrl_size=4092,lanes=4,mode_flags=MIPI_DSI_MODE_VIDEO;
    bool cphy_mode{},power_on=true,enabled=true,cmd_dma_blocked{};
    drm_display_mode *mode;mutex dev_mutex{1},cmd_mutex{2};uke_dsi_misr_capture misr_capture{};
};
static msm_dsi_host *to_msm_dsi_host(mipi_dsi_host *h) {return reinterpret_cast<msm_dsi_host *>(h);}
static bool of_machine_is_compatible(const char *) {return same_board;}
static int drm_mode_vrefresh(drm_display_mode *m) {return m->hz;}
static int mutex_lock_interruptible(mutex *m) {
    if(lock_failure_rank==m->rank)return -EINTR;
    assert(!m->held);assert(locks.empty()||locks.back()<m->rank);
    m->held=true;locks.push_back(m->rank);return 0;
}
static void mutex_lock(mutex *m) {assert(mutex_lock_interruptible(m)==0);}
static void mutex_unlock(mutex *m) {
    assert(m->held&&!locks.empty()&&locks.back()==m->rank);
    m->held=false;locks.pop_back();
}
static int pm_runtime_get_if_active(device *) {if(pm_result>0)++pm_refs;return pm_result;}
static void pm_runtime_put(device *) {assert(pm_refs==1);--pm_refs;}
static u64 ktime_get_ns() {static u64 t;return ++t;}
static u32 dsi_read(msm_dsi_host *,u32 r) {assert(pm_refs==1);return regs[r/4];}
static void dsi_write(msm_dsi_host *,u32 r,u32 value) {
    assert(pm_refs==1);assert(r==UKE_DSI_MISR_CTRL);
    assert(locks==std::vector<int>({1,2}));writes.push_back(value);
    regs[r/4]=value|(regs[r/4]&UKE_DSI_MISR_STATUS);
}
static void wmb() {}
static int msleep_interruptible(int n) {
    assert(n==30);++sleeps;
    if(interrupt_at==sleeps)return 1;
    if(!missing_ready)regs[UKE_DSI_MISR_CTRL/4]|=UKE_DSI_MISR_STATUS;
    if(changed_config)regs[UKE_DSI_MISR_CTRL/4]^=BIT(24);
    if(changed_engine)regs[0]|=BIT(4);
    regs[UKE_DSI_MISR_SIGNATURE/4]=0x12345678;return 0;
}
static void dsi_op_mode_config(msm_dsi_host *,bool,bool) {assert(locks==std::vector<int>({1,2}));}
static void dsi_sw_reset(msm_dsi_host *) {assert(locks==std::vector<int>({1,2}));}
static void drm_mode_destroy(drm_device *,drm_display_mode *) {assert(locks==std::vector<int>({1}));}
static drm_display_mode *drm_mode_duplicate(drm_device *,const drm_display_mode *m) {
    assert(locks==std::vector<int>({1}));return duplicate_fail?nullptr:const_cast<drm_display_mode *>(m);
}
#define pr_err(...) do {} while(0)
CPP
for function in 'static bool dsi_uke_misr_scope(' 'static int dsi_uke_misr_capture(' \
                'int msm_dsi_host_enable(' 'int msm_dsi_host_disable(' \
                'int msm_dsi_host_set_display_mode('; do
    extract "$function" >> "$work/check.cpp"
done
cat >> "$work/check.cpp" <<'CPP'
int main() {
    cfg conf;handler h{3,MSM_DSI_6G_VER_MINOR_V2_8_0,&conf};platform_device p;drm_display_mode mode;
    msm_dsi_host host{};host.pdev=&p;host.cfg_hnd=&h;host.mode=&mode;
    auto reset=[&] {
        assert(locks.empty()&&pm_refs==0);memset(regs,0,sizeof(regs));regs[0]=3;
        writes.clear();host.misr_capture={};same_board=true;pm_result=1;
        lock_failure_rank=sleeps=interrupt_at=missing_ready=changed_config=changed_engine=0;
        host.power_on=host.enabled=true;host.cmd_dma_blocked=false;host.mode=&mode;mode={};
    };
    auto run=[&](int expected,unsigned count=4) {
        static int case_number;int actual=dsi_uke_misr_capture(&host,count);++case_number;
        if(actual!=expected)std::fprintf(stderr,"case %d: expected %d, actual %d\n",case_number,expected,actual);
        assert(actual==expected);
        assert(locks.empty()&&pm_refs==0);
    };
    reset();run(-EINVAL,0);assert(writes.empty());run(-EINVAL,9);assert(writes.empty());
    for(int lock:{1,2}){reset();lock_failure_rank=lock;run(-EINTR);assert(writes.empty());}
    reset();same_board=false;run(-EOPNOTSUPP);assert(writes.empty());
    reset();mode.hz=60;run(-EOPNOTSUPP);assert(writes.empty());
    reset();mode.hdisplay=1600;run(-EOPNOTSUPP);assert(writes.empty());
    reset();host.mode=nullptr;run(-EOPNOTSUPP);assert(writes.empty());
    reset();host.enabled=false;run(-EBUSY);assert(writes.empty());
    reset();host.cmd_dma_blocked=true;run(-EBUSY);assert(writes.empty());
    for(int pm:{0,-EIO}) {reset();pm_result=pm;run(pm?pm:-EAGAIN);assert(writes.empty());}
    reset();regs[0]=1;run(-EBUSY);assert(writes.empty());
    reset();regs[UKE_DSI_MISR_CTRL/4]=BIT(8);run(-EBUSY);assert(writes.empty());
    for(u32 sticky:{0U,UKE_DSI_MISR_STATUS,BIT(24),BIT(24)|UKE_DSI_MISR_STATUS}) {
        reset();regs[UKE_DSI_MISR_CTRL/4]=sticky;run(0);
        assert(host.misr_capture.completed==4&&writes==std::vector<u32>({0,UKE_DSI_MISR_CONFIG,sticky&~UKE_DSI_MISR_STATUS}));
        assert((regs[UKE_DSI_MISR_CTRL/4]&~UKE_DSI_MISR_STATUS)==(sticky&~UKE_DSI_MISR_STATUS));
        for(auto s:host.misr_capture.samples) {if(s.control)assert(s.signature==0x12345678);}
        run(0,1);assert(host.misr_capture.sequence==2&&host.misr_capture.completed==1);
    }
    for(int at:{1,3}) {
        reset();regs[UKE_DSI_MISR_CTRL/4]=BIT(24);interrupt_at=at;
        run(-ERESTARTSYS);assert(writes.back()==BIT(24));
    }
    reset();missing_ready=1;run(-ETIMEDOUT);assert(writes.back()==0&&host.misr_capture.completed==1);
    reset();changed_config=1;run(-EIO);assert(writes.back()==0);
    reset();changed_engine=1;run(-EIO);assert(writes.back()==0);
    reset();assert(!msm_dsi_host_enable(&host.base)&&host.enabled);
    assert(!msm_dsi_host_disable(&host.base)&&!host.enabled&&locks.empty());
    host.cmd_dma_blocked=true;assert(msm_dsi_host_enable(&host.base)==-EIO&&locks.empty());
    reset();assert(!msm_dsi_host_set_display_mode(&host.base,&mode)&&locks.empty());
    duplicate_fail=true;assert(msm_dsi_host_set_display_mode(&host.base,&mode)==-ENOMEM&&locks.empty());
}
CPP
"${CXX:-c++}" -std=c++17 -Wall -Wextra -Werror -fsanitize=undefined -fsanitize-undefined-trap-on-error \
    "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'DSI MISR transaction: refusal, READY, signals, cleanup, PM and lifecycle locks passed\n'
