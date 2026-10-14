#!/usr/bin/env bash
# Execute the candidate panel's real lifecycle functions with bounded host I/O.
set -Eeuo pipefail
source_file=${1:?Pass panel-xiaomi-o82.c} header=${2:?Pass generated o82-data.h}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <errno.h>
#include <string.h>
typedef uint8_t u8; typedef uint16_t u16; typedef long ssize_t;
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define BIT(n) (1U<<(n))
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
enum { MIPI_DSI_MSG_USE_LPM=2 };
struct drm_display_mode { unsigned int clock,hdisplay,hsync_start,hsync_end,htotal,
    vdisplay,vsync_start,vsync_end,vtotal,width_mm,height_mm; };
struct drm_panel {};
struct drm_crtc_state { struct drm_display_mode adjusted_mode; };
struct drm_crtc { struct drm_crtc_state *state; };
struct drm_connector_state { struct drm_crtc *crtc; };
struct drm_connector { struct drm_connector_state *state; };
struct regulator { int id; }; struct gpio_desc {};
struct mipi_dsi_msg { unsigned int channel,type,flags; size_t tx_len; const void *tx_buf; };
struct mipi_dsi_host;
struct host_ops { ssize_t (*transfer)(struct mipi_dsi_host *,const struct mipi_dsi_msg *); };
struct mipi_dsi_host { struct host_ops *ops; };
struct mipi_dsi_device { struct mipi_dsi_host *host; };
struct drm_dsc_config {};
int balance[3], loads[3], enables, disables, transfers, failure=-1, operation, gpio_failure,
    short_write, transfer_failure=-1, disable_failure=-1, settle_ms, off_order[3];
static bool drm_mode_equal(const struct drm_display_mode *a,const struct drm_display_mode *b) {
    return !memcmp(a,b,offsetof(struct drm_display_mode,width_mm));
}
static int regulator_set_load(struct regulator *r,int load) {
    if (operation++==failure) return -EIO; loads[r->id]=load; return 0;
}
static int regulator_enable(struct regulator *r) {
    if (operation++==failure) return -EIO; balance[r->id]++; enables++; return 0;
}
static int regulator_disable(struct regulator *r) {
    if (r->id==disable_failure) return -EIO;
    assert(balance[r->id]==1); balance[r->id]--; off_order[disables++%3]=r->id; return 0;
}
static int gpiod_direction_output(struct gpio_desc *g,int value) {
    (void)g; assert(value==0); return gpio_failure ? -EIO : 0;
}
static void gpiod_set_value_cansleep(struct gpio_desc *g,int value) { (void)g; (void)value; }
static void msleep(unsigned int ms) { assert(ms<=200); settle_ms+=ms; }
static ssize_t transfer(struct mipi_dsi_host *host,const struct mipi_dsi_msg *m) {
    (void)host; assert(m->flags==MIPI_DSI_MSG_USE_LPM && m->channel==0 && m->tx_len>0);
    const int n=transfers++; if(n==transfer_failure) return -EIO;
    return short_write ? 0 : (ssize_t)m->tx_len;
}
C
{
sed -n '/^struct o82_command {/,/^struct o82_panel {/p' "$source_file" | sed '$d; /#include "o82-data.h"/d'
cat "$header"
sed -n '/^struct o82_panel {/,/^};/p' "$source_file"
sed -n '/^static int o82_send(/,/^static int o82_get_modes(/p' "$source_file" | sed '$d'
} >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static struct o82_panel context(int variant,int mode) {
    static struct host_ops ops={transfer};
    static struct mipi_dsi_host hosts[2]={{&ops},{&ops}};
    static struct mipi_dsi_device dsis[2]={{&hosts[0]},{&hosts[1]}};
    static struct regulator supplies[3]={{0},{1},{2}};
    static struct drm_crtc_state cs;
    static struct drm_crtc crtc={&cs};
    static struct drm_connector_state state={&crtc};
    static struct drm_connector connector={&state};
    memset(balance,0,sizeof(balance)); memset(loads,0,sizeof(loads));
    enables=disables=transfers=operation=gpio_failure=short_write=settle_ms=0;
    failure=transfer_failure=disable_failure=-1;
    cs.adjusted_mode=o82_modes[mode].mode;
    const struct o82_profile *p=variant ? o82_42_02_0b_profiles : o82_36_02_0a_profiles;
    struct o82_panel ctx={.dsi={&dsis[0],&dsis[1]},.supplies={&supplies[0],&supplies[1],&supplies[2]},
        .connector=&connector,.profiles=p,.active=p};
    return ctx;
}
int main(void) {
    const unsigned int rates[]={30,48,50,60,90,120,144};
    assert(ARRAY_SIZE(o82_modes)==7);
    for(unsigned int v=0;v<2;v++) for(unsigned int m=0;m<7;m++) {
        const struct drm_display_mode *mode=&o82_modes[m].mode;
        const uint64_t divisor=(uint64_t)mode->htotal*mode->vtotal;
        assert(((uint64_t)mode->clock*1000+divisor/2)/divisor==rates[m]);
        assert(mode->width_mm==237 && mode->height_mm==158 && mode->vtotal<=8191);
        struct o82_panel c=context(v,m);
        assert(o82_prepare(&c.panel)==0 && c.prepared && c.enabled_supplies==7);
        const int full=transfers;
        assert(full==2*(int)(c.active->on_count+c.active->switch_count));
        assert(o82_prepare(&c.panel)==0 && transfers==full && enables==3);
        assert(o82_unprepare(&c.panel)==0 && !c.prepared && !c.enabled_supplies);
        assert(off_order[0]==2 && off_order[1]==1 && off_order[2]==0);
        assert(o82_unprepare(&c.panel)==0 && disables==3);
        for(int fault=0;fault<6;fault++) {
            c=context(v,m); failure=fault;
            assert(o82_prepare(&c.panel)==-EIO && !c.prepared && !c.enabled_supplies);
            for(int i=0;i<3;i++) assert(!balance[i] && !loads[i]);
        }
        for(int fault=0;fault<full;fault++) {
            c=context(v,m); transfer_failure=fault;
            assert(o82_prepare(&c.panel)==-EIO && !c.prepared && !c.enabled_supplies);
            for(int i=0;i<3;i++) assert(!balance[i] && !loads[i]);
            assert(settle_ms>=20+100);
        }
        c=context(v,m); gpio_failure=1;
        assert(o82_prepare(&c.panel)==-EIO && !c.enabled_supplies);
        c=context(v,m); short_write=1;
        assert(o82_prepare(&c.panel)==-EIO && !c.enabled_supplies);
        c=context(v,m); assert(o82_prepare(&c.panel)==0); disable_failure=1;
        assert(o82_unprepare(&c.panel)==-EIO && c.enabled_supplies==2);
        assert(o82_prepare(&c.panel)==-EBUSY);
        disable_failure=-1; assert(o82_unprepare(&c.panel)==0 && !c.enabled_supplies);
        c=context(v,m); c.connector=NULL;
        assert(o82_prepare(&c.panel)==-EINVAL && enables==0);
        c=context(v,m); c.connector->state->crtc->state->adjusted_mode.clock++;
        assert(o82_prepare(&c.panel)==-EINVAL && enables==0);
    }
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-sign-compare -Wno-misleading-indentation -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/check.c" -o "$work/check"
"$work/check"
printf 'Two O82 variants, seven mode timings and actual lifecycle supply/GPIO/DSI/short-write/rollback faults: passed\n'
