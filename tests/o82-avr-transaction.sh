#!/usr/bin/bash
# COPR only. Extract actual production callbacks; never compile on the tablet.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
profile=$kernel/native-profile
cc=${CC:-gcc}
sanitize=${SANITIZE:-0}
[[ $sanitize == 0 || $sanitize == 1 ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <errno.h>
typedef uint32_t u32;
struct drm_encoder {int unused;};
struct drm_display_mode {int lines;};
struct drm_crtc_state {bool vrr_enabled;struct drm_display_mode adjusted_mode;};
struct dpu_hw_intf {
 struct {
  int (*setup_avr)(struct dpu_hw_intf *,u32,u32 *);
  int (*get_avr_period)(struct dpu_hw_intf *,u32 *);
  int (*set_avr_period)(struct dpu_hw_intf *,u32);
  void (*enable_avr)(struct dpu_hw_intf *,bool);
 } ops;
 unsigned int id;u32 period;
};
enum {DPU_ENC_DISABLED, DPU_ENC_ENABLED};
struct dpu_encoder_phys {struct dpu_hw_intf *hw_intf;unsigned int enable_state;};
struct dpu_encoder_virt {
 struct drm_encoder base;bool avr_enabled,avr_failed;unsigned int num_phys_encs;
 struct dpu_encoder_phys *phys_encs[2];int enc_spinlock;
};
static struct dpu_encoder_virt *to_dpu_encoder_virt(struct drm_encoder *e){return (void *)e;}
static bool admitted=true;
static unsigned int o82_vrr_test_min_hz=30;
static bool dpu_encoder_uke_vrr_check(struct drm_encoder *e,const struct drm_crtc_state *s){(void)e;(void)s;return admitted;}
static int qcom_uke_o82_avr_lines(const struct drm_display_mode *m,unsigned int floor){assert(floor==30);return m->lines;}
static void lock(int *held);
static void unlock(int *held);
#define spin_lock_irqsave(p,flags) do{(flags)=0;lock(p);}while(0)
#define spin_unlock_irqrestore(p,flags) do{(void)(flags);unlock(p);}while(0)
C
for signature in 'bool dpu_encoder_uke_avr_active(' 'int dpu_encoder_uke_avr_retime('; do
 awk -v signature="$signature" 'index($0,signature)==1 {emit=1;found=1} emit {print} emit&&/^}/ {exit} END {if(!found)exit 1}' "$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c" >> "$work/check.c"
done
cat "$profile/tests/o82-avr-transaction.c" >> "$work/check.c"
flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -fno-omit-frame-pointer)
[[ $sanitize == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
"$cc" "${flags[@]}" "$work/check.c" -o "$work/check"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/check"
cat > "$work/mmio.c" <<'C'
#include <assert.h>
#include <stdint.h>
#include <errno.h>
typedef uint32_t u32;
struct dpu_hw_intf {struct {u32 period;unsigned int writes;int corrupt;} hw;};
#define INTF_AVR_VTOTAL 0x27c
#define DPU_REG_READ(p,r) ((void)assert((r)==0x27c),(p)->period ^ (unsigned int)(p)->corrupt)
#define DPU_REG_WRITE(p,r,v) do{assert((r)==0x27c);(p)->period=(v);(p)->writes++;}while(0)
C
for name in dpu_hw_intf_get_avr_period dpu_hw_intf_set_avr_period; do
 awk -v name="$name" '$0~("^static int "name"\\("){emit=1;found=1} emit{print} emit&&/^}/{exit} END{if(!found)exit 1}' "$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_hw_intf.c" >> "$work/mmio.c"
done
cat >> "$work/mmio.c" <<'C'
int main(void){
 struct dpu_hw_intf intf={0};u32 period=123;
 assert(dpu_hw_intf_get_avr_period(&intf,&period)==-EIO);
 assert(dpu_hw_intf_set_avr_period(&intf,0)==-EINVAL && !intf.hw.writes);
 for(unsigned int i=0;i<3;i++){
  const u32 value=i==0?1:i==1?933*11088:UINT32_MAX;
  assert(!dpu_hw_intf_set_avr_period(&intf,value));
  assert(!dpu_hw_intf_get_avr_period(&intf,&period) && period==value);
 }
 intf.hw.corrupt=1;
 assert(dpu_hw_intf_set_avr_period(&intf,123)==-EIO);
 assert(intf.hw.writes==4);
 return 0;
}
C
"$cc" "${flags[@]}" "$work/mmio.c" -o "$work/mmio"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/mmio"
if [[ $sanitize == 0 ]]; then
 for mutant in skip-second-restore accept-readback-mismatch omit-failure-latch; do
  awk -v m="$mutant" '
   m=="skip-second-restore" && /if \(intf->ops.set_avr_period\(intf, before\[i\]\)\)/ {print "\t\tif (i == 0 && intf->ops.set_avr_period(intf, before[i]))";n++;next}
   m=="accept-readback-mismatch" && /if \(actual != periods\[i\]\)/ {print "\t\tif (false && actual != periods[i])";n++;next}
   m=="omit-failure-latch" && /^\tenc->avr_failed = true;/ {print "\tenc->avr_failed = false;";n++;next}
   {print} END{if(n!=1)exit 1}
  ' "$work/check.c" > "$work/mutant.c"
  "$cc" "${flags[@]}" "$work/mutant.c" -o "$work/mutant"
  set +e
  (ulimit -c 0; "$work/mutant") > "$work/mutant.log" 2>&1
  status=$?
  set -e
  [[ $status == 134 ]]
  grep -Eq 'Assertion .* failed' "$work/mutant.log"
  printf 'Actual dual-INTF transaction mutant refused:%s/%s.\n' "$cc" "$mutant"
 done
fi
printf 'Actual dual-INTF transaction callbacks passed:%s/sanitize%s; hardware acceptance separate.\n' "$cc" "$sanitize"
