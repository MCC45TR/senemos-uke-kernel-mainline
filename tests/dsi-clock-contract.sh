#!/usr/bin/env bash
# Execute the selected kernel's actual compression and DSI byte-clock helpers.
set -Eeuo pipefail
file=${1:?Pass prepared dsi_host.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cstdint>
#include <cstddef>
#define DIV_ROUND_UP(n,d) (((n)+(d)-1)/(d))
#define mult_frac(n,m,d) ((static_cast<uint64_t>(n)*(m))/(d))
#define container_of(p,t,m) reinterpret_cast<t *>(reinterpret_cast<char *>(p)-offsetof(t,m))
#define pr_err(...) ((void)0)
using u8=uint8_t; using u32=uint32_t;
struct drm_display_mode { int clock,hdisplay,htotal; };
struct drm_dsc_config { unsigned int bits_per_component,bits_per_pixel; };
struct mipi_dsi_host {};
struct msm_dsi_host { mipi_dsi_host base; unsigned int lanes,format; drm_dsc_config *dsc; bool cphy_mode; };
#define to_msm_dsi_host(p) container_of(p,msm_dsi_host,base)
unsigned int drm_dsc_get_bpp_int(const drm_dsc_config *dsc) {return dsc->bits_per_pixel>>4;}
unsigned int mipi_dsi_pixel_format_to_bpp(unsigned int format) {return format;}
CPP
sed -n '/^dsi_adjust_pclk_for_compression(/,/^static void dsi_calc_pclk(/p' "$file" | sed '$d' > "$work/functions"
{
printf 'static unsigned long\n'
cat "$work/functions"
} >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
int main() {
    drm_display_mode mode{967428,3200,3490};
    drm_dsc_config dsc{10,8<<4};
    msm_dsi_host host{{},4,24,&dsc,false};
    const auto lane=dsi_byte_clk_get_rate(&host.base,true,&mode)*8;
    assert(lane==1189188000UL);
    dsc.bits_per_component=8;
    assert(dsi_byte_clk_get_rate(&host.base,true,&mode)*8==1129312800UL);
    host.dsc=nullptr;
    assert(dsi_byte_clk_get_rate(&host.base,true,&mode)==362785500UL);
    assert(dsi_byte_clk_get_rate(&host.base,false,&mode)==725571000UL);
    host.cphy_mode=true;
    assert(dsi_byte_clk_get_rate(&host.base,true,&mode)==181392750UL);
    host.cphy_mode=false; host.lanes=0;
    assert(dsi_byte_clk_get_rate(&host.base,true,&mode)==1451142000UL);
}
CPP
g++ -std=c++20 -O2 -Wall -Wextra -Werror -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Real DSI clock functions: O82 10-bpc lane clock, 8-bpc, uncompressed, bonded, CPHY and zero-lane guard passed\n'
