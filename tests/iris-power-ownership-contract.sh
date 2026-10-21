#!/usr/bin/env bash
# shellcheck disable=SC2129
# Import actual native power paths; model provider requests, not physical rails.
set -Eeuo pipefail
iris=$1
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <algorithm>
#include <array>
#include <cassert>
#include <cerrno>
#include <climits>
#include <cstdint>
#include <cstring>
#include <iostream>
using u32 = unsigned;
using u64 = std::uint64_t;
using u8 = unsigned char;
// Carry invalid C enum inputs without introducing C++ enum undefined behavior.
using platform_clk_type = unsigned;
#define BIT(n) (1UL << (n))
#define BITS_PER_LONG (sizeof(unsigned long) * CHAR_BIT)
#define __iomem
#define dev_err(...) ((void)0)
#include "iris_vpu_register_defines.h"
CPP
for pattern in '^enum platform_clk_type ' '^enum platform_pm_domain_type ' \
               '^struct platform_clk_data ' '^struct iris_core_power '; do
    awk -v pattern="$pattern" '$0 ~ pattern {emit=1} emit {
        if ($0 ~ /^enum platform_clk_type/) sub("enum platform_clk_type", "enum");
        else gsub("enum platform_clk_type", "platform_clk_type"); print
    } emit && /^};/ {exit}' \
        "$iris/iris_platform_common.h" >> "$work/check.cpp"
done
cat >> "$work/check.cpp" <<'CPP'
struct iris_core;
struct vpu_ops {
    int (*power_on_controller)(iris_core *);
    int (*power_on_hw)(iris_core *);
    void (*power_off_hw)(iris_core *);
    int (*power_off_controller)(iris_core *);
    int (*power_off_checked)(iris_core *);
};
struct device { int id, usage=0, gets=0, puts=0, restored=0, fatal=0; };
struct clk { int stage, refs=0, enabled=0, disabled=0; };
struct clk_bulk_data { const char *id; struct clk *clk; };
struct icc_info { unsigned long bw_min_kbps, bw_max_kbps; };
struct icc_bulk_data { const char *name; unsigned long avg_bw, peak_bw; };
struct domains { u32 num_pds; device **pd_devs; };
struct platform_data {
    const struct vpu_ops *vpu_ops;
    const platform_clk_data *clk_tbl;
    u32 clk_tbl_size, clk_rst_tbl_size=1, controller_rst_tbl_size=1;
    const icc_info *icc_tbl;
};
struct iris_core {
    device *dev;
    platform_data *iris_platform_data;
    domains *pmdomain_tbl;
    clk_bulk_data *clock_tbl;
    u32 clk_count;
    icc_bulk_data *icc_tbl;
    u32 icc_count;
    iris_core_power power{};
    u8 *reg_base;
    void *resets=nullptr, *controller_resets=nullptr;
    unsigned intr_status=0;
    int state=0;
    bool irq_enabled=false;
};
enum {
    IRIS_CORE_ERROR=1, ICC_ON=1, ICC_OFF, OPP_ON, OPP_RATE, OPP_OFF,
    CTRL_GET, HW_GET, CTRL_PUT, HW_PUT, AXI_ON, CTRL_ON, HW_ON,
    HWMODE, QUIESCE, CPU_POLL, DEBUG_POLL, SPARE_POLL, ON_RESET,
    OFF_RESET, XO_ASSERT, XO_DEASSERT
};
static int fault, secondary, mmio, quiesces, hwmodes, icc_calls, opp_calls;
static bool stopping, collapsed, icc_request, opp_request, positive_pm;
static iris_core *checked_core;
static std::array<u32, 0xf0000/4> regs;
static clk clocks[]{{AXI_ON},{CTRL_ON},{HW_ON}};
static int failure(int stage) {
    if (fault==stage) return -EUCLEAN;
    if (secondary==stage) return -EREMOTEIO;
    return 0;
}
static int iris_opp_set_rate(device *, unsigned long rate) {
    ++opp_calls;
    // The real recommended-OPP helper selects the lowest OPP for rate zero.
    opp_request=true;
    const int ret=failure(!rate ? OPP_OFF : rate==ULONG_MAX ? OPP_ON : OPP_RATE);
    return ret;
}
static int dev_pm_opp_set_opp(device *, void *opp) {
    assert(!opp && !checked_core->power.domain_mask && !checked_core->power.clock_mask);
    ++opp_calls;
    const int ret=failure(OPP_OFF);
    if (!ret) opp_request=false;
    return ret;
}
static int icc_bulk_set_bw(int count, icc_bulk_data *votes) {
    assert(count==1); ++icc_calls;
    if (votes[0].avg_bw) icc_request=true;
    const int ret=failure(votes[0].avg_bw ? ICC_ON : ICC_OFF);
    if (!votes[0].avg_bw && !ret) icc_request=false;
    return ret;
}
static int iris_set_icc_bw(iris_core *core, unsigned long bandwidth) {
    core->icc_tbl[0].avg_bw=bandwidth;
    return icc_bulk_set_bw(core->icc_count,core->icc_tbl);
}
static int pm_runtime_resume_and_get(device *dev) {
    ++dev->gets;
    const int ret=dev->fatal ? dev->fatal : failure(dev->id ? HW_GET : CTRL_GET);
    if (!ret) ++dev->usage;
    return ret ? ret : positive_pm ? 1 : 0;
}
static int pm_runtime_put_sync(device *dev) {
    assert(!checked_core->irq_enabled);
    assert(dev->usage>0); --dev->usage; ++dev->puts;
    const int ret=dev->fatal ? dev->fatal : failure(dev->id ? HW_PUT : CTRL_PUT);
    if (ret) dev->fatal=ret;
    return ret;
}
static void pm_runtime_get_noresume(device *dev) { ++dev->usage; ++dev->restored; }
static int clk_prepare_enable(clk *clock) {
    const int ret=failure(clock->stage);
    if (!ret) { ++clock->refs; ++clock->enabled; }
    return ret;
}
static void clk_disable_unprepare(clk *clock) {
    assert(!checked_core->irq_enabled);
    assert(clock->refs>0); --clock->refs; ++clock->disabled;
}
static u32 offset(const volatile void *address) {
    auto n=reinterpret_cast<std::uintptr_t>(address)-
           reinterpret_cast<std::uintptr_t>(regs.data());
    assert(n<sizeof(regs) && n%4==0 && clocks[1].refs>0);
    ++mmio;
    return static_cast<u32>(n);
}
static u32 readl(const volatile void *address) {
    const auto n=offset(address);
    if (n==WRAPPER_CORE_POWER_STATUS) return collapsed ? 0 : BIT(1);
    if (n==WRAPPER_IRIS_CPU_NOC_LPI_STATUS) return BIT(0);
    if (n==WRAPPER_DEBUG_BRIDGE_LPI_STATUS) return 0;
    return regs[n/4];
}
static void writel(u32 value, volatile void *address) { regs[offset(address)/4]=value; }
static int poll_failure(const volatile void *address) {
    const auto n=offset(address);
    return failure(n==WRAPPER_IRIS_CPU_NOC_LPI_STATUS ? CPU_POLL :
                   n==WRAPPER_DEBUG_BRIDGE_LPI_STATUS ? DEBUG_POLL : SPARE_POLL);
}
#define readl_poll_timeout(address, value, condition, delay, timeout) \
    ([&]() { (value)=readl(address); const int ret=poll_failure(address); \
             return ret ? ret : (condition) ? 0 : -ETIMEDOUT; }())
