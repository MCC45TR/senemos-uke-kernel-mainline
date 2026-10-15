#!/usr/bin/env bash
# shellcheck disable=SC2129
# Execute the candidate panel's real lifecycle functions with bounded host I/O.
set -Eeuo pipefail
source_file=${1:?Pass panel-xiaomi-o82.c} header=${2:?Pass generated o82-data.h}
kernel=${3:?Pass the prepared kernel source}
[[ $(awk '/ctx->panel.prepare_prev_first = true;/ {ready=1} /drm_panel_add\(&ctx->panel\)/ {print ready+0; exit}' "$source_file") == 1 ]]
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <errno.h>
#include <string.h>
typedef uint8_t u8; typedef uint16_t u16; typedef uint32_t u32; typedef uint16_t __be16; typedef long ssize_t;
#define __packed __attribute__((packed))
#define DIV_ROUND_UP(n,d) (((n)+(d)-1)/(d))
#define BUILD_BUG_ON(c) _Static_assert(!(c), #c)
#define WARN_ON_ONCE(c) (c)
#define DRM_DEBUG_KMS(...) ((void)0)
#define DRM_DEV_ERROR(...) ((void)0)
#define DRM_DEV_INFO(...) ((void)0)
#define DP_SDP_PPS_HEADER_PAYLOAD_BYTES_MINUS_1 127
#define cpu_to_be16(v) ((uint16_t)__builtin_bswap16((uint16_t)(v)))
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define BIT(n) (1U<<(n))
#define dev_err(...) ((void)0)
#define dev_info(...) ((void)0)
#define dev_warn(...) ((void)0)
#define dev_err_probe(dev,err,...) (err)
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
enum { MIPI_DSI_MSG_USE_LPM=2, MIPI_DSI_PICTURE_PARAMETER_SET=0x0a,
       MIPI_DCS_GET_POWER_MODE=0x0a, MIPI_DSI_FMT_RGB101010=10,
       DRM_MODE_TYPE_DRIVER=1, DRM_MODE_TYPE_PREFERRED=2 };
C
# Use the selected kernel's public flag definitions.
awk '/^#define MIPI_DSI_MODE_VIDEO[ \t]|^#define MIPI_DSI_CLOCK_NON_CONTINUOUS[ \t]|^#define MIPI_DSI_MODE_LPM[ \t]/' \
    "$kernel/include/drm/drm_mipi_dsi.h" >> "$work/check.c"
# Compile the selected upstream structs, RC calculation and wire packer, not a second serializer.
{
sed -n '/^#define DSC_NUM_BUF_RANGES/,/^} __packed;/p' "$kernel/include/drm/display/drm_dsc.h"
sed -n '/^enum drm_dsc_params_type {/,/^};/p' "$kernel/include/drm/display/drm_dsc_helper.h"
sed -n '/^void drm_dsc_pps_payload_pack(/,/^EXPORT_SYMBOL(drm_dsc_compute_rc_parameters)/p' \
    "$kernel/drivers/gpu/drm/display/drm_dsc_helper.c" | sed '/^EXPORT_SYMBOL/d'
awk '/^u8 drm_dsc_initial_scale_value\(/ {p=1} p && /^EXPORT_SYMBOL/ {exit} p' \
    "$kernel/drivers/gpu/drm/display/drm_dsc_helper.c"
} >> "$work/check.c"
cat >> "$work/check.c" <<'C'
struct device_node { const char *compatible; };
static bool requested_initial60,requested_initial120;
static bool of_property_read_bool(struct device_node *node,const char *property) {
    assert(node);
    if(!strcmp(property,"xiaomi,initial-60hz-only")) return requested_initial60;
    assert(!strcmp(property,"xiaomi,initial-120hz-only")); return requested_initial120;
}
struct device { struct device_node *of_node; };
struct platform_device { struct device dev; };
struct msm_dsi_host { struct platform_device *pdev; };
static int node_refs;
static struct device_node *of_graph_get_remote_node(struct device_node *n,int port,int ep) {
    assert(port==1 && ep==-1); if(n) node_refs++; return n;
}
static int of_device_is_compatible(struct device_node *n,const char *name) {
    return n && !strcmp(n->compatible,name);
}
static void of_node_put(struct device_node *n) { if(n) node_refs--; }
C
awk '/^static int dsi_populate_dsc_params\(.*$/ && !/;$/ {p=1}
     p && /^static int dsi_host_parse_dt/ {exit} p' \
    "$kernel/drivers/gpu/drm/msm/dsi/dsi_host.c" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
