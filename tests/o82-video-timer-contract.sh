#!/usr/bin/env bash
# Execute the real scoped timer setter with the generated register encoder.
set -Eeuo pipefail
source=${1:?Pass candidate dsi_host.c}
objects=${2:?Pass kernel object directory}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#define FD_NO_DEPRECATED_PACK
#include "dsi.xml.h"
#define DSI_0 0
#define DSI_1 1
#define MSM_DSI_VER_MAJOR_6G 6
#define MSM_DSI_6G_VER_MINOR_V2_8_0 0x20080000
#define MIPI_DSI_MODE_VIDEO 1
#define MIPI_DSI_FMT_RGB101010 4
struct drm_display_mode {int clock,hdisplay,hsync_start,hsync_end,htotal;
    int vdisplay,vsync_start,vsync_end,vtotal;};
struct drm_dsc_config {int bits_per_component,bits_per_pixel;};
struct device_node {bool pb,isolated;};
struct platform_device {struct {struct device_node *of_node;} dev;};
struct msm_dsi_cfg_handler {int major,minor;};
struct msm_dsi_host {struct drm_display_mode *mode;
    struct drm_dsc_config *dsc; struct msm_dsi_cfg_handler *cfg_hnd;
    struct platform_device *pdev; int id,lanes,format,mode_flags; bool cphy_mode;};
static bool uke=true,sm7675=true;
static struct device_node node={true,true};
static struct device_node *remote=&node;
static unsigned int gets,puts,writes;
static uint32_t encoded;
static bool of_machine_is_compatible(const char *name) {
    if(!strcmp(name,"xiaomi,uke"))return uke;
    assert(!strcmp(name,"qcom,sm7675"));return sm7675;
}
static struct device_node *of_graph_get_remote_node(struct device_node *parent,int port,int endpoint) {
    assert(parent==&node && port==1 && endpoint==-1);++gets;return remote;
}
static bool of_device_is_compatible(struct device_node *n,const char *name) {
    assert(!strcmp(name,"xiaomi,o82-42-02-0b"));return n && n->pb;
}
static bool of_property_read_bool(struct device_node *n,const char *name) {
    assert(n && !strcmp(name,"xiaomi,initial-120hz-only"));return n->isolated;
}
static void of_node_put(struct device_node *n) {assert(n==remote);++puts;}
static void dsi_write(struct msm_dsi_host *host,uint32_t reg,uint32_t value) {
    assert(host && reg==REG_DSI_HS_TIMER_CTRL);++writes;encoded=value;
}
C
awk '
 /^static void dsi_uke_o82_video_timer\(/ {found=1}
 found {print}
 found && /^}/ {exit}
 END {if(!found)exit 1}
' "$source" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static void check(struct msm_dsi_host *host,bool bonded,unsigned int expected) {
    gets=puts=writes=0;encoded=0;
    dsi_uke_o82_video_timer(host,bonded);
    assert(writes==expected && gets==puts && gets<=1);
    if(expected)assert(encoded==0x4bb80 && !(encoded&DSI_HS_TIMER_CTRL_HS_TX_TO_STOP_EN));
}
#define REJECT(field,value) do {__auto_type saved=(field);(field)=(value);check(&host,true,0);(field)=saved;}while(0)
int main(void) {
    struct drm_display_mode mode={967428,3200,3426,3458,3490,2136,2162,2164,2310};
    struct drm_dsc_config dsc={10,8<<4};
    struct msm_dsi_cfg_handler cfg={MSM_DSI_VER_MAJOR_6G,MSM_DSI_6G_VER_MINOR_V2_8_0};
    struct platform_device pdev={{&node}};
    struct msm_dsi_host host={&mode,&dsc,&cfg,&pdev,0,4,MIPI_DSI_FMT_RGB101010,MIPI_DSI_MODE_VIDEO,false};
    check(&host,true,1);host.id=1;check(&host,true,1);
    check(&host,false,0);
    REJECT(uke,false);REJECT(sm7675,false);REJECT(host.id,2);
    REJECT(host.mode,NULL);REJECT(host.cfg_hnd,NULL);REJECT(host.dsc,NULL);
    REJECT(cfg.major,5);REJECT(cfg.minor,0x20070000);
    REJECT(host.mode_flags,0);REJECT(host.cphy_mode,true);
    REJECT(host.lanes,3);REJECT(host.format,0);
    REJECT(dsc.bits_per_component,8);REJECT(dsc.bits_per_pixel,10<<4);
    REJECT(mode.clock,967427);REJECT(mode.hdisplay,3199);
    REJECT(mode.hsync_start,3425);REJECT(mode.hsync_end,3457);
    REJECT(mode.htotal,3489);REJECT(mode.vdisplay,2135);
    REJECT(mode.vsync_start,2161);REJECT(mode.vsync_end,2163);
    REJECT(mode.vtotal,2309);REJECT(node.pb,false);
    REJECT(node.isolated,false);REJECT(remote,NULL);
    check(&host,true,1);
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror \
    -fsanitize=undefined -fsanitize-undefined-trap-on-error \
    -I "$objects/drivers/gpu/drm/msm/generated" "$work/check.c" -o "$work/check"
"$work/check"
[[ $(grep -c '^[[:space:]]*dsi_uke_o82_video_timer(msm_host, is_bonded_dsi);' "$source") == 1 ]]
printf 'Actual O82 PB120 timer: exact encoding, both links, scoped refusals and balanced DT references passed\n'