static void usleep_range(unsigned, unsigned) {}
static int reset_control_bulk_reset(u32, void *) { return failure(stopping ? OFF_RESET : ON_RESET); }
static int reset_control_bulk_assert(u32, void *) { return failure(XO_ASSERT); }
static int reset_control_bulk_deassert(u32, void *) { return failure(XO_DEASSERT); }
static int dev_pm_genpd_set_hwmode(device *, bool mode) {
    assert(!mode); ++hwmodes; return failure(HWMODE);
}
static int iris_vpu33_2p_quiesce(iris_core *) {
    assert(clocks[2].refs>0); ++quiesces; return failure(QUIESCE);
}
static void iris_hfi_irq_disable(iris_core *core) { core->irq_enabled=false; }
static void iris_hfi_irq_enable(iris_core *core) { core->irq_enabled=true; }
static void iris_vpu_set_preset_registers(iris_core *) {}
static void iris_vpu_interrupt_init(iris_core *) {}
CPP
for function in iris_unset_icc_bw iris_owned_domain_id \
                iris_enable_power_domains iris_disable_power_domains \
                iris_get_clk_by_type iris_prepare_enable_clock iris_disable_unprepare_clock; do
    awk -v f="$function" '$0 ~ "^(static )?(int |struct clk \\*)" f "\\(" {emit=1} emit {gsub("enum platform_clk_type", "platform_clk_type"); print} emit && /^}/ {exit}' \
        "$iris/iris_resources.c" >> "$work/check.cpp"