struct drm_display_mode { unsigned int clock,hdisplay,hsync_start,hsync_end,htotal,
    vdisplay,vsync_start,vsync_end,vtotal,width_mm,height_mm,type; };
struct drm_panel;
struct drm_panel_funcs {int (*enable)(struct drm_panel *); int (*disable)(struct drm_panel *);};
struct drm_panel {bool enabled; const struct drm_panel_funcs *funcs;
    int follower_lock,followers; void *backlight;};
struct drm_panel_follower;
struct follower_ops {int (*panel_enabled)(struct drm_panel_follower *);
    int (*panel_disabling)(struct drm_panel_follower *);};
struct drm_panel_follower {const struct follower_ops *funcs;};
static int backlight_calls,backlight_disable_calls,normal_transfers,hs_transfers;
static void mutex_lock(int *lock) {(void)lock;}
static void mutex_unlock(int *lock) {(void)lock;}
static int backlight_enable(void *backlight) {
    (void)backlight; assert(normal_transfers==4 && hs_transfers==8); ++backlight_calls; return 0;
}
static int backlight_disable(void *backlight) {(void)backlight; ++backlight_disable_calls; return 0;}
#define list_for_each_entry(entry,head,member) for(entry=NULL;entry;entry=NULL)
struct drm_crtc_state { struct drm_display_mode adjusted_mode; };
struct drm_crtc { struct drm_crtc_state *state; };
struct drm_connector_state { struct drm_crtc *crtc; };
struct drm_connector { struct drm_connector_state *state; void *dev;
    struct { int bpc,width_mm,height_mm; } display_info; };
static unsigned int published, preferred, preferred_rate, duplication_failure;
static struct drm_display_mode copies[7];
static int drm_mode_vrefresh(const struct drm_display_mode *m) {
    uint64_t total=(uint64_t)m->htotal*m->vtotal;
    return ((uint64_t)m->clock*1000+total/2)/total;
}
static struct drm_display_mode *drm_mode_duplicate(void *dev,const struct drm_display_mode *mode) {
    (void)dev; assert(published<7);
    if(duplication_failure) return NULL;
    copies[published]=*mode; return &copies[published];
}
static void drm_mode_set_name(struct drm_display_mode *mode) { (void)mode; }
static void drm_mode_probed_add(struct drm_connector *c,struct drm_display_mode *mode) {
    (void)c; assert(mode->type&DRM_MODE_TYPE_DRIVER);
    if(mode->type&DRM_MODE_TYPE_PREFERRED) { preferred_rate=drm_mode_vrefresh(mode); preferred++; }
    published++;
}
struct regulator { int id; }; struct gpio_desc {};
struct mipi_dsi_msg { unsigned int channel,type,flags; size_t tx_len; const void *tx_buf; };
struct mipi_dsi_host;
struct host_ops { ssize_t (*transfer)(struct mipi_dsi_host *,const struct mipi_dsi_msg *); };
struct mipi_dsi_host { struct host_ops *ops; int id; };
struct mipi_dsi_device { struct mipi_dsi_host *host; unsigned long mode_flags;
    unsigned int lanes,format; struct drm_dsc_config *dsc; int id; };
static ssize_t mipi_dsi_dcs_read(struct mipi_dsi_device *d,u8 reg,void *value,size_t len) {
    assert(d->id==0 && !(d->mode_flags&MIPI_DSI_MODE_LPM) && len==1 && (reg==0xda || reg==0x0a));
    *(u8 *)value=0; return 1;
}
static const u8 golden_pps[128]={
    0x11,0,0,0xab,0x30,0x80,0x08,0x58,0x06,0x40,0,0x18,0x03,0x20,0x03,0x20,
    0x02,0,0x02,0xb2,0,0x20,0x02,0x9f,0,0x0b,0,0x0d,0x04,0x86,0x02,0xdc,
    0x18,0,0x10,0xf0,0x07,0x10,0x20,0,0x06,0x0f,0x0f,0x33,0x0e,0x1c,0x2a,0x38,
    0x46,0x54,0x62,0x69,0x70,0x77,0x79,0x7b,0x7d,0x7e,0x02,0x02,0x22,0,0x2a,0x40,
    0x2a,0xbe,0x3a,0xfc,0x3a,0xfa,0x3a,0xf8,0x3b,0x38,0x3b,0x78,0x3b,0xb6,0x4b,0xf6,
    0x4c,0x34,0x4c,0x74,0x5c,0x74,0x8c,0xf4
};
int balance[3], loads[3], enables, disables, transfers, failure=-1, operation, gpio_failure,
    short_write, wire_write, transfer_failure=-1, disable_failure=-1, settle_ms, off_order[3],
    lpm_transfers, pps_transfers, pps_start, transfer_short=-1;
