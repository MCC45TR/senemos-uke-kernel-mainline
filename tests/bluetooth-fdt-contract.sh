#!/usr/bin/env bash
# Execute the actual OEM-to-upstream Bluetooth graph translation with libfdt.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel}
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d);trap 'rm -r -- "$work"' EXIT
{
cat <<'C'
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <libfdt.h>
#define UKE_INIT
C
awk '/^static int UKE_INIT uke_path_reg/ {emit=1} emit {print} emit && /^}/ {exit}' "$root/src/boot/uke-abl.c"
cat "${UKE_BT_HEADER:-$root/src/boot/uke-bluetooth.h}"
cat <<'C'
static const char path[]="/soc/qcom,qupv3_1_geni_se@8c0000/qcom,qup_uart@888000";
static void cells(void *fdt,int node,const char *key,const unsigned *values,unsigned count) {
 fdt32_t data[8];assert(count<=8);
 for(unsigned i=0;i<count;i++)data[i]=cpu_to_fdt32(values[i]);
 assert(!fdt_setprop(fdt,node,key,data,count*4));
}
static int add(void *fdt,int parent,const char *name,unsigned phandle) {
 int n=fdt_add_subnode(fdt,parent,name);assert(n>=0);
 if(phandle)assert(!fdt_setprop_u32(fdt,n,"phandle",phandle));
 return n;
}
static void fixture(void *fdt) {
 assert(!fdt_create_empty_tree(fdt,32768));
 int soc=add(fdt,0,"soc",0),n;
 add(fdt,soc,"interrupt-controller@17100000",3);
 soc=fdt_path_offset(fdt,"/soc");add(fdt,soc,"clock-controller@100000",2);
 soc=fdt_path_offset(fdt,"/soc");add(fdt,soc,"pinctrl@f000000",1);
 for(unsigned state=0;state<2;state++)for(unsigned i=0;i<4;i++) {
  char name[16],pin[16],function[24];snprintf(name,sizeof(name),"state%u-%u",state,i);
  n=add(fdt,fdt_node_offset_by_phandle(fdt,1),name,100+state*100+i);
  n=add(fdt,n,"mux",0);snprintf(pin,sizeof(pin),"gpio%u",40+i);
  snprintf(function,sizeof(function),state?"gpio":"qup1_se2_l%u",i);
  assert(!fdt_setprop_string(fdt,n,"pins",pin));
  assert(!fdt_setprop_string(fdt,n,"function",function));
 }
 n=add(fdt,fdt_node_offset_by_phandle(fdt,1),"bt_en_sleep",300);
 n=add(fdt,n,"mux",0);assert(!fdt_setprop_string(fdt,n,"pins","gpio156"));
 assert(!fdt_setprop_string(fdt,n,"function","gpio"));
 soc=fdt_path_offset(fdt,"/soc");n=add(fdt,soc,"qcom,qupv3_1_geni_se@8c0000",0);
 n=add(fdt,n,"qcom,qup_uart@888000",0);
 assert(!fdt_setprop_string(fdt,n,"compatible","qcom,msm-geni-serial-hs"));
 cells(fdt,n,"reg",(unsigned[]){0x888000,0x4000},2);
 cells(fdt,n,"clocks",(unsigned[]){2,90},2);
 cells(fdt,n,"interrupts-extended",(unsigned[]){3,0,584,4,1,43,4},7);
 cells(fdt,n,"pinctrl-1",(unsigned[]){100,101,102,103},4);
 cells(fdt,n,"pinctrl-3",(unsigned[]){200,201,202,203},4);
 assert(!fdt_setprop_string(fdt,n,"pinctrl-2","unused"));
 soc=fdt_path_offset(fdt,"/soc");n=add(fdt,soc,"bt_wcn6750",0);
 assert(!fdt_setprop_string(fdt,n,"compatible","qcom,wcn6750-bt"));
 assert(!fdt_setprop_string(fdt,n,"pinctrl-names","default"));
 cells(fdt,n,"pinctrl-0",(unsigned[]){300},1);
 cells(fdt,n,"qcom,bt-reset-gpio",(unsigned[]){1,156,0},3);
 cells(fdt,n,"qcom,bt-sw-ctrl-gpio",(unsigned[]){1,80,0},3);
 const char *names[]={"io","aon","dig","rfacmn","rfa-0p8","rfa1","rfa2","ipa-2p2"};
 const char *resources[]={"ldob7","smpb3","smpb3","smpb3","smpb3","smpb1","smpb2","smpe3"};
 for(unsigned i=0;i<8;i++) {
  char name[48];snprintf(name,sizeof(name),"resource%u",i);
  int p=add(fdt,0,name,0);assert(!fdt_setprop_string(fdt,p,"qcom,resource-name",resources[i]));
  add(fdt,p,"regulator",400+i);
  n=fdt_path_offset(fdt,"/soc/bt_wcn6750");
  snprintf(name,sizeof(name),"qcom,bt-vdd-%s-supply",names[i]);
  cells(fdt,n,name,(unsigned[]){400+i},1);
  snprintf(name,sizeof(name),"qcom,bt-vdd-%s-config",names[i]);
  cells(fdt,n,name,(unsigned[]){0,0,0,1},4);
 }
}
int main(void) {
 _Alignas(8) char fdt[32768];fixture(fdt);
 assert(!uke_bluetooth(fdt));
 int n=fdt_path_offset(fdt,path),length;
 const fdt32_t *v=fdt_getprop(fdt,n,"interrupts-extended",&length);
 unsigned expected[]={3,0,584,4,1,43,2};assert(v&&length==28);
 for(unsigned i=0;i<7;i++)assert(fdt32_to_cpu(v[i])==expected[i]);
 assert(!fdt_node_check_compatible(fdt,n,"qcom,geni-uart"));
 assert(fdt_subnode_offset(fdt,n,"bluetooth")>=0);
 for(unsigned cell=0;cell<7;cell++) {
  fixture(fdt);n=fdt_path_offset(fdt,path);
  fdt32_t *w=fdt_getprop_w(fdt,n,"interrupts-extended",&length);assert(w&&length==28);
  w[cell]=cpu_to_fdt32(fdt32_to_cpu(w[cell])+1);
  assert(uke_bluetooth(fdt)==-FDT_ERR_BADVALUE);
  assert(!fdt_node_check_compatible(fdt,n,"qcom,msm-geni-serial-hs"));
  assert(fdt_subnode_offset(fdt,n,"bluetooth")==-FDT_ERR_NOTFOUND);
 }
 fixture(fdt);n=fdt_path_offset(fdt,path);assert(!fdt_delprop(fdt,n,"interrupts-extended"));
 assert(uke_bluetooth(fdt)==-FDT_ERR_BADVALUE);
 return 0;
}
C
} > "$work/check.c"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-sign-compare \
 -I "$kernel/scripts/dtc/libfdt" "$work/check.c" "$kernel"/scripts/dtc/libfdt/*.c -o "$work/check"
"$work/check"
echo 'Actual Bluetooth FDT translation: only the exact OEM wake IRQ becomes falling-edge; main IRQ and GPIO remain unchanged; foreign/missing contracts refuse mutation'