done
awk '/^#define (AON_WRAPPER_MVP_NOC_CORE|SW_RESET|NOC_HALT|AON_WRAPPER_SPARE)/' \
    "$iris/iris_vpu3x.c" >> "$work/check.cpp"
for function in iris_vpu3x_hw_power_collapsed iris_vpu33_2p_power_off_hardware \
                iris_vpu33_power_off_controller iris_vpu33_2p_power_off_checked; do
    awk -v f="$function" '$0 ~ "^static (int|bool) " f "\\(" {emit=1} emit {print} emit && /^}/ {exit}' \
        "$iris/iris_vpu3x.c" >> "$work/check.cpp"
done
for function in iris_vpu_power_resources_held iris_vpu_power_off iris_vpu_power_on_controller \
                iris_vpu_power_on_hw iris_vpu_power_on; do
    awk -v f="$function" '$0 ~ "^(int|bool) " f "\\(" {emit=1} emit {print} emit && /^}/ {exit}' \
        "$iris/iris_vpu_common.c" >> "$work/check.cpp"
done
cat >> "$work/check.cpp" <<'CPP'
static vpu_ops native_ops{iris_vpu_power_on_controller,iris_vpu_power_on_hw,nullptr,
                         iris_vpu33_power_off_controller,iris_vpu33_2p_power_off_checked};
static platform_clk_data clk_data[]{{IRIS_AXI_CLK,"iface"},{IRIS_CTRL_CLK,"core"},
                                    {IRIS_HW_CLK,"vcodec0_core"}};
static icc_info bandwidth[]{ {1,INT_MAX} };
static platform_data platform{&native_ops,clk_data,3,1,1,bandwidth};
static device pd0{0}, pd1{1}, main_dev{2};
static device *pd_devs[]{&pd0,&pd1};
static domains pds{2,pd_devs};
static clk_bulk_data clock_data[]{{"iface",&clocks[0]},{"core",&clocks[1]},
                                  {"vcodec0_core",&clocks[2]}};
static icc_bulk_data votes[]{{"video-mem",0,0}};
static iris_core core{&main_dev,&platform,&pds,clock_data,3,votes,1,{},
                      reinterpret_cast<u8 *>(regs.data())};
