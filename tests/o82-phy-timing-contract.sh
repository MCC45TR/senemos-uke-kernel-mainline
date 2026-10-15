#!/usr/bin/env bash
# Execute the prepared timing calculator/helper, MMIO writer and host propagation.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
objects=${2:?Pass kernel object tree with generated MSM register headers}
base=$kernel/drivers/gpu/drm/msm/dsi
source_file=$base/phy/dsi_phy_7nm.c
here=$(cd -- "$(dirname -- "$0")" && pwd)
[[ $(rg -c 'compatible = "xiaomi,uke-o82-dsi-phy-4nm", "qcom,sm7675-dsi-phy-4nm";' \
    "$here/../src/display/sm7675-uke-native-display.dtso") == 2 ]]
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
extract() {
    awk -v signature="$1" '
        $0 == signature { emit=1; found=1 }
        emit { print }
        emit && /^}/ { exit }
        END { if (!found) exit 1 }
    ' "$2"
}
cat > "$work/check.cpp" <<'CPP'
#include <algorithm>
#include <array>
#include <cassert>
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <map>
#include <string>
#include <vector>
#define FD_NO_DEPRECATED_PACK
#include "dsi_phy_7nm.xml.h"
#include "dsi.xml.h"
using u8=uint8_t; using u32=uint32_t; using s32=int32_t;
#define BIT(n) (1U<<(n))
#define DBG(...) ((void)0)
#define DRM_DEV_ERROR(dev,...) ((void)(dev))
#define NSEC_PER_MSEC 1000000UL
#define max_t(type,a,b) std::max(static_cast<type>(a),static_cast<type>(b))
#define DIV_ROUND_UP(n,d) (((n)+(d)-1)/(d))
#define mult_frac(x,n,d) ((x)*(n)/(d))
namespace retime { static void check(); }
CPP
{
    sed -n '/^#define DSI_PHY_7NM_QUIRK_/p' "$source_file"
    sed -n '/^#define S_DIV_ROUND_UP/,/^static void dsi_dphy_timing_calc_clk_zero/p' \
        "$base/phy/dsi_phy.c" | sed '$d'
    extract 'struct msm_dsi_phy_shared_timings {' "$base/dsi.h"
    extract 'struct msm_dsi_phy_clk_request {' "$base/dsi.h"
    extract 'struct msm_dsi_dphy_timing {' "$base/phy/dsi_phy.h"
    cat <<'CPP'
struct device_node {const char *compatible;};
struct device {device_node *of_node;};
struct platform_device {device dev;};
struct msm_dsi_phy_cfg {u32 quirks;};
struct msm_dsi_phy {platform_device *pdev; msm_dsi_dphy_timing timing; int id; bool cphy_mode;
    const msm_dsi_phy_cfg *cfg;};
static bool uke=true,sm7675=true;
static bool of_device_is_compatible(device_node *node,const char *name) {
    return node && !std::strcmp(node->compatible,name);
}
static bool of_machine_is_compatible(const char *name) {
    return !std::strcmp(name,"xiaomi,uke") ? uke : sm7675;
}
static std::map<uintptr_t,u32> registers;
static void writel(u32 value,uintptr_t address) {registers[address]=value;}
CPP
    extract 'int msm_dsi_dphy_timing_calc_v4(struct msm_dsi_dphy_timing *timing,' "$base/phy/dsi_phy.c"
    extract 'static int dsi_7nm_uke_o82_timing(struct msm_dsi_phy *phy,' "$source_file"
    cat <<'CPP'
static int msm_dsi_cphy_timing_calc_v4(msm_dsi_dphy_timing *,msm_dsi_phy_clk_request *) {return 0;}
static int calculate(msm_dsi_phy *phy,msm_dsi_phy_clk_request *clk_req) {
    auto *timing=&phy->timing;
    int ret;
CPP
    awk '/^static int dsi_7nm_phy_enable\(struct msm_dsi_phy \*phy,/ {in_phy=1}
         in_phy && /^\tif \(dsi_phy_hw_v4_0_is_pll_on/ {exit}
         in_phy && /^\tif \(phy->cphy_mode\)/ {p=1} p {print}' "$source_file"
    cat <<'CPP'
    return ret;
}
static int write_strength(msm_dsi_phy *phy,msm_dsi_phy_clk_request *clk_req) {
    int ret=calculate(phy,clk_req);
    if(ret) return ret;
    uintptr_t base=0;
    bool less_than_1500_mhz;
    u32 vreg_ctrl_0,vreg_ctrl_1,lane_ctrl0,glbl_pemph_ctrl_0;
    u32 glbl_str_swi_cal_sel_ctrl,glbl_hstx_str_ctrl_0;
    u32 glbl_rescode_top_ctrl,glbl_rescode_bot_ctrl;
CPP
    sed -n '/^\t\/\* Alter PHY configurations if data rate/,/^\tspin_lock_irqsave(&pll->pll_enable_lock, flags);/p' "$source_file" | sed '$d'
    sed -n '/^\t\/\* Enable LDO \*\//,/^\tret = dsi_7nm_set_usecase(phy);/p' "$source_file" | sed '$d'
    cat <<'CPP'
    return 0;
}
static void write_timing(msm_dsi_phy *phy,uintptr_t base) {
    auto *timing=&phy->timing;
CPP
    sed -n '/^\t\/\* DSI PHY timings \*\//,/^\t\/\* DSI lane settings \*\//p' "$source_file" | sed '$d'
    cat <<'CPP'
}
static void copy_shared(msm_dsi_phy *phy,msm_dsi_phy_shared_timings *shared_timings) {
CPP
    sed -n '/^\tmemcpy(shared_timings, &phy->timing.shared_timings,/,+1p' "$base/phy/dsi_phy.c"
    cat <<'CPP'
}
static void dsi_write(void *,u32 address,u32 value) {registers[0x2000+address]=value;}
static void write_host(msm_dsi_phy_shared_timings *phy_shared_timings) {
    void *msm_host=nullptr;
    u32 data;
CPP
    sed -n '/^\tdata = DSI_CLKOUT_TIMING_CTRL_T_CLK_POST/,/dsi_write(msm_host, REG_DSI_CLKOUT_TIMING_CTRL, data);/p' "$base/dsi_host.c"
    cat <<'CPP'
}
int main() {
    device_node node{"xiaomi,uke-o82-dsi-phy-4nm"};
    platform_device platform{{&node}};
    msm_dsi_phy_cfg cfg{DSI_PHY_7NM_QUIRK_V5_2};
    msm_dsi_phy phy{&platform,{},0,false,&cfg};
    msm_dsi_phy_clk_request request{1189188000UL,19200000UL};
    const std::array<u32,14> original{0,0x27,0x0a,0x0c,0x27,0x25,0x0a,0x0b,0x07,2,4,0,0x23,0x1a};
    const std::array<u32,14> expected{0,0x27,0x0a,0x0a,0x1b,0x19,0x0a,0x0b,0x0a,2,4,0,0x20,0x0f};
    assert(msm_dsi_dphy_timing_calc_v4(&phy.timing,&request)==0);
    write_timing(&phy,0);
    for(unsigned i=0;i<original.size();++i) assert(registers.at(0xb4+4*i)==original[i]);
    for(int id:{0,1}) for(unsigned long rate:{1189187000UL,1189188000UL,1189190000UL,1189191000UL}) {
        phy.id=id; request.bitclk_rate=rate;
        assert(msm_dsi_dphy_timing_calc_v4(&phy.timing,&request)==0);
        const bool divider=phy.timing.shared_timings.byte_intf_clk_div_2;
        assert(calculate(&phy,&request)==0);
        registers.clear(); write_timing(&phy,0);
        assert(registers.size()==14);
        for(unsigned i=0;i<expected.size();++i) assert(registers.at(0xb4+4*i)==expected[i]);
        msm_dsi_phy_shared_timings shared{};
        copy_shared(&phy,&shared); write_host(&shared);
        assert(shared.clk_pre==0x20 && shared.clk_post==0x0f);
        assert(shared.byte_intf_clk_div_2==divider && divider);
        assert(!shared.clk_pre_inc_by_2);
        assert(registers.at(0x2000+REG_DSI_CLKOUT_TIMING_CTRL)==0x0f20);
        registers.clear(); assert(write_strength(&phy,&request)==0);
        assert(registers.at(0x10c)==1 && registers.at(0xec)==0xff);
        assert(registers.at(0x104)==0 && registers.at(0x2c)==0x40);
    }
    auto unchanged=[&](int expected_result) {
        std::array<unsigned char,sizeof(phy.timing)> before{};
        std::memcpy(before.data(),&phy.timing,sizeof(phy.timing));
        assert(dsi_7nm_uke_o82_timing(&phy,&request)==expected_result);
        assert(!std::memcmp(before.data(),&phy.timing,sizeof(phy.timing)));
        /* Keep the ~0UL admission fault outside the generic calculator's
         * hardware-clock domain; real boundary rates exercise the writer.
         */
        if(expected_result && request.bitclk_rate!=~0UL) {
            registers.clear();
            assert(write_strength(&phy,&request)==expected_result);
            assert(registers.empty());
        }
    };
    node.compatible="qcom,sm7675-dsi-phy-4nm";
    request.bitclk_rate=1189188000UL;
    assert(msm_dsi_dphy_timing_calc_v4(&phy.timing,&request)==0);
    unchanged(0); registers.clear(); write_timing(&phy,0);
    for(unsigned i=0;i<original.size();++i) assert(registers.at(0xb4+4*i)==original[i]);
    for(u32 quirks:{DSI_PHY_7NM_QUIRK_V4_0,DSI_PHY_7NM_QUIRK_V4_3,DSI_PHY_7NM_QUIRK_V5_2}) {
        cfg.quirks=quirks;
        registers.clear(); assert(write_strength(&phy,&request)==0);
        const bool v4_0=quirks==DSI_PHY_7NM_QUIRK_V4_0;
        assert(registers.at(0x10c)==(v4_0 ? 3U:0));
        assert(registers.at(0xec)==(v4_0 ? 0x66U:0x88U));
        assert(registers.at(0x104)==0 && registers.at(0x2c)==0x40);
    }
    cfg.quirks=DSI_PHY_7NM_QUIRK_V5_2;
    node.compatible="xiaomi,uke-o82-dsi-phy-4nm";
    request.bitclk_rate=0; assert(calculate(&phy,&request)==-EINVAL);
    request.bitclk_rate=1189188000UL;
    phy.cphy_mode=true; assert(calculate(&phy,&request)==-EINVAL); phy.cphy_mode=false;
    phy.cphy_mode=true; unchanged(-EINVAL); phy.cphy_mode=false;
    uke=false; unchanged(-EINVAL); uke=true;
    sm7675=false; unchanged(-EINVAL); sm7675=true;
    phy.id=-1; unchanged(-EINVAL); phy.id=2; unchanged(-EINVAL); phy.id=0;
    for(unsigned long rate:{0UL,1189186999UL,1189191001UL,1189706568UL,1190019600UL,~0UL}) {
        request.bitclk_rate=rate; unchanged(-EINVAL);
    }
    phy.pdev->dev.of_node=nullptr; unchanged(0);
    retime::check();
}
CPP
    cat <<'CPP'
namespace retime {
#define spin_lock_irqsave(lock,flags) ((void)(lock),(flags)=0)
#define spin_unlock_irqrestore(lock,flags) ((void)(lock),(void)(flags))
struct device_node {const char *compatible;};
struct device {device_node *of_node;};
struct platform_device {device dev;};
struct msm_dsi_phy;
struct phy_ops {int (*sync_retime)(msm_dsi_phy *,msm_dsi_phy *,const msm_dsi_phy_clk_request *);};
struct phy_cfg {u32 quirks; phy_ops ops;};
struct msm_dsi_phy {platform_device *pdev; int id; bool cphy_mode;
    uintptr_t base; int usecase; phy_cfg *cfg; void *pll_data;};
struct dsi_pll_7nm {msm_dsi_phy *phy; dsi_pll_7nm *slave; int pclk_mux_lock;};
static std::map<uintptr_t,u32> registers;
static std::vector<std::string> events;
static bool uke=true,sm7675=true;
static int reads;
static bool of_machine_is_compatible(const char *name) {
    return !std::strcmp(name,"xiaomi,uke") ? uke:sm7675;
}
static bool of_device_is_compatible(device_node *node,const char *name) {
    return node && !std::strcmp(node->compatible,name);
}
static u32 readl(uintptr_t address) {++reads; return registers[address];}
static void writel(u32 value,uintptr_t address) {
    registers[address]=value;
    events.push_back(std::to_string(address)+"="+std::to_string(value));
}
static void barrier() {events.emplace_back("wmb");}
#define wmb() barrier()
CPP
    extract 'enum msm_dsi_phy_usecase {' "$base/dsi.h"
    extract 'static void dsi_pll_cmn_clk_cfg1_update(struct dsi_pll_7nm *pll, u32 mask,' "$source_file"
    extract 'static int dsi_7nm_uke_o82_sync_retime(struct msm_dsi_phy *phy,' "$source_file" |
        sed 's/struct dsi_pll_7nm \*pll = phy->pll_data;/struct dsi_pll_7nm *pll = static_cast<dsi_pll_7nm *>(phy->pll_data);/; s/struct dsi_pll_7nm \*peer_pll = peer->pll_data;/struct dsi_pll_7nm *peer_pll = static_cast<dsi_pll_7nm *>(peer->pll_data);/'
    extract 'int msm_dsi_phy_sync_retime(struct msm_dsi_phy *phy, struct msm_dsi_phy *peer,' "$base/phy/dsi_phy.c"
    cat <<'CPP'
static void check() {
    device_node nodes[2]{{"xiaomi,uke-o82-dsi-phy-4nm"},{"xiaomi,uke-o82-dsi-phy-4nm"}};
    platform_device platforms[2]{{{&nodes[0]}},{{&nodes[1]}}};
    phy_cfg cfgs[2]{{DSI_PHY_7NM_QUIRK_V5_2,{dsi_7nm_uke_o82_sync_retime}},
                    {DSI_PHY_7NM_QUIRK_V5_2,{dsi_7nm_uke_o82_sync_retime}}};
    msm_dsi_phy phys[2]{{&platforms[0],0,false,0x1000,MSM_DSI_PHY_MASTER,&cfgs[0],nullptr},
                        {&platforms[1],1,false,0x2000,MSM_DSI_PHY_SLAVE,&cfgs[1],nullptr}};
    dsi_pll_7nm slave{&phys[1],nullptr,0},pll{&phys[0],&slave,0};
    phys[0].pll_data=&pll; phys[1].pll_data=&slave;
    msm_dsi_phy_clk_request request{1189188000UL,19200000UL};
    const uintptr_t cfg0=phys[0].base+REG_DSI_7nm_PHY_CMN_CLK_CFG1;
    const uintptr_t cfg1=phys[1].base+REG_DSI_7nm_PHY_CMN_CLK_CFG1;
    const uintptr_t rbuf0=phys[0].base+REG_DSI_7nm_PHY_CMN_RBUF_CTRL;
    const uintptr_t rbuf1=phys[1].base+REG_DSI_7nm_PHY_CMN_RBUF_CTRL;
    auto write=[](uintptr_t address,u32 value) {return std::to_string(address)+"="+std::to_string(value);};
    auto run=[&](int result,bool changed,u32 initial0=0x30,u32 initial1=0x34) {
        registers={{cfg0,initial0},{cfg1,initial1},{rbuf0,1},{rbuf1,1}};
        const auto before=registers; events.clear(); reads=0;
        assert(msm_dsi_phy_sync_retime(&phys[0],&phys[1],&request)==result);
        if(!changed) {assert(registers==before && events.empty() && !reads); return;}
        assert(registers.size()==before.size() && reads==2);
        for(const auto &[address,value]:before)
            assert(registers.at(address)==((address==cfg0 || address==cfg1) ? value&~0x10U:value));
        const std::vector<std::string> expected{write(rbuf0,0),"wmb",write(rbuf0,1),"wmb",
            write(rbuf1,0),"wmb",write(rbuf1,1),"wmb",write(cfg0,initial0&~0x10U),
            write(cfg1,initial1&~0x10U),"wmb"};
        assert(events==expected);
    };
    for(unsigned long rate:{1189187000UL,1189188000UL,1189190000UL,1189191000UL}) {
        request.bitclk_rate=rate; run(0,true); run(0,true,0xb2,0xf4);
    }
    request.bitclk_rate=1189188000UL;
    uke=false; run(-EINVAL,false); uke=true;
    sm7675=false; run(-EINVAL,false); sm7675=true;
    for(int id:{0,1}) {
        nodes[id].compatible="qcom,sm7675-dsi-phy-4nm"; run(-EINVAL,false);
        nodes[id].compatible="xiaomi,uke-o82-dsi-phy-4nm";
        phys[id].cphy_mode=true; run(-EINVAL,false); phys[id].cphy_mode=false;
        platforms[id].dev.of_node=nullptr; run(-EINVAL,false); platforms[id].dev.of_node=&nodes[id];
        cfgs[id].quirks=0; run(-EINVAL,false); cfgs[id].quirks=DSI_PHY_7NM_QUIRK_V5_2;
        cfgs[id].ops.sync_retime=nullptr; run(-EINVAL,false);
        cfgs[id].ops.sync_retime=dsi_7nm_uke_o82_sync_retime;
        const int usecase=phys[id].usecase;
        phys[id].usecase=MSM_DSI_PHY_STANDALONE; run(-EINVAL,false); phys[id].usecase=usecase;
        void *saved=phys[id].pll_data;
        phys[id].pll_data=nullptr; run(-EINVAL,false); phys[id].pll_data=saved;
    }
    phys[0].id=1; run(-EINVAL,false); phys[0].id=0;
    phys[1].id=0; run(-EINVAL,false); phys[1].id=1;
    pll.slave=nullptr; run(-EINVAL,false); pll.slave=&slave;
    for(unsigned long rate:{0UL,1189186999UL,1189191001UL,2500000000UL,~0UL}) {
        request.bitclk_rate=rate; run(-EINVAL,false);
    }
    nodes[0].compatible=nodes[1].compatible="qcom,sm7675-dsi-phy-4nm";
    run(-EINVAL,false);
    cfgs[0].ops.sync_retime=cfgs[1].ops.sync_retime=nullptr; run(-EOPNOTSUPP,false);
    assert(msm_dsi_phy_sync_retime(nullptr,&phys[1],&request)==-EINVAL);
    assert(msm_dsi_phy_sync_retime(&phys[0],nullptr,&request)==-EINVAL);
    assert(msm_dsi_phy_sync_retime(&phys[0],&phys[1],nullptr)==-EINVAL);
}
}
CPP
} >> "$work/check.cpp"
"${CXX:-c++}" -std=c++20 -O2 -Wall -Wextra -Werror \
    -fsanitize=undefined -fsanitize-undefined-trap-on-error \
    -I "$objects/drivers/gpu/drm/msm/generated" "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'O82 PHY: exact timing/strength and post-link pair FIFO/clock-select order; unsupported or mismatched pairs refuse with no register access\n'
