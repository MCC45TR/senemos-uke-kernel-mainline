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
#define FD_NO_DEPRECATED_PACK
#include "dsi_phy_7nm.xml.h"
#include "dsi.xml.h"
using u8=uint8_t; using u32=uint32_t; using s32=int32_t;
#define DBG(...) ((void)0)
#define DRM_DEV_ERROR(dev,...) ((void)(dev))
#define NSEC_PER_MSEC 1000000UL
#define max_t(type,a,b) std::max(static_cast<type>(a),static_cast<type>(b))
#define DIV_ROUND_UP(n,d) (((n)+(d)-1)/(d))
#define mult_frac(x,n,d) ((x)*(n)/(d))
CPP
{
    sed -n '/^#define S_DIV_ROUND_UP/,/^static void dsi_dphy_timing_calc_clk_zero/p' \
        "$base/phy/dsi_phy.c" | sed '$d'
    extract 'struct msm_dsi_phy_shared_timings {' "$base/dsi.h"
    extract 'struct msm_dsi_phy_clk_request {' "$base/dsi.h"
    extract 'struct msm_dsi_dphy_timing {' "$base/phy/dsi_phy.h"
    cat <<'CPP'
struct device_node {const char *compatible;};
struct device {device_node *of_node;};
struct platform_device {device dev;};
struct msm_dsi_phy {platform_device *pdev; msm_dsi_dphy_timing timing; int id; bool cphy_mode;};
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
    extract 'static int dsi_7nm_phy_enable(struct msm_dsi_phy *phy,' "$source_file" | \
        awk '/^\tif \(dsi_phy_hw_v4_0_is_pll_on/ {exit}
             /^\tif \(phy->cphy_mode\)/ {p=1} p {print}'
    cat <<'CPP'
    return ret;
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
    msm_dsi_phy phy{&platform,{},0,false};
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
    }
    auto unchanged=[&](int expected_result) {
        std::array<unsigned char,sizeof(phy.timing)> before{};
        std::memcpy(before.data(),&phy.timing,sizeof(phy.timing));
        assert(dsi_7nm_uke_o82_timing(&phy,&request)==expected_result);
        assert(!std::memcmp(before.data(),&phy.timing,sizeof(phy.timing)));
    };
    node.compatible="qcom,sm7675-dsi-phy-4nm";
    request.bitclk_rate=1189188000UL;
    assert(msm_dsi_dphy_timing_calc_v4(&phy.timing,&request)==0);
    unchanged(0); registers.clear(); write_timing(&phy,0);
    for(unsigned i=0;i<original.size();++i) assert(registers.at(0xb4+4*i)==original[i]);
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
}
CPP
} >> "$work/check.cpp"
"${CXX:-c++}" -std=c++20 -O2 -Wall -Wextra -Werror \
    -fsanitize=undefined -fsanitize-undefined-trap-on-error \
    -I "$objects/drivers/gpu/drm/msm/generated" "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'O82 PHY: real v4 calculation, exact 14 OEM cells, both links, host shared timings, unchanged generic path and refusal boundaries passed\n'