static void reset() {
    checked_core=&core;
    fault=secondary=mmio=quiesces=hwmodes=icc_calls=opp_calls=0;
    stopping=collapsed=icc_request=opp_request=positive_pm=false;
    for (auto& c:clocks) c.refs=c.enabled=c.disabled=0;
    pd0=device{0}; pd1=device{1}; regs.fill(0); votes[0].avg_bw=0;
    platform.vpu_ops=&native_ops; core.power={}; core.power.clk_freq=1000;
    core.state=0; core.irq_enabled=false; pds.num_pds=2;
}
static void running() {
    reset(); assert(iris_vpu_power_on(&core)==0);
    assert(core.power.clock_mask==(BIT(IRIS_AXI_CLK)|BIT(IRIS_CTRL_CLK)|BIT(IRIS_HW_CLK)));
    assert(core.power.domain_mask==3 && pd0.usage==1 && pd1.usage==1);
    assert(core.power.controller_started && core.power.hardware_started && core.irq_enabled);
    assert(icc_request && opp_request);
}
static int stop() { stopping=true; return iris_vpu_power_off(&core); }
static void released() {
    assert(!iris_vpu_power_resources_held(&core));
    assert(!pd0.usage && !pd1.usage && !icc_request && !opp_request && !core.irq_enabled);
    for (auto& c:clocks) assert(c.refs==0 && c.enabled==c.disabled);
}
int main() {
    running(); const int gets=pd0.gets+pd1.gets;
    assert(iris_vpu_power_on(&core)==-EBUSY && pd0.gets+pd1.gets==gets);
    assert(stop()==0); released(); const int accesses=mmio;
    assert(stop()==0 && mmio==accesses); released();
    running(); collapsed=true; assert(stop()==0 && hwmodes==1 && quiesces==0); released();
    reset(); positive_pm=true; assert(iris_vpu_power_on(&core)==0 && pd0.usage==1);
    assert(stop()==0); released();
    for (int stage:{ICC_ON,OPP_ON,CTRL_GET,ON_RESET,AXI_ON,CTRL_ON,HW_GET,HW_ON,OPP_RATE}) {
        reset(); fault=stage; assert(iris_vpu_power_on(&core)==-EUCLEAN);
        assert(core.state==IRIS_CORE_ERROR); released();
    }
    // A partial vote is retained when its cleanup fails; preserve the first error.
    reset(); fault=ICC_ON; secondary=ICC_OFF;
    assert(iris_vpu_power_on(&core)==-EUCLEAN && core.power.icc_voted && icc_request);
    fault=secondary=0; assert(stop()==0); released();
    reset(); fault=OPP_RATE; secondary=HWMODE;
    assert(iris_vpu_power_on(&core)==-EUCLEAN && iris_vpu_power_resources_held(&core));
    fault=secondary=0; assert(stop()==0); released();
    for (int stage:{HWMODE,QUIESCE,HW_PUT,CPU_POLL,DEBUG_POLL,SPARE_POLL,
                    OFF_RESET,XO_ASSERT,XO_DEASSERT,CTRL_PUT,OPP_OFF,ICC_OFF}) {
        running(); fault=stage; assert(stop()==-EUCLEAN && !core.irq_enabled);
        assert(iris_vpu_power_resources_held(&core));
        if (stage==HWMODE || stage==QUIESCE || stage==HW_PUT) {
            assert(pd0.usage==1 && pd1.usage==1 && core.power.domain_mask==3);
            for (const auto& clock:clocks) assert(clock.refs==1);
            assert(opp_request && icc_request);
        } else if (stage>=CPU_POLL && stage<=XO_DEASSERT) {
            assert(pd1.usage==0 && clocks[2].refs==0 && pd0.usage==1);
            assert(clocks[0].refs==1 && clocks[1].refs==1 && core.power.domain_mask==1);
            assert(core.power.controller_started && !core.power.controller_quiesced);
        } else if (stage==CTRL_PUT) {
            assert(!pd1.usage && !clocks[2].refs && !clocks[1].refs);
            assert(pd0.usage==1 && clocks[0].refs==1 && core.power.controller_quiesced);
        } else {
            assert(!core.power.domain_mask && !core.power.clock_mask);
            assert(core.power.icc_voted && (stage==ICC_OFF || core.power.opp_voted));
            if (stage==ICC_OFF) assert(!core.power.opp_voted);
        }
        const int old_quiesces=quiesces, old_mmio=mmio;
        if (stage==HW_PUT || stage==CTRL_PUT) {
            device& pd=stage==HW_PUT ? pd1 : pd0;
            assert(pd.usage==1 && pd.restored==1 && pd.fatal==-EUCLEAN);
            fault=0; assert(stop()==-EUCLEAN && pd.usage==1 && pd.restored==2);
            assert(mmio==old_mmio);
            // The fixture supplies explicit provider recovery; the driver does not clear fatal PM state.
            pd.fatal=0;
        }
        fault=0; assert(stop()==0); released();
        if (stage==HW_PUT) assert(quiesces==old_quiesces);
        if (stage==CTRL_PUT || stage==OPP_OFF || stage==ICC_OFF) assert(mmio==old_mmio);
    }
    reset(); device foreign{3};
    assert(iris_enable_power_domains(&core,&foreign)==-EINVAL);
    pds.num_pds=BITS_PER_LONG+1;
    assert(iris_enable_power_domains(&core,&pd0)==-EINVAL && !pd0.gets);
    pds.num_pds=2;
    assert(iris_prepare_enable_clock(&core,static_cast<platform_clk_type>(BITS_PER_LONG))==-EINVAL);
    assert(iris_disable_unprepare_clock(&core,static_cast<platform_clk_type>(-1))==-EINVAL);
    assert(iris_prepare_enable_clock(&core,IRIS_AHB_CLK)==-ENOENT);
    assert(iris_disable_unprepare_clock(&core,IRIS_AHB_CLK)==0);
    // Legacy VPU35 takes two AXI references, one per subblock.
    vpu_ops legacy=native_ops; legacy.power_off_checked=nullptr; platform.vpu_ops=&legacy;
    assert(iris_prepare_enable_clock(&core,IRIS_AXI_CLK)==0);
    assert(iris_prepare_enable_clock(&core,IRIS_AXI_CLK)==0 && clocks[0].refs==2);
    assert(core.power.clock_mask==0);
    assert(iris_disable_unprepare_clock(&core,IRIS_AXI_CLK)==0 && clocks[0].refs==1);
    assert(iris_disable_unprepare_clock(&core,IRIS_AXI_CLK)==0 && clocks[0].refs==0);
    std::cout << "Actual native Iris power: checked stops, partial votes, retry ownership and legacy references passed\n";
}
CPP
compiler=$(printenv CXX || printf 'g++')
"$compiler" -std=c++20 -O2 -Wall -Wextra -Werror -I"$iris" "$work/check.cpp" -o "$work/check"
"$work/check"
