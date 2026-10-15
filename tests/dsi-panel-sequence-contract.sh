#!/usr/bin/env bash
# Execute the prepared DSI manager callbacks with host-only fault injection.
set -Eeuo pipefail
manager=${1:?Pass prepared dsi_manager.c with the O82 sequence candidate}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
extract() {
    awk -v signature="$1" '
        $0 == signature { emit=1; found=1 }
        emit { print }
        emit && /^}/ { exit }
        END { if (!found) exit 1 }
    ' "$manager"
}
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cstddef>
#include <cstring>
#include <string>
#include <vector>
#define DSI_1 1
#define DSI_MAX 2
#define MIPI_DSI_MODE_VIDEO 1
#define container_of(ptr,type,member) ((type *)((char *)(ptr)-offsetof(type,member)))
#define DBG(...) ((void)0)
#define dev_err(dev,...) ((void)(dev))
#define pr_err(...) ((void)0)
struct drm_bridge {};
struct drm_panel { bool prepared; } panel;
struct device_node { const char *compatible; } remote{"xiaomi,o82-36-02-0a"};
struct device { device_node *of_node; };
struct platform_device { device dev; } platform;
struct mipi_dsi_host { int id; unsigned long flags; } hosts[2]{{0,1},{1,1}};
struct msm_dsi_phy_shared_timings {};
struct msm_dsi { platform_device *pdev; mipi_dsi_host *host; int phy; } devices[2]{{&platform,&hosts[0],0},{&platform,&hosts[1],1}};
static bool bonded=true,uke=true,sm7675=true,missing_node=false;
static int master=0,node_puts=0;
static drm_panel *found_panel=&panel;
static std::string fault;
static std::vector<std::string> events;
static int event(const std::string &name) { events.push_back(name); return fault==name ? -5 : 0; }
static std::string link(const char *name, mipi_dsi_host *host) { return std::string(name)+std::to_string(host->id); }
#define IS_BONDED_DSI() bonded
#define IS_MASTER_DSI_LINK(id) (master==(id))
static msm_dsi *dsi_mgr_get_dsi(int id) { return &devices[id]; }
static int dsi_mgr_phy_enable(int,msm_dsi_phy_shared_timings *) { return event("phy_on"); }
static void dsi_mgr_phy_disable(int) { event("phy_off"); }
static int msm_dsi_host_power_on(mipi_dsi_host *host,msm_dsi_phy_shared_timings *,bool,int) { return event(link("power",host)); }
static int msm_dsi_host_power_off(mipi_dsi_host *host) { return event(link("off",host)); }
static void msm_dsi_host_enable_irq(mipi_dsi_host *host) { event(link("irq",host)); }
static void msm_dsi_host_disable_irq(mipi_dsi_host *host) { event(link("noirq",host)); }
static int msm_dsi_host_enable(mipi_dsi_host *host) { return event(link("video",host)); }
static int msm_dsi_host_disable(mipi_dsi_host *host) { return event(link("stop",host)); }
static void msm_dsi_phy_pll_save_state(int) { event("save_pll"); }
static bool of_machine_is_compatible(const char *name) { return !strcmp(name,"xiaomi,uke") ? uke : sm7675; }
static unsigned long msm_dsi_host_get_mode_flags(mipi_dsi_host *host) { return host->flags; }
static device_node *of_graph_get_remote_node(device_node *,int,int) { return missing_node ? nullptr : &remote; }
static bool of_device_is_compatible(device_node *node,const char *name) { return node && !strcmp(node->compatible,name); }
static drm_panel *of_drm_find_panel(device_node *) { return found_panel; }
static void of_node_put(device_node *node) { if(node) ++node_puts; }
CPP
{
    extract 'struct dsi_bridge {'
    printf '#define to_dsi_bridge(x) container_of(x, struct dsi_bridge, base)\n'
    for callback in \
        'static int dsi_mgr_bridge_get_id(struct drm_bridge *bridge)' \
        'static int dsi_mgr_bridge_power_on(struct drm_bridge *bridge)' \
        'static void dsi_mgr_bridge_power_off(struct drm_bridge *bridge)' \
        'static int dsi_mgr_bridge_enable_hosts(struct drm_bridge *bridge)' \
        'static void dsi_mgr_bridge_pre_enable(struct drm_bridge *bridge)' \
        'static void dsi_mgr_bridge_enable(struct drm_bridge *bridge)' \
        'static void dsi_mgr_bridge_disable(struct drm_bridge *bridge)' \
        'static void dsi_mgr_bridge_post_disable(struct drm_bridge *bridge)' \
        'static struct drm_panel *dsi_mgr_o82_panel(struct msm_dsi *msm_dsi)'; do
        extract "$callback"
    done
    cat <<'CPP'
static void expect(std::initializer_list<const char *> expected) {
    std::vector<std::string> wanted;
    for (const char *name : expected) wanted.emplace_back(name);
    assert(events==wanted);
    events.clear();
}
static void prepare(bool success=true) {
    event("reset"); event("panel_on"); event("pps"); panel.prepared=success;
}
static void unprepare() { event("panel_off"); panel.prepared=false; }
int main() {
    for (const char *compatible : {"xiaomi,o82-36-02-0a","xiaomi,o82-42-02-0b"}) {
        remote.compatible=compatible;
        assert(dsi_mgr_o82_panel(&devices[0])==&panel);
    }
    assert(node_puts==2);
    uke=false; assert(dsi_mgr_o82_panel(&devices[0])==nullptr); uke=true;
    sm7675=false; assert(dsi_mgr_o82_panel(&devices[0])==nullptr); sm7675=true;
    hosts[0].flags=0; assert(dsi_mgr_o82_panel(&devices[0])==nullptr); hosts[0].flags=1;
    remote.compatible="xiaomi,another-panel"; assert(dsi_mgr_o82_panel(&devices[0])==nullptr);
    remote.compatible="xiaomi,o82-36-02-0a";
    missing_node=true; assert(dsi_mgr_o82_panel(&devices[0])==nullptr); missing_node=false;
    found_panel=reinterpret_cast<drm_panel *>(-517L);
    assert(dsi_mgr_o82_panel(&devices[0])==found_panel); found_panel=&panel;

    dsi_bridge bridge{{},0,&panel,false,false};
    dsi_mgr_bridge_enable(&bridge.base); expect({});
    dsi_mgr_bridge_pre_enable(&bridge.base);
    expect({"phy_on","power0","power1","irq0","irq1"});
    dsi_mgr_bridge_enable(&bridge.base); expect({});
    prepare(); dsi_mgr_bridge_enable(&bridge.base);
    expect({"reset","panel_on","pps","video0","video1"});
    assert(bridge.video_enabled);
    dsi_mgr_bridge_disable(&bridge.base); unprepare();
    dsi_mgr_bridge_post_disable(&bridge.base);
    expect({"stop1","stop0","panel_off","save_pll","noirq0","noirq1","off1","off0","phy_off"});
    assert(!bridge.powered && !bridge.video_enabled);
    dsi_mgr_bridge_disable(&bridge.base); dsi_mgr_bridge_post_disable(&bridge.base); expect({});

    // Every host/PHY power failure must suppress the later enable callback.
    for (const char *failure : {"phy_on","power0","power1"}) {
        fault=failure; dsi_mgr_bridge_pre_enable(&bridge.base);
        panel.prepared=true; dsi_mgr_bridge_enable(&bridge.base);
        assert(!bridge.powered && !bridge.video_enabled);
        for (const auto &name : events) assert(name!="video0" && name!="video1");
        if (fault=="phy_on") expect({"phy_on"});
        else if (fault=="power0") expect({"phy_on","power0","phy_off"});
        else expect({"phy_on","power0","power1","off0","phy_off"});
        dsi_mgr_bridge_post_disable(&bridge.base); expect({});
        panel.prepared=false;
    }
    fault.clear(); dsi_mgr_bridge_pre_enable(&bridge.base); events.clear();
    prepare(false); dsi_mgr_bridge_enable(&bridge.base);
    expect({"reset","panel_on","pps"});
    dsi_mgr_bridge_post_disable(&bridge.base);
    expect({"save_pll","noirq0","noirq1","off1","off0","phy_off"});

    // Failed second video enable unwinds the first, keeping command power for OFF.
    dsi_mgr_bridge_pre_enable(&bridge.base); events.clear(); prepare(); events.clear();
    fault="video1"; dsi_mgr_bridge_enable(&bridge.base);
    expect({"video0","video1","stop0"});
    assert(!bridge.video_enabled && bridge.powered);
    fault.clear(); unprepare(); dsi_mgr_bridge_post_disable(&bridge.base);
    expect({"panel_off","save_pll","noirq0","noirq1","off1","off0","phy_off"});
    dsi_mgr_bridge_pre_enable(&bridge.base); events.clear(); prepare(); events.clear();
    fault="video0"; dsi_mgr_bridge_enable(&bridge.base); expect({"video0"});
    assert(!bridge.video_enabled && bridge.powered);
    fault.clear(); unprepare(); dsi_mgr_bridge_post_disable(&bridge.base);
    expect({"panel_off","save_pll","noirq0","noirq1","off1","off0","phy_off"});

    dsi_bridge slave{{},1,&panel,false,false};
    dsi_mgr_bridge_pre_enable(&slave.base); dsi_mgr_bridge_enable(&slave.base);
    expect({}); dsi_mgr_bridge_post_disable(&slave.base); expect({"phy_off"});

    // Non-O82 bonded and standalone hosts keep their previous callback order.
    bridge.o82_panel=nullptr;
    dsi_mgr_bridge_pre_enable(&bridge.base); dsi_mgr_bridge_enable(&bridge.base);
    expect({"phy_on","power0","power1","irq0","irq1","video0","video1"});
    dsi_mgr_bridge_disable(&bridge.base); expect({});
    dsi_mgr_bridge_post_disable(&bridge.base);
    expect({"stop0","stop1","noirq0","noirq1","save_pll","off0","off1","phy_off"});
    fault="video1"; dsi_mgr_bridge_pre_enable(&bridge.base);
    expect({"phy_on","power0","power1","irq0","irq1","video0","video1","stop0","noirq0","noirq1","off1","off0","phy_off"});
    fault.clear();
    bonded=false;
    dsi_mgr_bridge_pre_enable(&bridge.base); dsi_mgr_bridge_enable(&bridge.base);
    expect({"phy_on","power0","irq0","video0"});
    dsi_mgr_bridge_post_disable(&bridge.base);
    expect({"stop0","noirq0","save_pll","off0","phy_off"});
}
CPP
} >> "$work/check.cpp"
"${CXX:-c++}" -std=c++20 -O2 -Wall -Wextra -Werror \
    -Wno-missing-field-initializers -fsanitize=undefined \
    -fsanitize-undefined-trap-on-error "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Real DSI callbacks: O82 ON/PPS before video, power/prepare failure refusal, reverse stop and unchanged other-panel paths passed\n'