static bool video_started;
static u8 hs_payloads[8][2];
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
    assert((m->flags==MIPI_DSI_MSG_USE_LPM || m->flags==0) && m->channel==0 && m->tx_len>0);
    if (m->flags==MIPI_DSI_MSG_USE_LPM) {
        lpm_transfers++;
        if(video_started) {
            static const u8 normal[2][2]={{0xff,0x10},{0x13,0x00}};
            assert(hs_transfers==8 && normal_transfers<4);
            assert(host->id==normal_transfers%2 && !backlight_calls);
            assert(m->type==(normal_transfers<2 ? 0x15U:0x39U) && m->tx_len==2);
            assert(!memcmp(m->tx_buf,normal[normal_transfers/2],2));
            normal_transfers++;
        }
    }
    else {
        assert(video_started && pps_transfers==2 && hs_transfers<8);
        assert(m->type==0x39 && m->tx_len==2);
        memcpy(hs_payloads[hs_transfers++],m->tx_buf,2);
    }
    const int n=transfers++; if(n==transfer_failure) return -EIO;
    if(m->type==MIPI_DSI_PICTURE_PARAMETER_SET) {
        assert(n==pps_start+pps_transfers);
        assert(m->flags==MIPI_DSI_MSG_USE_LPM && m->tx_len==128);
        assert(!memcmp(m->tx_buf,golden_pps,128)); pps_transfers++;
    }
    return short_write || n==transfer_short ? 0 : (ssize_t)(wire_write ? (m->tx_len+7)&~3UL : m->tx_len);
}
C
{
sed -n '/^struct o82_command {/,/^struct o82_panel {/p' "$source_file" | sed '$d; /#include "o82-data.h"/d'
cat "$header"
sed -n '/^struct o82_panel {/,/^};/p' "$source_file"
sed -n '/^static int o82_send(/,/^static int o82_get_modes(/p' "$source_file" | sed '$d'
sed -n '/^static int o82_get_modes(/,/^static const struct drm_panel_funcs/p' "$source_file" | sed '$d'
} >> "$work/check.c"
# Execute the selected DRM core's duplicate-enable guard and backlight admission.
sed -n '/^void drm_panel_enable(/,/^EXPORT_SYMBOL(drm_panel_enable)/p' \
    "$kernel/drivers/gpu/drm/drm_panel.c" | sed '$d' >> "$work/check.c"
sed -n '/^void drm_panel_disable(/,/^EXPORT_SYMBOL(drm_panel_disable)/p' \
    "$kernel/drivers/gpu/drm/drm_panel.c" | sed '$d' >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static struct o82_panel *attach_ctx;
static int attach_failure,attached,detached,panel_removed,secondary_removed;
static int mipi_dsi_attach(struct mipi_dsi_device *dsi) {
    int id=attached++;
    assert(id<2 && dsi==attach_ctx->dsi[id]);
    assert(dsi->mode_flags==(MIPI_DSI_MODE_VIDEO|MIPI_DSI_CLOCK_NON_CONTINUOUS|MIPI_DSI_MODE_LPM));
    assert(dsi->lanes==4 && dsi->format==MIPI_DSI_FMT_RGB101010 && dsi->dsc==&attach_ctx->dsc);
    return id==attach_failure ? -EIO:0;
}
static void mipi_dsi_detach(struct mipi_dsi_device *dsi) {
    assert(dsi==attach_ctx->dsi[0]); ++detached;
}
static void drm_panel_remove(struct drm_panel *panel) {
    assert(panel==&attach_ctx->panel); ++panel_removed;
}
static void mipi_dsi_device_unregister(struct mipi_dsi_device *dsi) {
    assert(dsi==attach_ctx->dsi[1]); ++secondary_removed;
}
/* Execute the actual probe's attachment loop and its failure unwind. Resource
 * discovery before this block is outside the clock-policy change's scope.
 */
