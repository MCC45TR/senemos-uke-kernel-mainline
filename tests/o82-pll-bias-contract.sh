#!/usr/bin/env bash
# Execute the prepared bias gate and shared bias functions; no target access.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
objects=${2:?Pass kernel object tree with generated MSM register headers}
source_file=$kernel/drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
extract() {
    awk -v signature="$1" '
        $0 == signature {emit=1; found=1}
        emit {print}
        emit && /^}/ {exit}
        END {if (!found) exit 1}
    ' "$2"
}
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <climits>
#include <cstdint>
#include <cstring>
#include <map>
#include <string>
#include <utility>
#include <vector>
#define FD_NO_DEPRECATED_PACK
#include "dsi_phy_7nm.xml.h"
using u32=uint32_t;
struct device_node {const char *compatible;};
struct device {device_node *of_node;};
struct platform_device {device dev;};
struct msm_dsi_phy {platform_device *pdev;uintptr_t base,pll_base;
    int id,usecase;bool cphy_mode;};
struct dsi_pll_7nm {msm_dsi_phy *phy;int pll_enable_lock,pll_enable_cnt;};
static bool uke=true,sm7675=true,locked;
static unsigned warnings,errors;
static std::map<uintptr_t,u32> registers;
static std::vector<std::string> events;
static std::vector<std::pair<uintptr_t,u32>> writes;
static bool of_machine_is_compatible(const char *name) {
    assert(!locked);
    if (!std::strcmp(name,"xiaomi,uke"))return uke;
    assert(!std::strcmp(name,"qcom,sm7675"));return sm7675;
}
static bool of_device_is_compatible(device_node *node,const char *name) {
    assert(!locked);return node && !std::strcmp(node->compatible,name);
}
static u32 readl(uintptr_t address) {
    assert(locked && registers.count(address));events.emplace_back("read");
    return registers.at(address);
}
static void writel(u32 value,uintptr_t address) {
    assert(locked && registers.count(address));events.emplace_back("write");
    registers[address]=value;writes.emplace_back(address,value);
}
static void ndelay(unsigned ns) {
    assert(!locked && ns==250);events.emplace_back("delay250");
}
static void warning(bool condition) {assert(!locked);warnings+=condition;}
#define WARN_ON(condition) warning(condition)
#define DRM_DEV_ERROR_RATELIMITED(dev,...) ((void)(dev),assert(!locked),++errors)
#define spin_lock_irqsave(lock,flags) do {(void)(lock);(flags)=0;assert(!locked);locked=true;events.emplace_back("lock");}while(0)
#define spin_unlock_irqrestore(lock,flags) do {(void)(lock);(void)(flags);assert(locked);locked=false;events.emplace_back("unlock");}while(0)
CPP
{
    extract 'enum msm_dsi_phy_usecase {' "$kernel/drivers/gpu/drm/msm/dsi/dsi.h"
    extract 'static bool dsi_pll_7nm_uke_o82_bias_replay(struct dsi_pll_7nm *pll)' "$source_file"
    extract 'static void dsi_pll_enable_pll_bias(struct dsi_pll_7nm *pll)' "$source_file"
    extract 'static void dsi_pll_disable_pll_bias(struct dsi_pll_7nm *pll)' "$source_file"
    cat <<'CPP'
static device_node node{"xiaomi,uke-o82-dsi-phy-4nm"};
static platform_device platform{{&node}};
static msm_dsi_phy phy{&platform,0x1000,0x2000,0,MSM_DSI_PHY_MASTER,false};
static dsi_pll_7nm pll{&phy,0,0};
static constexpr uintptr_t ctrl=0x1000+REG_DSI_7nm_PHY_CMN_CTRL_0;
static constexpr uintptr_t mux=0x2000+REG_DSI_7nm_PHY_PLL_SYSTEM_MUXES;
static void reset(int count) {
    assert(!locked);warnings=errors=0;events.clear();writes.clear();
    registers={{ctrl,0x5f},{mux,0x99}};pll.pll_enable_cnt=count;
}
static void enabled_writes() {
    assert(events==std::vector<std::string>({"lock","read","write","write","unlock","delay250"}));
    assert((writes==std::vector<std::pair<uintptr_t,u32>>({{ctrl,0x7f},{mux,0xc0}})));
    assert(!locked && !warnings && !errors);
}
static void skipped() {
    assert(events==std::vector<std::string>({"lock","unlock"}));
    assert(writes.empty() && registers.at(ctrl)==0x5f && registers.at(mux)==0x99);
    assert(!locked);
}
static void ordinary() {
    assert(!dsi_pll_7nm_uke_o82_bias_replay(&pll));
    reset(1);dsi_pll_enable_pll_bias(&pll);assert(pll.pll_enable_cnt==2);skipped();
    assert(!warnings && !errors);
    reset(0);dsi_pll_enable_pll_bias(&pll);assert(pll.pll_enable_cnt==1);enabled_writes();
}
int main() {
    for(int id=0;id<2;id++) {
        phy.id=id;phy.usecase=id ? MSM_DSI_PHY_SLAVE:MSM_DSI_PHY_MASTER;
        assert(dsi_pll_7nm_uke_o82_bias_replay(&pll));
        for(int count:{0,1,2,9}) {
            reset(count);dsi_pll_enable_pll_bias(&pll);
            assert(pll.pll_enable_cnt==count+1);enabled_writes();
        }
    }
    phy.id=0;phy.usecase=MSM_DSI_PHY_MASTER;
    for(bool matching:{false,true}) {
    uke=matching;
    reset(0);dsi_pll_enable_pll_bias(&pll);assert(pll.pll_enable_cnt==1);
    events.clear();writes.clear();dsi_pll_enable_pll_bias(&pll);
    assert(pll.pll_enable_cnt==2 && writes.size()==(matching ? 2U:0U));
    events.clear();writes.clear();dsi_pll_disable_pll_bias(&pll);
    assert(pll.pll_enable_cnt==1 && writes.empty());
    assert(events==std::vector<std::string>({"lock","unlock"}));
    events.clear();dsi_pll_disable_pll_bias(&pll);assert(pll.pll_enable_cnt==0);
    assert(events==std::vector<std::string>({"lock","read","write","write","unlock","delay250"}));
    assert((writes==std::vector<std::pair<uintptr_t,u32>>({{mux,0},{ctrl,0x5f}})));
    assert(!warnings && !errors && !locked);
    }
    uke=true;

    uke=false;ordinary();uke=true;
    sm7675=false;ordinary();sm7675=true;
    node.compatible="qcom,sm7675-dsi-phy-4nm";ordinary();node.compatible="xiaomi,uke-o82-dsi-phy-4nm";
    phy.cphy_mode=true;ordinary();phy.cphy_mode=false;
    for(int id:{-1,0,1,2}) for(int usecase:{MSM_DSI_PHY_STANDALONE,MSM_DSI_PHY_MASTER,MSM_DSI_PHY_SLAVE}) {
        if((id==0&&usecase==MSM_DSI_PHY_MASTER)||(id==1&&usecase==MSM_DSI_PHY_SLAVE))continue;
        phy.id=id;phy.usecase=usecase;ordinary();
    }
    phy.id=0;phy.usecase=MSM_DSI_PHY_MASTER;
    // Match upstream warning/invalid-count behavior, including kernel wraparound.
    for(bool matching:{false,true}) {
        uke=matching;
        for(int count:{-2,-1,INT_MAX-1,INT_MAX}) {
            reset(count);dsi_pll_enable_pll_bias(&pll);
            assert(pll.pll_enable_cnt==(count==INT_MAX ? INT_MIN:count+1));
            skipped();assert(warnings==unsigned(count==INT_MAX-1) && !errors);
        }
        reset(0);dsi_pll_disable_pll_bias(&pll);
        assert(pll.pll_enable_cnt==-1 && errors==1 && !warnings);skipped();
    }
}
CPP
} >> "$work/check.cpp"
# Kernel C uses wraparound arithmetic; preserve that baseline in the host fixture.
"${CXX:-c++}" -std=c++17 -O2 -Wall -Wextra -Werror -fwrapv \
    -fsanitize=undefined -fsanitize-undefined-trap-on-error \
    -I "$objects/drivers/gpu/drm/msm/generated" "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual O82 bias gate/functions: exact master/slave replay, ordinary zero/positive behavior, nested drops, store/lock/delay order and invalid/warning/overflow baseline passed\n'
