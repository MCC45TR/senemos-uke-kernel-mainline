#!/usr/bin/env bash
# Actual FDT helper with the prepared kernel's bundled libfdt; host only.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel}
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d); trap 'rm -r -- "$work"' EXIT
{
cat <<'C'
#include <assert.h>
#include <string.h>
#include <libfdt.h>
#define UKE_INIT
#define ARRAY_SIZE(array) (sizeof(array) / sizeof((array)[0]))
C
awk '/^static int UKE_INIT uke_empty_spmi_bus/ {emit=1} emit {print} emit && /^}/ {exit}' "$root/src/boot/uke-abl.c"
awk '/^static int UKE_INIT uke_empty_demura_regions/ {emit=1} emit {print} emit && /^}/ {exit}' "$root/src/boot/uke-abl.c"
cat <<'C'
static const char path[]="/soc/qcom,spmi@c432000";
static void fixture(void *tree) {
 assert(!fdt_create_empty_tree(tree,4096));
 int soc=fdt_add_subnode(tree,0,"soc");assert(soc>=0);
 int node=fdt_add_subnode(tree,soc,"qcom,spmi@c432000");assert(node>=0);
 assert(!fdt_setprop_string(tree,node,"compatible","qcom,spmi-pmic-arb"));
 unsigned values[]={0xc432000,0x4000,0xc400000,0x3000,0xc500000,0x400000,0xc440000,0x80000,0xc4d000,0x10000};
 fdt32_t reg[10];for(unsigned i=0;i<10;i++)reg[i]=cpu_to_fdt32(values[i]);
 assert(!fdt_setprop(tree,node,"reg",reg,sizeof(reg)));
 assert(!fdt_setprop_u32(tree,node,"qcom,bus-id",1));
 assert(!fdt_setprop_u32(tree,node,"phandle",123));
 assert(!fdt_setprop_string(tree,node,"status","okay"));
}
static void state(void *tree,const char *expected) {
 int node=fdt_path_offset(tree,path),size;
 const char *actual=fdt_getprop(tree,node,"status",&size);
 assert(actual && size==(int)strlen(expected)+1 && !strcmp(actual,expected));
 assert(fdt_get_phandle(tree,node)==123);
}
static void demura_fixture(void *tree) {
 assert(!fdt_create_empty_tree(tree,4096));
 int parent=fdt_add_subnode(tree,0,"reserved-memory");assert(parent>=0);
 for(unsigned i=0;i<2;i++) {
  int node=fdt_add_subnode(tree,parent,i ? "demura_region_1" : "demura_region_0");assert(node>=0);
  fdt32_t reg[4]={0};assert(!fdt_setprop(tree,node,"reg",reg,sizeof(reg)));
  assert(!fdt_setprop_u32(tree,node,"phandle",123+i));
 }
}
static void demura_state(void *tree,unsigned i,int disabled) {
 int node=fdt_path_offset(tree,i ? "/reserved-memory/demura_region_1" : "/reserved-memory/demura_region_0");
 const char *status=fdt_getprop(tree,node,"status",NULL);
 assert(disabled ? status && !strcmp(status,"disabled") : !status);
 assert(fdt_get_phandle(tree,node)==123+i);
}
int main(void) {
 _Alignas(8) char tree[4096];fixture(tree);
 _Alignas(8) char misaligned[4104];
 assert(fdt_create_empty_tree(misaligned+1,4096)==-FDT_ERR_ALIGNMENT);
 assert(!uke_empty_spmi_bus(tree));state(tree,"disabled");
 fixture(tree);int node=fdt_path_offset(tree,path);
 assert(fdt_add_subnode(tree,node,"pmic@0")>=0);
 assert(!uke_empty_spmi_bus(tree));state(tree,"okay");
 for(unsigned i=0;i<10;i++) {
  fixture(tree);node=fdt_path_offset(tree,path);int length;
  fdt32_t *reg=fdt_getprop_w(tree,node,"reg",&length);assert(reg && length==40);
  reg[i]=cpu_to_fdt32(fdt32_to_cpu(reg[i])+1);
  assert(!uke_empty_spmi_bus(tree));state(tree,"okay");
 }
 for(const char **property=(const char *[]) {"reg","compatible","qcom,bus-id",NULL};*property;property++) {
  fixture(tree);node=fdt_path_offset(tree,path);assert(!fdt_delprop(tree,node,*property));
  assert(!uke_empty_spmi_bus(tree));state(tree,"okay");
 }
 fixture(tree);node=fdt_path_offset(tree,path);
 assert(!fdt_setprop_u32(tree,node,"qcom,bus-id",0));
 assert(!uke_empty_spmi_bus(tree));state(tree,"okay");
 fixture(tree);assert(!fdt_pack(tree));
 assert(uke_empty_spmi_bus(tree)==-FDT_ERR_NOSPACE);state(tree,"okay");
 demura_fixture(tree);assert(!uke_empty_demura_regions(tree));
 demura_state(tree,0,1);demura_state(tree,1,1);
 for(unsigned i=0;i<2;i++)for(unsigned cell=0;cell<4;cell++) {
  demura_fixture(tree);int n=fdt_path_offset(tree,i ? "/reserved-memory/demura_region_1" : "/reserved-memory/demura_region_0");
  int size;fdt32_t *reg=fdt_getprop_w(tree,n,"reg",&size);assert(size==16);
  reg[cell]=cpu_to_fdt32(1);assert(!uke_empty_demura_regions(tree));
  demura_state(tree,i,0);demura_state(tree,!i,1);
 }
 for(unsigned variant=0;variant<5;variant++) {
  demura_fixture(tree);int n=fdt_path_offset(tree,"/reserved-memory/demura_region_0");
  switch(variant) {
   case 0:assert(!fdt_delprop(tree,n,"reg"));break;
   case 1:assert(!fdt_setprop_u32(tree,n,"reg",0));break;
   case 2:assert(!fdt_setprop_string(tree,n,"compatible","shared-dma-pool"));break;
   case 3:assert(!fdt_setprop_u32(tree,n,"size",4096));break;
   case 4:assert(fdt_add_subnode(tree,n,"child")>=0);break;
  }
  assert(!uke_empty_demura_regions(tree));demura_state(tree,0,0);demura_state(tree,1,1);
 }
 demura_fixture(tree);assert(!fdt_pack(tree));
 assert(uke_empty_demura_regions(tree)==-FDT_ERR_NOSPACE);
 demura_state(tree,0,0);demura_state(tree,1,0);
 return 0;
}
C
} > "$work/check.c"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -I "$kernel/scripts/dtc/libfdt" \
 "$work/check.c" "$kernel"/scripts/dtc/libfdt/*.c -o "$work/check"
"$work/check"
echo 'Only the exact empty Uke secondary SPMI bus is disabled; populated, foreign and missing resource contracts remain unchanged; no-space errors propagate'
echo 'Only unused zero-length OEM demura placeholders are disabled; populated carveouts, providers and phandles are preserved'
