#!/usr/bin/env bash
# shellcheck disable=SC2129
# Host-only actual catalog and snapshot-helper bounds check.
set -Eeuo pipefail
kernel=${1:?Pass the selected prepared kernel}
candidate=${2:?Pass the SM7675 catalog}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
base=$kernel/drivers/gpu/drm/msm/disp
extract() {
    awk -v signature="$1" '$0==signature {p=1; found=1} p {print}
        p && /^};?$/ {exit} END {if(!found) exit 1}' "$2"
}
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
typedef uint32_t u32;
#define __iomem
#define GFP_KERNEL 0
#define DPU_HW_BLK_NAME_LEN 16
#define BIT(n) (1UL<<(n))
#define DIV_ROUND_UP(n,d) (((n)+(d)-1)/(d))
#define round_up(n,d) (((n)+(d)-1)&~((d)-1))
enum {DSC_0,DSC_1,DSC_2,DPU_DSC_NATIVE_42x_EN,DPU_DSC_FULL_ICH_PREC};
static unsigned char mmio[0x8f000] __attribute__((aligned(4)));
static uintptr_t reads[16];
static unsigned nreads;
static void *kvzalloc(u32 bytes,int flags) {(void)flags; return calloc(1,bytes);}
static u32 readl_relaxed(const void *address) {
    uintptr_t offset=(const unsigned char *)address-mmio;
    assert(offset%4==0 && offset+4<=sizeof(mmio) && nreads<16);
    reads[nreads++]=offset; return *(const u32 *)address;
}
struct drm_printer {char text[512]; size_t len;};
static void drm_printf(struct drm_printer *p,const char *format,...) {
    va_list args; va_start(args,format);
    int n=vsnprintf(p->text+p->len,sizeof(p->text)-p->len,format,args);
    va_end(args); assert(n>=0 && (size_t)n<sizeof(p->text)-p->len); p->len+=(size_t)n;
}
C
sed -n '/^#define REG_DUMP_ALIGN/p' "$base/msm_disp_snapshot.h" >> "$work/check.c"
sed -n '/^#define DPU_HW_BLK_INFO /,/^$/p' "$base/dpu1/dpu_hw_catalog.h" >> "$work/check.c"
extract 'struct dpu_dsc_blk {' "$base/dpu1/dpu_hw_catalog.h" >> "$work/check.c"
extract 'struct dpu_dsc_sub_blks {' "$base/dpu1/dpu_hw_catalog.h" >> "$work/check.c"
extract 'struct dpu_dsc_cfg {' "$base/dpu1/dpu_hw_catalog.h" >> "$work/check.c"
extract 'static const struct dpu_dsc_sub_blks dsc_sblk_0 = {' "$base/dpu1/dpu_hw_catalog.c" >> "$work/check.c"
extract 'static const struct dpu_dsc_sub_blks dsc_sblk_1 = {' "$base/dpu1/dpu_hw_catalog.c" >> "$work/check.c"
sed -n '/^static const struct dpu_dsc_sub_blks sm7675_dsc_sblk_0 = {/,/^static const struct dpu_intf_cfg sm7675_intf\[\] = {/p' "$candidate" | sed '$d' >> "$work/check.c"
extract 'static void msm_disp_state_dump_regs(u32 **reg, u32 len, void __iomem *base_addr)' "$base/msm_disp_snapshot_util.c" >> "$work/check.c"
extract 'static void msm_disp_state_print_regs(const u32 *dump_addr, u32 len,' "$base/msm_disp_snapshot_util.c" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static void check(u32 base,u32 len) {
    u32 *data=NULL; struct drm_printer p={0}; nreads=0;
    for(u32 i=0;i<0x20;i+=4) *(u32 *)(mmio+base+i)=0x10203000+i;
    msm_disp_state_dump_regs(&data,len,mmio+base);
    assert(data && nreads==len/4);
    for(unsigned i=0;i<nreads;i++) assert(reads[i]==base+4*i && data[i]==0x10203000+4*i);
    msm_disp_state_print_regs(data,len,mmio+base,&p);
    if(len==0x18) {
        assert(strstr(p.text,"0x10 : 10203010 10203014\n"));
        assert(data[6]==0 && data[7]==0);
    } else assert(!strstr(p.text,"0x10 :"));
    free(data);
}
int main(void) {
    assert(sizeof(sm7675_dsc)/sizeof(sm7675_dsc[0])==3);
    const u32 ctl[]={0xf00,0xf80}, enc[]={0x100,0x200};
    for(unsigned i=0;i<2;i++) {
        const struct dpu_dsc_cfg *d=&sm7675_dsc[i];
        assert(d->base==0x80000 && d->len==6 && d->sblk->ctl.len==0x18);
        assert(d->sblk->ctl.base==ctl[i] && d->sblk->enc.base==enc[i] && d->sblk->enc.len==0x9c);
        u32 base=d->base+d->sblk->ctl.base;
        assert(base+0x18<=sizeof(mmio)); check(base,0x18);
        assert(0xae01000+base+0x10==(i ? 0xae81f90:0xae81f10));
    }
    assert(sm7675_dsc[2].sblk==&dsc_sblk_0 && sm7675_dsc[2].base==0x81000);
    assert(dsc_sblk_0.ctl.len==0x10 && dsc_sblk_1.ctl.len==0x10);
    check(0x80000+dsc_sblk_0.ctl.base,0x10);
    check(0x80000+dsc_sblk_1.ctl.base,0x10);
    puts("Actual SM7675 catalog and snapshot helper: six bounded CTL reads/printed words per active DSC; no +18/+1c access; generic and unused spans unchanged");
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-sign-compare -fsanitize=undefined \
    -fsanitize-undefined-trap-on-error "$work/check.c" -o "$work/check"
"$work/check"
