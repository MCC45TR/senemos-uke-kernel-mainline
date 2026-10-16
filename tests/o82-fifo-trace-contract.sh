#!/usr/bin/env bash
# Execute passive O82 host/PLL diagnostics; no target access.
set -Eeuo pipefail
host=${1:?Pass candidate dsi_host.c}
phy=${2:?Pass candidate dsi_phy_7nm.c}
objects=${3:?Pass kernel object directory}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
extract() {
    awk -v signature="$1" '
        index($0, signature)==1 {emit=1; found=1}
        emit {print}
        emit && /^}/ {exit}
        END {if (!found) exit 1}
    ' "$2"
}
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>
#define FD_NO_DEPRECATED_PACK
#include "dsi.xml.h"
using u8=uint8_t;using u32=uint32_t;
#define READ_ONCE(v) (v)
#define MIPI_DSI_FMT_RGB101010 4
#define MIPI_DSI_MODE_VIDEO 1
#define MIPI_DSI_MSG_USE_LPM 2
struct device_node {bool pb=true,isolated=true,phy=true;};
struct device {device_node *of_node;};
struct platform_device {device dev;};
struct drm_display_mode {int hdisplay=3200,vdisplay=2136,hz=120,clock=967428,htotal=3490,vtotal=2310;};
struct mipi_dsi_msg {u8 type=0x39;unsigned flags=1;size_t tx_len=2;const void *tx_buf;};
struct mipi_dsi_host {void *owner;};
struct msm_dsi_host;
struct clock_ops {void (*link_clk_set_rate)(msm_dsi_host *);void (*link_clk_enable)(msm_dsi_host *);};
struct msm_dsi_cfg_handler {clock_ops *ops;};
struct msm_dsi_host {
    platform_device *pdev;drm_display_mode *mode;
    bool power_on=true,cmd_dma_blocked=false,cphy_mode=false;
    unsigned lanes=4,format=MIPI_DSI_FMT_RGB101010,mode_flags=MIPI_DSI_MODE_VIDEO;
    u8 uke_fifo_trace_xfers=0;
    bool enabled=true;
    msm_dsi_cfg_handler *cfg_hnd=nullptr;
    u32 dma_cmd_ctrl_restore=0;
};
static bool scope=true,uke=true,sm7675=true;
static device_node node;static device_node *remote=&node;
static unsigned reads,node_gets,node_puts;
static std::vector<std::string> logs,events;
static msm_dsi_host *to_msm_dsi_host(mipi_dsi_host *host) {return static_cast<msm_dsi_host *>(host->owner);}
static void pm_runtime_get_sync(device *) {events.emplace_back("pm-get");}
static void set_rate(msm_dsi_host *) {events.emplace_back("set-rate");}
static void enable_clk(msm_dsi_host *) {events.emplace_back("clk-enable");}
static void dsi_set_tx_power_mode(int mode,msm_dsi_host *) {assert(!mode);events.emplace_back("hs");}
static void dsi_write(msm_dsi_host *,u32 reg,u32 value) {
    assert(reg==REG_DSI_CTRL&&value==0x1f7);events.emplace_back("ctrl-enable");
}
static void dsi_intr_ctrl(msm_dsi_host *,int irq,int enable) {
    assert(irq==DSI_IRQ_MASK_CMD_DMA_DONE&&enable==1);events.emplace_back("irq-enable");
}
static bool dsi_uke_misr_scope(msm_dsi_host *) {return scope;}
static int drm_mode_vrefresh(drm_display_mode *m) {return m->hz;}
static device_node *of_graph_get_remote_node(device_node *n,int port,int endpoint) {
    assert(n==&node&&port==1&&endpoint==-1);++node_gets;return remote;
}
static void of_node_put(device_node *n) {assert(n==remote);++node_puts;}
static bool of_device_is_compatible(device_node *n,const char *name) {
    if(!std::strcmp(name,"xiaomi,o82-42-02-0b"))return n&&n->pb;
    assert(!std::strcmp(name,"xiaomi,uke-o82-dsi-phy-4nm"));return n&&n->phy;
}
static bool of_property_read_bool(device_node *n,const char *name) {
    assert(n&&!std::strcmp(name,"xiaomi,initial-120hz-only"));return n->isolated;
}
static bool of_machine_is_compatible(const char *name) {
    if(!std::strcmp(name,"xiaomi,uke"))return uke;
    assert(!std::strcmp(name,"qcom,sm7675"));return sm7675;
}
static u32 dsi_read(msm_dsi_host *,u32 reg) {
    ++reads;
    switch(reg) {
    case REG_DSI_CTRL:return 0x1f3;
    case REG_DSI_FIFO_STATUS:return 0x44441310;
    case REG_DSI_ERR_INT_MASK0:return 0x13ff3be0;
    case REG_DSI_TIMEOUT_STATUS:return 1;
    case REG_DSI_ACK_ERR_STATUS:return 2;
    case REG_DSI_INTR_CTRL:return 3;
    case REG_DSI_STATUS0:return 8;
    case REG_DSI_CLK_STATUS:return 0x47c3;
    default:assert(false);return 0;
    }
}
static void record(device *,const char *fmt,...) {
    char line[512];va_list args;va_start(args,fmt);
    std::vsnprintf(line,sizeof(line),fmt,args);va_end(args);logs.emplace_back(line);
}
#define dev_info record
#define DBG(...) ((void)0)
struct msm_dsi_phy {platform_device *pdev;bool pll_on;};
struct dsi_pll_7nm {msm_dsi_phy *phy;unsigned long vco_current_rate;};
struct clk_hw {dsi_pll_7nm *pll;};
struct dsi_pll_config {};
static dsi_pll_7nm *to_pll_7nm(clk_hw *hw) {return hw->pll;}
static void dsi_pll_enable_pll_bias(dsi_pll_7nm *) {events.emplace_back("bias-on");}
static void dsi_pll_setup_config(dsi_pll_config *) {events.emplace_back("setup");}
static void dsi_pll_calc_dec_frac(dsi_pll_7nm *,dsi_pll_config *) {events.emplace_back("frac");}
static void dsi_pll_calc_ssc(dsi_pll_7nm *,dsi_pll_config *) {events.emplace_back("ssc");}
static void dsi_pll_commit(dsi_pll_7nm *,dsi_pll_config *) {events.emplace_back("commit");}
static void dsi_pll_config_hzindep_reg(dsi_pll_7nm *) {events.emplace_back("hzindep");}
static void dsi_pll_ssc_commit(dsi_pll_7nm *,dsi_pll_config *) {events.emplace_back("ssc-commit");}
static void dsi_pll_disable_pll_bias(dsi_pll_7nm *) {events.emplace_back("bias-off");}
static void wmb() {events.emplace_back("barrier");}
CPP
{
extract 'static bool dsi_uke_o82_initial120(' "$host"
extract 'static void dsi_uke_fifo_trace(' "$host"
extract 'int msm_dsi_host_xfer_prepare(' "$host"
extract 'static int dsi_pll_7nm_vco_set_rate(' "$phy"
cat <<'CPP'
int main() {
    platform_device p{{&node}};drm_display_mode mode;msm_dsi_host h{&p,&mode};
    const u8 payload[]={0xff,0x10};mipi_dsi_msg msg{0x39,1,2,payload};
    auto reset=[&] {reads=node_gets=node_puts=0;logs.clear();h.uke_fifo_trace_xfers=0;};
    auto sample=[&] {dsi_uke_fifo_trace(&h,&msg,"prepare-before",true);};
    sample();assert(logs.size()==1&&reads==8&&node_gets==node_puts&&h.uke_fifo_trace_xfers==1);
    assert(logs[0].find("seq=1 stage=prepare-before type=0x39 op=0xff len=2")!=std::string::npos);
    assert(logs[0].find("fifo=0x44441310 mask=0x13ff3be0")!=std::string::npos);
#define REFUSE(field,value) do {auto old=(field);reset();(field)=(value);sample();assert(logs.empty()&&reads==0&&node_gets==node_puts&&h.uke_fifo_trace_xfers==0);(field)=old;}while(0)
    REFUSE(scope,false);REFUSE(h.power_on,false);REFUSE(h.cmd_dma_blocked,true);
    REFUSE(h.mode,nullptr);REFUSE(mode.hdisplay,3199);REFUSE(mode.vdisplay,2135);
    REFUSE(mode.hz,60);REFUSE(h.cphy_mode,true);REFUSE(h.lanes,3);
    REFUSE(mode.clock,967427);REFUSE(mode.htotal,3489);REFUSE(mode.vtotal,2309);
    REFUSE(h.format,0);REFUSE(h.mode_flags,0);REFUSE(node.pb,false);
    REFUSE(node.isolated,false);REFUSE(remote,nullptr);
    reset();
    for(unsigned i=0;i<24;++i) {
        sample();dsi_uke_fifo_trace(&h,&msg,"prepare-after",false);
        dsi_uke_fifo_trace(&h,&msg,"restore-before",false);
        dsi_uke_fifo_trace(&h,&msg,"restore-after",false);
    }
    assert(logs.size()==96&&reads==96*8&&h.uke_fifo_trace_xfers==24);
    sample();for(int i=0;i<30;++i)sample();
    dsi_uke_fifo_trace(&h,&msg,"restore-before",false);
    dsi_uke_fifo_trace(&h,nullptr,"video-after",false);
    assert(logs.size()==96&&reads==96*8&&h.uke_fifo_trace_xfers==25);
    reset();dsi_uke_fifo_trace(&h,&msg,"restore-before",false);assert(logs.empty());
    dsi_uke_fifo_trace(&h,nullptr,"video-before",false);
    dsi_uke_fifo_trace(&h,nullptr,"video-after",false);
    assert(logs.size()==2&&reads==16&&h.uke_fifo_trace_xfers==0);
    reset();msg.tx_buf=nullptr;msg.tx_len=0;sample();assert(logs.size()==1);
    assert(logs[0].find("op=0 len=0")!=std::string::npos);
    msm_dsi_phy phy{&p,true};dsi_pll_7nm pll{&phy,0};clk_hw hw{&pll};
    const std::vector<std::string> expected={"bias-on","setup","frac","ssc","commit","hzindep","ssc-commit","bias-off","barrier"};
    auto rate=[&](bool expect_log) {
        logs.clear();events.clear();assert(!dsi_pll_7nm_vco_set_rate(&hw,1189188000UL,19200000UL));
        assert(events==expected&&pll.vco_current_rate==1189188000UL);
        assert(logs.size()==(expect_log?1U:0U));
        if(expect_log)assert(logs[0].find("rate=1189188000 parent=19200000 pll_on=1")!=std::string::npos);
    };
    rate(true);uke=false;rate(false);uke=true;sm7675=false;rate(false);sm7675=true;
    node.phy=false;rate(false);node.phy=true;rate(true);

    clock_ops ops{set_rate,enable_clk};msm_dsi_cfg_handler cfg{&ops};h.cfg_hnd=&cfg;
    mipi_dsi_host base{&h};msg.tx_buf=payload;msg.tx_len=2;
    auto prepare=[&](bool preserve,bool lpm) {
        events.clear();msg.flags=lpm?MIPI_DSI_MSG_USE_LPM:0;
        assert(!msm_dsi_host_xfer_prepare(&base,&msg));
        std::vector<std::string> want={"pm-get"};
        if(!preserve)want.emplace_back("set-rate");
        want.emplace_back("clk-enable");if(!lpm)want.emplace_back("hs");
        want.emplace_back("ctrl-enable");want.emplace_back("irq-enable");
        assert(events==want&&h.dma_cmd_ctrl_restore==0x1f3);
        assert(node_gets==node_puts);
    };
    prepare(true,false);prepare(true,true);
#define ORDINARY(field,value) do {auto old=(field);(field)=(value);prepare(false,false);(field)=old;}while(0)
    ORDINARY(h.enabled,false);ORDINARY(h.power_on,false);ORDINARY(h.cmd_dma_blocked,true);
    ORDINARY(scope,false);ORDINARY(node.pb,false);ORDINARY(node.isolated,false);
    ORDINARY(remote,nullptr);ORDINARY(h.mode,nullptr);ORDINARY(mode.hz,60);
    ORDINARY(mode.clock,967427);ORDINARY(mode.htotal,3489);ORDINARY(mode.vtotal,2309);
    ORDINARY(h.lanes,3);ORDINARY(h.format,0);ORDINARY(h.cphy_mode,true);ORDINARY(h.mode_flags,0);
    prepare(true,false);
}
CPP
} >> "$work/check.cpp"
"${CXX:-c++}" -std=c++17 -O2 -Wall -Wextra -Werror -fsanitize=undefined \
    -fsanitize-undefined-trap-on-error -I "$objects/drivers/gpu/drm/msm/generated" \
    "$work/check.cpp" -o "$work/check"
"$work/check"
[[ $(rg -c '^[[:space:]]*dsi_uke_fifo_trace\(' "$host") == 6 ]]
printf 'Actual O82 diagnostics and transfer clock preservation: bounded logs, active-video rate exclusion, unchanged PM/clock votes/command writes and ordinary-profile rate setup passed\n'
