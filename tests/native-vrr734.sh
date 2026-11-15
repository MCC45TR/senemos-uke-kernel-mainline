#!/usr/bin/bash
# COPR only: execute the actual parameter and native initialization functions.
set -Eeuo pipefail
[[ $# == 1 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
source=$1/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
struct kernel_param {void *arg;};
struct kernel_param_ops {int (*set)(const char *, const struct kernel_param *);int (*get)(char *,const struct kernel_param *);};
static int param_set_uint(const char *text,const struct kernel_param *parameter) {
 char *end;errno=0;unsigned long value=strtoul(text,&end,0);
 if(errno||end==text||*end||*text=='-'||value>UINT_MAX)return -EINVAL;
 *(unsigned int *)parameter->arg=value;return 0;
}
static int param_get_uint(char *text,const struct kernel_param *parameter) {return snprintf(text,32,"%u\n",*(unsigned *)parameter->arg);}
#define module_param_cb(name,ops,arg,mode) static const struct kernel_param_ops *name##_ops=ops;static struct kernel_param name##_parameter={arg}
#define __MODULE_PARM_TYPE(name,type)
#define MODULE_PARM_DESC(name,text)
static int dpu_sm7675_cfg,foreign_cfg;
struct dpu_kms {const int *catalog;};
struct msm_display_info {int intf_type;bool is_cmd_mode;unsigned num_of_h_tiles,h_tile_instance[2];};
#define INTF_DSI 1
static bool uke=true,sm7675=true;
static bool of_machine_is_compatible(const char *name) {
 if(!strcmp(name,"xiaomi,uke"))return uke;
 assert(!strcmp(name,"qcom,sm7675"));return sm7675;
}
C
awk '/^static unsigned int o82_vrr_test_min_hz;/{emit=1}emit{print}
 /^MODULE_PARM_DESC\(o82_vrr_floor_api,/{end=1}end&&/\);$/{n++;exit}END{if(n!=1)exit 1}' "$source" >> "$work/check.c"
awk '/^static void dpu_encoder_uke_vrr_default\(/{emit=1}emit{print}emit&&/^}/{n++;exit}END{if(n!=1)exit 1}' "$source" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static void reset(void) {o82_vrr_test_min_hz=0;o82_vrr_floor_requested=0;uke=true;sm7675=true;}
int main(void) {
 const struct msm_display_info valid={INTF_DSI,false,2,{0,1}};
 struct dpu_kms kms={&dpu_sm7675_cfg};
 assert(o82_vrr_floor_api==1&&!o82_vrr_floor_api_ops->set);
 assert(o82_vrr_floor_api_ops->get((char[32]){0},&o82_vrr_floor_api_parameter)>0);
 for(unsigned fault=0;fault<9;fault++) {
  struct msm_display_info info=valid;reset();kms.catalog=&dpu_sm7675_cfg;
  switch(fault){case 0:uke=false;break;case 1:sm7675=false;break;case 2:kms.catalog=&foreign_cfg;break;
   case 3:info.intf_type=2;break;case 4:info.is_cmd_mode=true;break;case 5:info.num_of_h_tiles=1;break;
   case 6:info.h_tile_instance[0]=1;break;case 7:info.h_tile_instance[1]=0;break;}
  dpu_encoder_uke_vrr_default(&kms,fault==8?NULL:&info);assert(!o82_vrr_test_min_hz);
 }
 reset();kms.catalog=&dpu_sm7675_cfg;
 assert(o82_vrr_test_min_hz_ops->set("29",&o82_vrr_test_min_hz_parameter)==-ERANGE);
 assert(!o82_vrr_floor_requested);dpu_encoder_uke_vrr_default(&kms,&valid);assert(o82_vrr_test_min_hz==30);
 for(unsigned request=0;request<144;request++) {
  if(request&&request<30)continue;
  char value[32];snprintf(value,sizeof(value),"%u",request);reset();
  assert(!o82_vrr_test_min_hz_ops->set(value,&o82_vrr_test_min_hz_parameter));
  assert(o82_vrr_floor_requested);dpu_encoder_uke_vrr_default(&kms,&valid);assert(o82_vrr_test_min_hz==request);
  dpu_encoder_uke_vrr_default(&kms,&valid);assert(o82_vrr_test_min_hz==request);
  assert(o82_vrr_test_min_hz_ops->set("144",&o82_vrr_test_min_hz_parameter)==-ERANGE);
  assert(o82_vrr_test_min_hz==request&&o82_vrr_floor_requested);
 }
 return 0;
}
C
flags=(-std=c11 -Wall -Wextra -Werror)
[[ ${SANITIZE:-0} != 1 ]] || flags+=(-fsanitize=address,undefined -fno-omit-frame-pointer)
"${CC:-gcc}" "${flags[@]}" "$work/check.c" -o "$work/check"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/check"
printf 'Actual native Uke VRR default: nine foreign topology refusals, parser errors, all115 explicit zero/positive policies and repeat initialization passed; no MMIO or physical cadence claim.\n'
