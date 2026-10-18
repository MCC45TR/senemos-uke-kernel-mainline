#!/usr/bin/env bash
# Execute the live AVR retiming functions; no device access.
set -Eeuo pipefail
encoder=${1:?Pass prepared dpu_encoder.c}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
typedef uint32_t u32;
#define EPIPE 32
#define EINVAL 22
#define EIO 5
struct drm_encoder {int unused;};
struct drm_display_mode {int lines;};
struct drm_crtc_state {bool vrr_enabled;struct drm_display_mode adjusted_mode;};
struct dpu_hw_intf {
 struct {int (*setup_avr)(struct dpu_hw_intf *,u32,u32 *);} ops;
 unsigned id,htotal,writes;
};
struct dpu_encoder_phys {struct dpu_hw_intf *hw_intf;};
struct dpu_encoder_virt {
 struct drm_encoder base;bool avr_enabled,avr_failed;unsigned num_phys_encs;
 struct dpu_encoder_phys *phys_encs[2];
};
static struct dpu_encoder_virt *to_dpu_encoder_virt(struct drm_encoder *e){return (void *)e;}
static bool admitted=true,fail_second;
static unsigned o82_vrr_test_min_hz=30;
static bool dpu_encoder_uke_vrr_check(struct drm_encoder *e,const struct drm_crtc_state *s){(void)e;(void)s;return admitted;}
static int qcom_uke_o82_avr_lines(const struct drm_display_mode *m,unsigned floor){assert(floor==30);return m->lines;}
static int setup(struct dpu_hw_intf *intf,u32 lines,u32 *result){
 if(fail_second && intf->id==1)return -EIO;
 ++intf->writes;*result=lines*intf->htotal;return 0;
}
C
for signature in 'bool dpu_encoder_uke_avr_active(' 'int dpu_encoder_uke_avr_retime('; do
 awk -v signature="$signature" 'index($0,signature)==1 {emit=1;found=1} emit {print} emit&&/^}/ {exit} END {if(!found)exit 1}' "$encoder" >> "$work/check.c"
done
cat >> "$work/check.c" <<'C'
int main(void) {
 struct dpu_hw_intf hw[2]={{{setup},0,842,0},{{setup},1,842,0}};
 struct dpu_encoder_phys phys[2]={{&hw[0]},{&hw[1]}};
 struct dpu_encoder_virt enc={.avr_enabled=true,.num_phys_encs=2,.phys_encs={&phys[0],&phys[1]}};
 struct drm_crtc_state state={.vrr_enabled=true,.adjusted_mode={11088}};
 assert(dpu_encoder_uke_avr_active(&enc.base));
 assert(!dpu_encoder_uke_avr_retime(&enc.base,&state));
 assert(hw[0].writes==1 && hw[1].writes==1 && enc.avr_enabled);
 // A second timing group changes both the local horizontal period and total lines.
 hw[0].htotal=hw[1].htotal=933;state.adjusted_mode.lines=9240;
 assert(!dpu_encoder_uke_avr_retime(&enc.base,&state));
 assert(hw[0].writes==2 && hw[1].writes==2 && enc.avr_enabled);
 for(unsigned gate=0;gate<6;gate++) {
  enc.avr_enabled=true;enc.avr_failed=false;enc.num_phys_encs=2;admitted=true;
  state.adjusted_mode.lines=9240;phys[1].hw_intf=&hw[1];
  switch(gate){
  case 0:enc.avr_enabled=false;break;
  case 1:enc.avr_failed=true;break;
  case 2:enc.num_phys_encs=1;break;
  case 3:admitted=false;break;
  case 4:state.adjusted_mode.lines=-EINVAL;break;
  case 5:phys[1].hw_intf=NULL;break;
  }
  unsigned first=hw[0].writes,second=hw[1].writes;
  assert(dpu_encoder_uke_avr_retime(&enc.base,&state)<0);
  assert(hw[0].writes==first && hw[1].writes==second);
 }
 enc.avr_enabled=true;enc.avr_failed=false;enc.num_phys_encs=2;admitted=true;
 state.adjusted_mode.lines=9240;phys[1].hw_intf=&hw[1];
 hw[1].htotal++;
 assert(dpu_encoder_uke_avr_retime(&enc.base,&state)==-EINVAL);
 hw[1].htotal--;fail_second=true;
 assert(dpu_encoder_uke_avr_retime(&enc.base,&state)==-EIO);
 state.vrr_enabled=false;
 assert(!dpu_encoder_uke_avr_retime(&enc.base,&state));
 assert(enc.avr_enabled); // The retiming helper never disables AVR or either DSI.
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/check.c" -o "$work/check"
"$work/check"
printf 'Actual live AVR retiming: two periods, changed timings, scope/fault refusal and retained enable state passed\n'
