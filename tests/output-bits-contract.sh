#!/usr/bin/env bash
# Execute the real DP and DSI read-only stream snapshots, including inactive state.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel}
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#define READ_ONCE(x) (x)
struct seq_file {void *private; char line[256];};
static void seq_printf(struct seq_file *s,const char *fmt,...) {va_list a;va_start(a,fmt);vsnprintf(s->line,sizeof(s->line),fmt,a);va_end(a);}
struct drm_dsc_config {unsigned bits_per_component,bits_per_pixel;};
struct mipi_dsi_host {struct drm_dsc_config *dsc;};
struct msm_dsi {struct mipi_dsi_host *host;};
struct dsi_bridge {int id; bool video_enabled;};
static struct msm_dsi *selected;
static struct msm_dsi *dsi_mgr_get_dsi(int id) {(void)id;return selected;}
static struct drm_dsc_config *msm_dsi_host_get_dsc_config(struct mipi_dsi_host *h) {return h->dsc;}
struct msm_dp {bool power_on;};
struct msm_dp_mode {unsigned bpp;};
struct msm_dp_panel {struct msm_dp_mode msm_dp_mode;};
struct msm_dp_debug_private {struct msm_dp *display;struct msm_dp_panel *panel;};
C
for item in 'dsi/dsi_manager.c:dsi_mgr_output_bits_show' 'dp/dp_debug.c:msm_dp_output_bits_show'; do
 file=${item%%:*}; name=${item#*:}
 awk -v signature="static int $name(" 'index($0,signature)==1{emit=found=1} emit{print} emit&&/^}/{exit} END{if(!found)exit 1}' "$kernel/drivers/gpu/drm/msm/$file" >> "$work/check.c"
done
cat >> "$work/check.c" <<'C'
int main(void) {
 struct drm_dsc_config dsc={10,128};struct mipi_dsi_host host={&dsc};struct msm_dsi dsi={&host};selected=&dsi;
 struct dsi_bridge bridge={0,false};struct seq_file seq={.private=&bridge};
 assert(!dsi_mgr_output_bits_show(&seq,NULL));assert(!strcmp(seq.line,"version=1 active=0 bpc=0 bpp=0 dsc_bpp_x16=0\n"));
 bridge.video_enabled=true;
 assert(!dsi_mgr_output_bits_show(&seq,NULL));assert(!strcmp(seq.line,"version=1 active=1 bpc=10 bpp=30 dsc_bpp_x16=128\n"));
 selected=NULL;assert(!dsi_mgr_output_bits_show(&seq,NULL));assert(strstr(seq.line,"bpc=0 bpp=0"));selected=&dsi;
 host.dsc=NULL;assert(!dsi_mgr_output_bits_show(&seq,NULL));assert(strstr(seq.line,"bpc=0 bpp=0"));
 struct msm_dp display={false};struct msm_dp_panel panel={{30}};struct msm_dp_debug_private debug={&display,&panel};seq.private=&debug;
 for(unsigned power=0;power<2;power++)for(unsigned bpc=6;bpc<=12;bpc+=2) {
  display.power_on=power;panel.msm_dp_mode.bpp=bpc*3;
  assert(!msm_dp_output_bits_show(&seq,NULL));
  char expected[256];bool active=power;
  snprintf(expected,sizeof(expected),"version=1 active=%u bpc=%u bpp=%u dsc_bpp_x16=0\n",active,active?bpc:0,active?bpc*3:0);
  assert(!strcmp(seq.line,expected));
 }
 puts("Actual DP/DSI stream snapshots: enabled depth, DSC wire bits, inactive/disconnected and missing-state boundaries passed; host only");
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-unused-parameter "$work/check.c" -o "$work/check"
"$work/check"
