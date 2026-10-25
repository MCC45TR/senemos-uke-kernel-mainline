#!/usr/bin/env bash
set -Eeuo pipefail
file=${1:?Pass prepared dpu_kms.c}
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#define BIT(n) (1U << (n))
enum { DRM_MODE_ENCODER_DSI=6, DRM_MODE_ENCODER_TMDS=2, DRM_MODE_ENCODER_VIRTUAL=5 };
struct drm_encoder { unsigned encoder_type,possible_crtcs,possible_clones; };
struct drm_device { struct { unsigned num_crtc; } mode_config; struct drm_encoder encoders[5]; unsigned count; };
struct dpu_mdss_cfg { unsigned cwb_count; } dpu_sm7675_cfg,foreign;
#define drm_for_each_encoder(e,d) for(unsigned idx=0;idx<(d)->count && ((e)=&(d)->encoders[idx],true);idx++)
static unsigned dpu_encoder_get_clones(struct drm_encoder *e) {(void)e;return 0x5a;}
static void apply(struct drm_device *dev,const struct dpu_mdss_cfg *catalog) {
 struct drm_encoder *encoder;
 unsigned num_encoders=0,num_dsi=0,num_tmds=0;
 (void)num_dsi;(void)num_tmds;
C
awk '/^\tnum_encoders = 0;/{emit=1} emit&&/^\tmax_crtc_count =/{exit} emit{print}' "$file" >> "$work/check.c"
awk '/\/\* (All CRTCs are compatible|Keep the Uke SST pipelines)/{emit=1} emit&&/^\treturn 0;/{exit} emit{print}' "$file" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
 (void)num_encoders;
}
int main(void) {
 for(unsigned own=0;own<2;own++) for(unsigned crtcs=1;crtcs<4;crtcs++)
 for(unsigned dsi=0;dsi<3;dsi++) for(unsigned dp=0;dp<3;dp++) for(unsigned wb=0;wb<2;wb++) {
  if(dsi+dp+wb>5)continue;
  struct drm_device dev={.mode_config={.num_crtc=crtcs}};
  for(unsigned i=0;i<dsi+dp+wb;i++)dev.encoders[dev.count++].encoder_type=i<dsi?DRM_MODE_ENCODER_DSI:i<dsi+dp?DRM_MODE_ENCODER_TMDS:DRM_MODE_ENCODER_VIRTUAL;
  apply(&dev,own?&dpu_sm7675_cfg:&foreign);
  unsigned all=(1U<<crtcs)-1;
  for(unsigned i=0;i<dev.count;i++) {
   unsigned expected=all;
   if(own&&dsi==1&&dp==1&&crtcs>=2) {
    if(dev.encoders[i].encoder_type==DRM_MODE_ENCODER_DSI)expected=BIT(0);
    if(dev.encoders[i].encoder_type==DRM_MODE_ENCODER_TMDS)expected=all&~BIT(0);
   }
   assert(dev.encoders[i].possible_crtcs==expected && expected);
  }
 }
 puts("Actual encoder masks: independent Uke SST outputs, foreign/headless/multiple-output/writeback fallbacks passed; tablet test pending");
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror "$work/check.c" -o "$work/check"
"$work/check"