static int o82_probe_links(struct o82_panel *ctx) {
    int i,ret;
C
awk '
    /^static int o82_probe\(/ { probe=1 }
    probe && /^\tfor \(i = 0; i < ARRAY_SIZE\(ctx->dsi\); i\+\+\)/ { emit=1 }
    emit && /^static void o82_remove/ { exit }
    emit && !/^unregister_secondary:/ { print }
' "$source_file" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
/* Execute the probe's profile admission before any regulator acquisition. */
static int o82_probe_initial_mode(struct o82_panel *ctx,struct device_node *node) {
    struct device device={node},*dev=&device;
    int ret;
C
awk '
    /^static int o82_probe\(/ { probe=1 }
    probe && /^\tret = o82_read_initial_mode\(/ { emit=1 }
    emit && /^\tfor \(i = 0; i < ARRAY_SIZE\(supply_names\)/ { exit }
    emit { print }
' "$source_file" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
    return 0;
}
static struct o82_panel context(int variant,int mode) {
    static const struct drm_panel_funcs funcs={.enable=o82_enable};
    static struct host_ops ops={transfer};
    static struct mipi_dsi_host hosts[2]={{&ops,0},{&ops,1}};
    static struct mipi_dsi_device dsis[2]={{.host=&hosts[0],.mode_flags=MIPI_DSI_MODE_LPM},
                                         {.host=&hosts[1],.mode_flags=MIPI_DSI_MODE_LPM,.id=1}};
    static struct regulator supplies[3]={{0},{1},{2}};
    static struct drm_crtc_state cs;
    static struct drm_crtc crtc={&cs};
    static struct drm_connector_state state={&crtc};
    static struct drm_connector connector={.state=&state};
    memset(balance,0,sizeof(balance)); memset(loads,0,sizeof(loads));
    enables=disables=transfers=operation=gpio_failure=short_write=wire_write=settle_ms=0;
    lpm_transfers=hs_transfers=pps_transfers=normal_transfers=0;
    backlight_calls=backlight_disable_calls=0; video_started=false;
    failure=transfer_failure=disable_failure=transfer_short=-1;
    cs.adjusted_mode=o82_modes[mode].mode;
    const struct o82_profile *p=variant ? o82_42_02_0b_profiles : o82_36_02_0a_profiles;
    struct o82_panel ctx={.panel={.funcs=&funcs},.dsi={&dsis[0],&dsis[1]},.supplies={&supplies[0],&supplies[1],&supplies[2]},
        .connector=&connector,.profiles=p,.active=p,.initial_120hz_only=variant && mode==5};
    pps_start=2*p[o82_modes[mode].group].on_count;
    struct device_node node={variant ? "xiaomi,o82-42-02-0b" : "xiaomi,o82-36-02-0a"};
    struct platform_device platform={.dev={&node}};
    struct msm_dsi_host h={&platform};
    ctx.dsc=(struct drm_dsc_config){.dsc_version_major=1,.dsc_version_minor=1,
        .slice_width=800,.slice_height=24,.slice_count=2,.bits_per_component=10,
        .bits_per_pixel=8<<4,.block_pred_enable=true,.pic_width=3200,.pic_height=2136};
    assert(dsi_populate_dsc_params(&h,&ctx.dsc)==0 && node_refs==0);
    assert(ctx.dsc.first_line_bpg_offset==13 && ctx.dsc.rc_range_params[0].range_max_qp==8);
    assert(ctx.dsc.initial_dec_delay==690 && ctx.dsc.nfl_bpg_offset==1158 &&
           ctx.dsc.scale_increment_interval==671 && ctx.dsc.slice_bpg_offset==732);
    return ctx;
}
int main(void) {
    for(int variant=0;variant<2;variant++) for(int flags=0;flags<4;flags++) {
        struct o82_panel ctx=context(variant,3);
        struct device_node node={variant ? "xiaomi,o82-42-02-0b" : "xiaomi,o82-36-02-0a"};
        requested_initial60=flags&1; requested_initial120=flags&2;
        const bool invalid=flags==3 || (requested_initial120 && !variant);
        assert(o82_probe_initial_mode(&ctx,&node)==(invalid ? -EINVAL:0));
        assert(!enables && !transfers && !operation && !ctx.prepared);
        assert(ctx.initial_60hz_only==requested_initial60 && ctx.initial_120hz_only==requested_initial120);
    }
    for(int variant=0;variant<2;variant++) for(int fail=-1;fail<2;fail++) {
        struct o82_panel ctx=context(variant,3); attach_ctx=&ctx;
        attach_failure=fail; attached=detached=panel_removed=secondary_removed=0;
        assert(o82_probe_links(&ctx)==(fail<0 ? 0:-EIO));
        assert(attached==(fail==0 ? 1:2));
        assert(detached==(fail==1 ? 1:0));
        assert(panel_removed==(fail>=0) && secondary_removed==(fail>=0));
    }
    const unsigned int rates[]={30,48,50,60,90,120,144};
    assert(ARRAY_SIZE(o82_modes)==7);
    struct o82_panel selection=context(0,3);
    published=preferred=0;
    assert(o82_get_modes(&selection.panel,selection.connector)==7 && published==7 && preferred==1 && preferred_rate==60);
    selection.initial_60hz_only=true; published=preferred=0;
    assert(o82_get_modes(&selection.panel,selection.connector)==1 && published==1 && preferred==1);
    assert(drm_mode_vrefresh(&copies[0])==60 && preferred_rate==60);
    duplication_failure=1; published=0;
    assert(o82_get_modes(&selection.panel,selection.connector)==-ENOMEM && !published);
    duplication_failure=0;
    selection=context(1,5); published=preferred=0;
    assert(o82_get_modes(&selection.panel,selection.connector)==1 && published==1 && preferred==1);
    assert(drm_mode_vrefresh(&copies[0])==120 && preferred_rate==120);
    duplication_failure=1; published=0;
    assert(o82_get_modes(&selection.panel,selection.connector)==-ENOMEM && !published);
    duplication_failure=0;
    for(int mode=0;mode<7;mode++) {
        if(mode==5) continue;
        struct o82_panel ctx=context(1,mode); ctx.initial_120hz_only=true;
        assert(o82_prepare(&ctx.panel)==-EINVAL && !enables && !transfers && !operation && !ctx.prepared);
    }
    selection=context(1,5); selection.connector->state->crtc->state->adjusted_mode.clock++;
    assert(o82_prepare(&selection.panel)==-EINVAL && !enables && !transfers && !operation);
    for(unsigned int v=0;v<2;v++) for(unsigned int m=0;m<7;m++) {
        const struct drm_display_mode *mode=&o82_modes[m].mode;
        const uint64_t divisor=(uint64_t)mode->htotal*mode->vtotal;
        assert(((uint64_t)mode->clock*1000+divisor/2)/divisor==rates[m]);
        assert(mode->width_mm==237 && mode->height_mm==158 && mode->vtotal<=8191);
        struct o82_panel c=context(v,m);
        const struct drm_dsc_config encoder=c.dsc;
        drm_panel_enable(&c.panel);
        assert(!c.panel.enabled && !transfers && !backlight_calls);
        assert(o82_prepare(&c.panel)==0 && c.prepared && c.enabled_supplies==7);
        assert(!memcmp(&c.dsc,&encoder,sizeof(encoder)) && pps_transfers==2);
        const int full=transfers;
        assert(full==2*(int)(c.active->on_count+1));
        assert(lpm_transfers==2*(int)(c.active->on_count+1));
        assert(!hs_transfers && !c.panel.enabled && !backlight_calls);
        assert(c.active->switch_count==4);
        assert(o82_prepare(&c.panel)==0 && transfers==full && enables==3);
        const int before_enable_wait=settle_ms;
        video_started=true; drm_panel_enable(&c.panel);
        assert(c.panel.enabled && backlight_calls==1 && enables==3);
        assert(hs_transfers==2*(int)c.active->switch_count && settle_ms==before_enable_wait);
        assert(normal_transfers==4 && transfers==full+12);
        for(unsigned int command=0;command<c.active->switch_count;command++)
            for(int link=0;link<2;link++)
                assert(!memcmp(hs_payloads[2*command+link],c.active->switch_commands[command].data,2));
        const int enabled_full=transfers;
        drm_panel_enable(&c.panel);
        assert(transfers==enabled_full && backlight_calls==1);
        drm_panel_disable(&c.panel);
        assert(!c.panel.enabled && backlight_disable_calls==1);
        drm_panel_disable(&c.panel);
        assert(backlight_disable_calls==1);
        /* A fresh core enable after disable repeats the panel protocol. */
        hs_transfers=normal_transfers=0; backlight_calls=0;
        drm_panel_enable(&c.panel);
        assert(c.panel.enabled && backlight_calls==1 && normal_transfers==4 && hs_transfers==8);
        drm_panel_disable(&c.panel);
        video_started=false;
        assert(o82_unprepare(&c.panel)==0 && !c.prepared && !c.enabled_supplies);
        assert(off_order[0]==2 && off_order[1]==1 && off_order[2]==0);
        assert(o82_unprepare(&c.panel)==0 && disables==3);
        /* Full unprepare/prepare also retains normal restoration on enable. */
        pps_start=transfers+2*c.active->on_count; pps_transfers=0;
        hs_transfers=normal_transfers=backlight_calls=0;
        assert(o82_prepare(&c.panel)==0 && c.prepared && pps_transfers==2);
        assert(!normal_transfers && !hs_transfers);
        video_started=true; drm_panel_enable(&c.panel);
        assert(c.panel.enabled && backlight_calls==1 && normal_transfers==4 && hs_transfers==8);
        drm_panel_disable(&c.panel); video_started=false;
        assert(o82_unprepare(&c.panel)==0 && !c.prepared && !c.enabled_supplies);
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
        for(int link=0;link<2;link++) {
            c=context(v,m); transfer_short=pps_start+link;
            assert(o82_prepare(&c.panel)==-EIO && !c.prepared && !c.enabled_supplies);
            for(int i=0;i<3;i++) assert(!balance[i] && !loads[i]);
        }
        for(int short_reply=0;short_reply<2;short_reply++) for(int fault=0;fault<12;fault++) {
            c=context(v,m); assert(o82_prepare(&c.panel)==0);
            const int before=transfers;
            if(short_reply) transfer_short=before+fault; else transfer_failure=before+fault;
            video_started=true; drm_panel_enable(&c.panel);
            assert(!c.panel.enabled && !backlight_calls && c.prepared && c.enabled_supplies==7);
            assert(disables==0 && transfers==before+fault+1);
            assert(hs_transfers==(fault<8 ? fault+1:8));
            assert(normal_transfers==(fault<8 ? 0:fault-7));
            transfer_failure=transfer_short=-1; hs_transfers=normal_transfers=0;
            if(fault&1) {
                drm_panel_enable(&c.panel);
                assert(c.panel.enabled && backlight_calls==1 && hs_transfers==8 && normal_transfers==4 && enables==3);
            }
            video_started=false;
            assert(o82_unprepare(&c.panel)==0 && !c.prepared && !c.enabled_supplies);
        }
        c=context(v,m); gpio_failure=1;
        assert(o82_prepare(&c.panel)==-EIO && !c.enabled_supplies);
        c=context(v,m); short_write=1;
        assert(o82_prepare(&c.panel)==-EIO && !c.enabled_supplies);
        c=context(v,m); wire_write=1;
        assert(o82_prepare(&c.panel)==0 && c.prepared);
        assert(o82_unprepare(&c.panel)==0 && !c.enabled_supplies);
        c=context(v,m); assert(o82_prepare(&c.panel)==0); disable_failure=1;
        assert(o82_unprepare(&c.panel)==-EIO && c.enabled_supplies==2);
        assert(o82_prepare(&c.panel)==-EBUSY);
        disable_failure=-1; assert(o82_unprepare(&c.panel)==0 && !c.enabled_supplies);
        c=context(v,m); c.connector=NULL;
        assert(o82_prepare(&c.panel)==-EINVAL && enables==0);
        c=context(v,m); c.dsc.initial_dec_delay=0;
        assert(o82_prepare(&c.panel)==-EINVAL && enables==0 && transfers==0);
        c=context(v,m); c.connector->state->crtc->state->adjusted_mode.clock++;
        assert(o82_prepare(&c.panel)==-EINVAL && enables==0);
    }
    struct o82_panel c=context(0,3);
    struct device_node node={"unrelated,panel"};
    struct platform_device platform={.dev={&node}};
    struct msm_dsi_host h={&platform};
    assert(dsi_populate_dsc_params(&h,&c.dsc)==0 && node_refs==0);
    assert(c.dsc.first_line_bpg_offset==12 && c.dsc.rc_range_params[0].range_max_qp==4);
    node.compatible="xiaomi,o82-42-02-0b"; c.dsc.slice_width=400;
    assert(dsi_populate_dsc_params(&h,&c.dsc)==-EINVAL && node_refs==0);
    platform.dev.of_node=NULL; c.dsc.slice_width=800;
    assert(dsi_populate_dsc_params(&h,&c.dsc)==0 && node_refs==0);
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-sign-compare -Wno-misleading-indentation -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/check.c" -o "$work/check"
"$work/check"
printf 'Two O82 variants, seven modes: exclusive O82-42 initial120 admission and pre-power mode rejection; unchanged ON/PPS, HS post-enable, LP normal-pixels and DRM core lifecycle/fault cleanup passed\n'
