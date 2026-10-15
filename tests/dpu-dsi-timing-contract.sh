#!/usr/bin/env bash
# Execute real DPU/DSI timing functions on the host; never accesses hardware.
set -Eeuo pipefail
dpu=${1:?Pass prepared dpu_encoder_phys_vid.c}
dsi=${2:?Pass prepared dsi_host.c}
modes=${3:?Pass generated o82-data.h}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cstdint>
#include <cstring>
#define DIV_ROUND_UP(n,d) (((n)+(d)-1)/(d))
#define mult_frac(n,m,d) ((static_cast<uint64_t>(n)*(m))/(d))
#define DPU_ERROR(...) ((void)0)
#define DRM_MODE_FLAG_NHSYNC 1
#define DRM_MODE_FLAG_NVSYNC 2
using u32=uint32_t;
enum { INTF_DSI, INTF_DP };
struct drm_display_mode {
    int clock,hdisplay,hsync_start,hsync_end,htotal,vdisplay,vsync_start,vsync_end,vtotal;
    unsigned int width_mm,height_mm,flags,hskew;
};
struct drm_dsc_config {
    unsigned int bits_per_pixel,bits_per_component,slice_count,slice_chunk_size;
};
struct drm_encoder { bool dsc,wide; drm_dsc_config config; };
struct dpu_intf_caps { int type; };
struct dpu_hw_intf { dpu_intf_caps *cap; };
struct dpu_encoder_phys { drm_encoder *parent; dpu_hw_intf *hw_intf; };
struct dpu_hw_intf_timing_params {
    unsigned int width,height,xres,yres,h_back_porch,h_front_porch,v_back_porch,
        v_front_porch,hsync_pulse_width,vsync_pulse_width,hsync_polarity,
        vsync_polarity,border_clr,underflow_clr,hsync_skew,dce_bytes_per_line;
    bool wide_bus_en,compression_en;
};
static bool dpu_encoder_is_widebus_enabled(const drm_encoder *e) { return e->wide; }
static bool dpu_encoder_is_dsc_enabled(const drm_encoder *e) { return e->dsc; }
static drm_dsc_config *dpu_encoder_get_dsc_config(drm_encoder *e) { return &e->config; }
static unsigned int drm_dsc_get_bpp_int(const drm_dsc_config *d) { return d->bits_per_pixel>>4; }
static unsigned int msm_dsc_get_bytes_per_line(const drm_dsc_config *d) {
    return d->slice_count*d->slice_chunk_size;
}
struct o82_timing { unsigned int group; drm_display_mode mode; };
CPP
{
sed -n '/^static const struct o82_timing o82_modes\[\] = {/,/^};/p' "$modes"
sed -n '/^static void drm_mode_to_intf_timing_params(/,/^static u32 get_horizontal_total(/p' "$dpu" |
    sed '$d'
printf 'static unsigned long\n'
sed -n '/^dsi_adjust_pclk_for_compression(/,/^unsigned long dsi_byte_clk_get_rate(/p' "$dsi" |
    sed '$d'
cat <<'CPP'
static unsigned int dsi_active(const drm_dsc_config *dsc, unsigned int bits_per_pclk) {
    struct { const drm_dsc_config *dsc; } host{dsc};
    auto *msm_host=&host;
    unsigned int hdisplay;
CPP
sed -n '/^[[:space:]]*hdisplay = DIV_ROUND_UP(msm_dsc_get_bytes_per_line(msm_host->dsc)/p' "$dsi"
cat <<'CPP'
    return hdisplay;
}
int main() {
    static_assert(sizeof(o82_modes)/sizeof(o82_modes[0])==7);
    drm_encoder encoder{true,true,{8<<4,10,2,800}};
    dpu_intf_caps caps{INTF_DSI}; dpu_hw_intf intf{&caps};
    dpu_encoder_phys physical{&encoder,&intf};
    for(const auto &entry : o82_modes) {
        auto mode=entry.mode;
        mode.hdisplay/=2; mode.htotal/=2; mode.hsync_start/=2; mode.hsync_end/=2;
        dpu_hw_intf_timing_params timing{};
        drm_mode_to_intf_timing_params(&physical,&mode,&timing);
        const auto active=dsi_active(&encoder.config,30);
        const auto porch=entry.mode.htotal/2-1600;
        assert(active==427 && timing.width==active && timing.xres==active);
        assert(timing.dce_bytes_per_line==1600);
        assert(timing.width+timing.h_back_porch+timing.h_front_porch+timing.hsync_pulse_width==active+porch);
        const auto host_clock=dsi_get_pclk_rate(&entry.mode,&encoder.config,true);
        const auto expected=mult_frac(entry.mode.clock*1000u,2*(active+porch),entry.mode.htotal)/2;
        assert(host_clock==expected);
        if(entry.mode.clock==967428 && entry.mode.vtotal==4620) {
            assert(active+porch==572 && host_clock==158558400);
        }
        encoder.config.bits_per_component=8;
        drm_mode_to_intf_timing_params(&physical,&mode,&timing);
        assert(timing.width==534 && timing.width==dsi_active(&encoder.config,24));
        encoder.config.bits_per_component=10;
        encoder.dsc=false;
        drm_mode_to_intf_timing_params(&physical,&mode,&timing);
        assert(timing.width==1600 && !timing.compression_en);
        encoder.dsc=true;
    }
    caps.type=INTF_DP; encoder.wide=false;
    dpu_hw_intf_timing_params timing{};
    drm_mode_to_intf_timing_params(&physical,&o82_modes[3].mode,&timing);
    assert(timing.width==3200);
}
CPP
} >> "$work/check.cpp"
"${CXX:-c++}" -std=c++20 -O2 -Wall -Wextra -Werror -Wno-missing-field-initializers \
    -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Real DPU and DSI functions: seven O82 timings share rounded active width and line periods; 8-bpc, uncompressed and DP paths checked\n'
