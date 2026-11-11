#!/usr/bin/env bash
# COPR only: actual FDT helper on synthetic memory, never a panic/device write.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <string.h>
#include <libfdt.h>
#define UKE_INIT
#include "uke-pstore-dt.h"
static char tree[4096], before[4096];
static int fixture(void) {
 assert(!fdt_create_empty_tree(tree,sizeof(tree)));
 int parent=fdt_add_subnode(tree,0,"reserved-memory"); assert(parent>=0);
 int node=fdt_add_subnode(tree,parent,"ramoops_region"); assert(node>=0);
 fdt32_t reg[]={cpu_to_fdt32(0),cpu_to_fdt32(0xa7000000),cpu_to_fdt32(0),cpu_to_fdt32(0x400000)};
 assert(!fdt_setprop_string(tree,node,"compatible","ramoops"));
 assert(!fdt_setprop(tree,node,"reg",reg,sizeof(reg)));
 assert(!fdt_setprop_u32(tree,node,"mem-type",2));
 assert(!fdt_setprop_u32(tree,node,"console-size",0x200000));
 assert(!fdt_setprop_u32(tree,node,"pmsg-size",0x200000));
 return node;
}
static void refuse(void) {
 memcpy(before,tree,sizeof(tree));
 assert(uke_pstore_graph(tree)<0);
 assert(!memcmp(before,tree,sizeof(tree)));
}
int main(void) {
 int node=fixture(), size;
 fdt32_t reg[4]; memcpy(reg,fdt_getprop(tree,node,"reg",&size),sizeof(reg));
 assert(!uke_pstore_graph(tree));
 node=fdt_path_offset(tree,"/reserved-memory/ramoops_region");
 assert(!memcmp(reg,fdt_getprop(tree,node,"reg",&size),sizeof(reg)));
 assert(uke_pstore_u32(tree,node,"record-size",0x100000));
 assert(uke_pstore_u32(tree,node,"console-size",0x200000));
 assert(uke_pstore_u32(tree,node,"pmsg-size",0x100000));
 assert(uke_pstore_u32(tree,node,"max-reason",2));
 memcpy(before,tree,sizeof(tree)); assert(!uke_pstore_graph(tree));
 assert(!memcmp(before,tree,sizeof(tree)));
 node=fixture(); assert(!fdt_setprop_string(tree,node,"compatible","other")); refuse();
 node=fixture(); assert(!fdt_setprop_u32(tree,node,"reg",0xa7000000)); refuse();
 node=fixture(); reg[1]=cpu_to_fdt32(0xa8000000); assert(!fdt_setprop(tree,node,"reg",reg,sizeof(reg))); refuse();
 node=fixture(); assert(!fdt_setprop_u32(tree,node,"console-size",0x400000)); refuse();
 node=fixture(); assert(!fdt_setprop_u32(tree,node,"record-size",0x1000)); refuse();
 node=fixture(); assert(!fdt_setprop_u32(tree,node,"pmsg-size",0x100000)); refuse();
 node=fixture(); assert(!fdt_setprop_u32(tree,node,"mem-type",0)); refuse();
 node=fixture(); assert(!fdt_setprop_u32(tree,node,"ftrace-size",0x1000)); refuse();
 node=fixture(); assert(!fdt_setprop_string(tree,node,"status","disabled")); refuse();
 return 0;
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -I"$root/src/boot" \
 "$work/check.c" -lfdt -o "$work/check"
"$work/check"
printf 'Actual Uke pstore helper: fixed reservation, panic/oops allocation, preserved console, idempotence and unknown-layout refusal passed; synthetic FDT only\n'
