#!/usr/bin/env bash
# Run the real DSC latency helper and register-writer prefix without hardware.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
base=$kernel/drivers/gpu/drm/msm/disp/dpu1
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cstdint>
#include <map>
#define BIT(n) (1U << (n))
#define DIV_ROUND_UP(n,d) (((n)+(d)-1)/(d))
using u8=uint8_t; using u16=uint16_t; using u32=uint32_t;
CPP
{
sed -n '/^#define DSC_CMN_MAIN_CNF/,/^static int _dsc_calc_output_buf_max_addr/p' \
    "$base/dpu_hw_dsc_1_2.c" | sed '$d'
awk '/^ \* DSC sub-blocks\/features/ {p=1} p && /^enum/ {e=1}
     p && e {print} p && e && /^};/ {exit}' "$base/dpu_hw_catalog.h"
sed -n '/^#define DSC_MODE_SPLIT_PANEL/,/^struct dpu_hw_dsc;/p' \
    "$base/dpu_hw_dsc.h" | sed '$d'
sed -n '/^#define DSC_NUM_BUF_RANGES/,/^struct drm_dsc_picture_parameter_set {/p' \
    "$kernel/include/drm/display/drm_dsc.h" | sed '$d'
cat <<'CPP'
struct dpu_dsc_sub_blks { struct {u32 base;} enc; };
struct dpu_dsc_cfg {u32 features; const dpu_dsc_sub_blks *sblk;};
struct dpu_hw_blk_reg_map {std::map<u32,u32> writes;};
struct dpu_hw_dsc {dpu_hw_blk_reg_map hw; const dpu_dsc_cfg *caps;};
#define DPU_REG_WRITE(hw,offset,value) ((hw)->writes[(offset)]=(value))
static u32 drm_dsc_get_bpp_int(const drm_dsc_config *dsc) {return dsc->bits_per_pixel>>4;}
CPP
sed -n '/^static int _dsc_calc_output_buf_max_addr/,/^static void dpu_hw_dsc_disable_1_2/p' \
    "$base/dpu_hw_dsc_1_2.c" | sed '$d'
sed -n '/^static u32 dpu_hw_dsc_initial_lines_1_2(/,/^static void dpu_hw_dsc_config_1_2(/p' \
    "$base/dpu_hw_dsc_1_2.c" | sed '$d'
# Stop after the actual initial-lines register write; later RC writes are unrelated.
awk '/^static void dpu_hw_dsc_config_1_2\(/ {p=1} p {print}
     p && /DPU_REG_WRITE\(hw, sblk->enc.base \+ ENC_DF_CTRL, data\);/ {print "}"; exit}' \
    "$base/dpu_hw_dsc_1_2.c" | sed '/^[[:space:]]*u32 det_thresh_flatness;/d; /^[[:space:]]*u32 bpp;/d'
printf 'static u32\n'
sed -n '/^dpu_encoder_dsc_initial_line_calc(/,/^static void dpu_encoder_dsc_pipe_cfg(/p' \
    "$base/dpu_encoder.c" | sed '$d'
cat <<'CPP'
int main() {
    const dpu_dsc_sub_blks blocks{{0x100}};
    const dpu_dsc_cfg newer{BIT(DPU_DSC_NATIVE_42x_EN)|BIT(DPU_DSC_FULL_ICH_PREC),&blocks};
    auto older=newer; older.features&=~BIT(DPU_DSC_FULL_ICH_PREC);
    drm_dsc_config dsc{};
    dsc.bits_per_component=10; dsc.bits_per_pixel=8<<4; dsc.initial_xmit_delay=512;
    dsc.slice_width=800; dsc.slice_chunk_size=800;
    for(u32 width:{800U,1600U,3200U}) {
        dsc.pic_width=width;
        for(u32 mode:{0U,DSC_MODE_VIDEO,DSC_MODE_SPLIT_PANEL,
                      DSC_MODE_MULTIPLEX,DSC_MODE_SPLIT_PANEL|DSC_MODE_MULTIPLEX}) {
            for(u32 slices:{1U,2U}) {
                dsc.slice_count=(mode&DSC_MODE_MULTIPLEX) ? slices*2:slices;
                const bool split_mux=(mode&DSC_MODE_SPLIT_PANEL) && (mode&DSC_MODE_MULTIPLEX);
                const auto expected=slices==2 || split_mux ? 3U:2U;
                const auto old_lines=dpu_encoder_dsc_initial_line_calc(&dsc,width);
                assert(old_lines==2);
                for(u32 depth:{8U,10U,12U}) {
                    dsc.bits_per_component=depth;
                    assert(dpu_hw_dsc_initial_lines_1_2(&dsc,slices,mode)==expected);
                    dpu_hw_dsc current{{},&newer},legacy{{},&older};
                    dpu_hw_dsc_config_1_2(&current,&dsc,mode,old_lines);
                    dpu_hw_dsc_config_1_2(&legacy,&dsc,mode,old_lines);
                    assert((current.hw.writes.at(0x100+ENC_DF_CTRL)&0xff)==expected);
                    assert((legacy.hw.writes.at(0x100+ENC_DF_CTRL)&0xff)==old_lines);
                }
            }
        }
    }
    dsc.slice_width=0;
    assert(dpu_hw_dsc_initial_lines_1_2(&dsc,2,0)==0);
    dsc.slice_width=800; dsc.bits_per_pixel=0;
    assert(dpu_hw_dsc_initial_lines_1_2(&dsc,2,0)==0);
    dsc.bits_per_pixel=65<<4;
    assert(dpu_hw_dsc_initial_lines_1_2(&dsc,2,0)==0);
    dsc.bits_per_pixel=8<<4;
    assert(dpu_hw_dsc_initial_lines_1_2(&dsc,0,0)==0);
    assert(dpu_hw_dsc_initial_lines_1_2(nullptr,2,0)==0);
    dsc.slice_count=0;
    dpu_hw_dsc invalid{{},&newer};
    dpu_hw_dsc_config_1_2(&invalid,&dsc,0,2);
    assert(invalid.hw.writes.empty());
    dsc.slice_count=2; dsc.slice_width=1;
    dpu_hw_dsc_config_1_2(&invalid,&dsc,0,2);
    assert(invalid.hw.writes.empty());
}
CPP
} >> "$work/check.cpp"
"${CXX:-c++}" -std=c++20 -O2 -Wall -Wextra -Werror \
    -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Real DSC latency/writer: O82 active2=3 lines; 8/10/12-bpc, split/mux and width contracts; legacy unchanged; invalid inputs rejected\n'
