#!/usr/bin/env bash
# Execute the prepared kernel's real DSC register writer with host-only MMIO.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
here=$(cd -- "$(dirname -- "$0")" && pwd)
source_file=$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_hw_dsc_1_2.c
catalog=$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_hw_catalog.h
latency=0
if rg -q '^static u32 dpu_hw_dsc_initial_lines_1_2\(' "$source_file"; then latency=1; fi
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
sed -n '/^#define DSC_CMN_MAIN_CNF/,/^static int _dsc_calc_output_buf_max_addr/p' "$source_file" | sed '$d'
awk '/^ \* DSC sub-blocks\/features/ {p=1} p && /^enum/ {e=1}
     p && e {print} p && e && /^};/ {exit}' "$catalog"
sed -n '/^#define DSC_MODE_SPLIT_PANEL/,/^struct dpu_hw_dsc;/p' \
    "$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_hw_dsc.h" | sed '$d'
# Keep the selected upstream DSC structure rather than duplicating its fields.
sed -n '/^#define DSC_NUM_BUF_RANGES/,/^struct drm_dsc_picture_parameter_set {/p' \
    "$kernel/include/drm/display/drm_dsc.h" | sed '$d'
cat <<'CPP'
struct dpu_dsc_sub_blks { struct {u32 base;} enc,ctl; };
static const dpu_dsc_sub_blks dsc_sblk_0{{0x100},{0x1000}},dsc_sblk_1{{0x200},{0x2000}};
enum {DSC_0,DSC_1,DSC_2};
struct dpu_dsc_cfg {
    const char *name; int id; u32 base,len,features; const dpu_dsc_sub_blks *sblk;
};
struct dpu_hw_blk_reg_map { std::map<u32,u32> writes; };
struct dpu_hw_dsc { dpu_hw_blk_reg_map hw; const dpu_dsc_cfg *caps; };
#define DPU_REG_WRITE(hw,offset,value) ((hw)->writes[(offset)]=(value))
static u32 drm_dsc_flatness_det_thresh(const drm_dsc_config *dsc) {
    return 2U << (dsc->bits_per_component-8);
}
CPP
sed -n '/^static const struct dpu_dsc_cfg sm7675_dsc\[\] = {/,/^};/p' \
    "$here/../src/display/dpu_10_1_sm7675.h"
sed -n '/^static int _dsc_calc_output_buf_max_addr/,/^static void dpu_hw_dsc_disable_1_2/p' \
    "$source_file" | sed '$d'
if ((latency)); then
    printf '#define UKE_DSC_NEW_LATENCY\n'
    printf 'static u32 drm_dsc_get_bpp_int(const drm_dsc_config *dsc) {return dsc->bits_per_pixel>>4;}\n'
    sed -n '/^static u32 dpu_hw_dsc_initial_lines_1_2(/,/^static void dpu_hw_dsc_config_1_2(/p' \
        "$source_file" | sed '$d'
fi
sed -n '/^static void dpu_hw_dsc_config_1_2(/,/^static void dpu_hw_dsc_config_thresh_1_2(/p' \
    "$source_file" | sed '$d'
cat <<'CPP'
int main() {
    static_assert(sizeof(sm7675_dsc)/sizeof(sm7675_dsc[0])==3);
    drm_dsc_config dsc{};
    dsc.dsc_version_minor=1; dsc.slice_count=2; dsc.bits_per_pixel=8<<4;
    dsc.pic_width=1600; dsc.pic_height=2136; dsc.slice_width=800; dsc.slice_height=24;
    dsc.initial_xmit_delay=512; dsc.slice_chunk_size=800;
    for(const auto &entry:sm7675_dsc) {
        assert(entry.features&BIT(DPU_DSC_FULL_ICH_PREC));
        for(u32 mode:{0U,DSC_MODE_VIDEO,DSC_MODE_VIDEO|DSC_MODE_MULTIPLEX,
                      DSC_MODE_VIDEO|DSC_MODE_SPLIT_PANEL,
                      DSC_MODE_VIDEO|DSC_MODE_SPLIT_PANEL|DSC_MODE_MULTIPLEX}) {
            for(u32 depth:{8U,10U,12U}) {
                dsc.bits_per_component=depth;
                auto old_caps=entry; old_caps.features&=~BIT(DPU_DSC_FULL_ICH_PREC);
                dpu_hw_dsc old{{},&old_caps},current{{},&entry};
                dpu_hw_dsc_config_1_2(&old,&dsc,mode,2);
                dpu_hw_dsc_config_1_2(&current,&dsc,mode,2);
                const auto offset=entry.sblk->enc.base+ENC_DF_CTRL;
                const auto before=old.hw.writes.at(offset),after=current.hw.writes.at(offset);
                u32 expected_lines=2;
#ifdef UKE_DSC_NEW_LATENCY
                const auto slices=(mode&DSC_MODE_MULTIPLEX) ? dsc.slice_count/2:dsc.slice_count;
                expected_lines=dpu_hw_dsc_initial_lines_1_2(&dsc,slices,mode);
                const bool split_mux=(mode&DSC_MODE_SPLIT_PANEL) && (mode&DSC_MODE_MULTIPLEX);
                assert(expected_lines==(slices==2 || split_mux ? 3U:2U));
#endif
                assert(!(before&BIT(12)));
                assert((before&0xff)==2);
                assert(after==((before&~0xffU)|expected_lines|(depth>8 ? BIT(12):0)));
                assert((after&0xff)==expected_lines);
                current.hw.writes[offset]=(after&~(BIT(12)|0xffU))|(before&0xff);
                assert(current.hw.writes==old.hw.writes);
            }
        }
        dpu_hw_dsc empty{{},&entry};
        dpu_hw_dsc_config_1_2(&empty,nullptr,DSC_MODE_VIDEO,2);
        dpu_hw_dsc_config_1_2(nullptr,&dsc,DSC_MODE_VIDEO,2);
        assert(empty.hw.writes.empty());
    }
}
CPP
} >> "$work/check.cpp"
"${CXX:-c++}" -std=c++20 -O2 -Wall -Wextra -Werror \
    -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/check.cpp" -o "$work/check"
"$work/check"
if ((latency)); then
    printf 'Real DSC writer: precision guard passed; only ENC_DF_CTRL bit 12 and OEM-calculated initial_lines differ; legacy input 2 retained\n'
else
    printf 'Real DSC writer: three SM7675 encoders; 8/10/12-bpc capability guard; only ENC_DF_CTRL bit 12 changes; initial_lines preserved\n'
fi
