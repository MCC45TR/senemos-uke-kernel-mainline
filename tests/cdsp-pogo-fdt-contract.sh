#!/usr/bin/env bash
# Synthetic FDT only; uses the actual conversion helpers, runs on COPR.
set -Eeuo pipefail
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libfdt.h>
#define UKE_INIT
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
C
for f in uke_path_reg uke_delete_optional; do
    awk -v f="$f" '$0 ~ "^static int UKE_INIT " f "\\(" {p=1} p{print} p&&/^}/{exit}' \
        "$owner/src/boot/uke-abl.c" >> "$work/check.c"
done
cat >> "$work/check.c" <<'C'
#include "uke-cdsp-pogo.h"
static int path(void *fdt,const char *name) {
    int n=fdt_path_offset(fdt,name);
    if(n>=0)return n;
    char buf[256];assert(strlen(name)<sizeof(buf));strcpy(buf,name);
    char *slash=strrchr(buf,'/');assert(slash);*slash=0;
    int parent=slash==buf?0:path(fdt,buf);
    n=fdt_add_subnode(fdt,parent,slash+1);assert(n>=0);return n;
}
static void cells(void *fdt,const char *name,const char *key,const unsigned *v,size_t count) {
    fdt32_t wire[16];assert(count<=16);for(size_t i=0;i<count;i++)wire[i]=cpu_to_fdt32(v[i]);
    assert(!fdt_setprop(fdt,path(fdt,name),key,wire,count*4));
}
static void one(void *fdt,const char *name,const char *key,unsigned v) { cells(fdt,name,key,&v,1); }
static void str(void *fdt,const char *name,const char *key,const char *v) { assert(!fdt_setprop_string(fdt,path(fdt,name),key,v)); }
static void flag(void *fdt,const char *name,const char *key) { assert(!fdt_setprop(fdt,path(fdt,name),key,NULL,0)); }
static void baseline(void *fdt) {
    assert(!fdt_create_empty_tree(fdt,65536));
    const unsigned reg[]={0x32300000,0x10000};
    str(fdt,UKE_CDSP_PATH,"compatible","qcom,cliffs-cdsp-pas");cells(fdt,UKE_CDSP_PATH,"reg",reg,2);
    const unsigned mem[]={10,11};cells(fdt,UKE_CDSP_PATH,"memory-region",mem,2);
    one(fdt,UKE_CDSP_PATH,"global-sync-mem-reg",12);
    for(unsigned i=0;i<3;i++) {
        char name[80];snprintf(name,sizeof(name),"/reserved-memory/region%u",i);
        one(fdt,name,"phandle",10+i);cells(fdt,name,"reg",i==0?(unsigned[]){0,0x99900000,0,0x1400000}:
            i==1?(unsigned[]){0,0x9ad00000,0,0x80000}:(unsigned[]){0,0x82600000,0,0x100000},4);
        flag(fdt,name,"no-map");
    }
    one(fdt,"/soc/apps-smmu@15000000","phandle",20);
    for(unsigned i=0;i<2;i++) {
        char name[128];snprintf(name,sizeof(name),"/soc/qcom,msm_fastrpc/qcom,msm_fastrpc_compute_cb%u",i+1);
        str(fdt,name,"compatible","qcom,msm-fastrpc-compute-cb");str(fdt,name,"label","cdsprpc-smd");
        one(fdt,name,"pd-type",i?7:1);cells(fdt,name,"iommus",(unsigned[]){20,0xc01+i,0},3);
        flag(fdt,name,"dma-coherent");str(fdt,name,"status","disabled");
    }
    str(fdt,UKE_CDSP_RPC,"compatible","qcom,msm-fastrpc-rpmsg");
    str(fdt,UKE_CDSP_RPC,"qcom,glink-channels","fastrpcglink-apps-dsp");
    cells(fdt,UKE_CDSP_RPC,"qcom,intents",(unsigned[]){100,64},2);
    one(fdt,"/soc/pinctrl@f000000","phandle",30);
    one(fdt,"/soc/qcom,gpi-dma@a00000","phandle",40);
    str(fdt,UKE_POGO_BUS,"compatible","qcom,i2c-geni");
    cells(fdt,UKE_POGO_BUS,"reg",(unsigned[]){0xa8c000,0x4000},2);
    cells(fdt,UKE_POGO_BUS,"dmas",(unsigned[]){40,0,3,3,64,0,40,1,3,3,64,0},12);
    str(fdt,UKE_POGO_NODE,"compatible","nanosic,803");one(fdt,UKE_POGO_NODE,"reg",0x4c);
    const char *props[]={"irq_pin","reset_pin","status_pin","sleep_pin"};
    const unsigned gpio[]={116,127,128,98};
    for(unsigned i=0;i<4;i++)cells(fdt,UKE_POGO_NODE,props[i],(unsigned[]){30,gpio[i],i?0:0x2001},3);
    const char *resource[]={"ldob22","ldob23"};
    const unsigned volt[]={3300000,1800000};
    for(unsigned i=0;i<2;i++) {
        char parent[128],name[160];snprintf(parent,sizeof(parent),"/soc/rpmh-regulator-%s",resource[i]);
        snprintf(name,sizeof(name),"%s/rail",parent);str(fdt,parent,"qcom,resource-name",resource[i]);
        one(fdt,name,"phandle",50+i);one(fdt,name,"regulator-min-microvolt",volt[i]);
        one(fdt,name,"regulator-max-microvolt",volt[i]);
        one(fdt,UKE_POGO_NODE,i?"dvdd-supply":"vdd-supply",50+i);
    }
}
int main(void) {
    void *base=malloc(65536),*fdt=malloc(65536);assert(base&&fdt);baseline(base);
    memcpy(fdt,base,65536);assert(!uke_cdsp(fdt)&&!uke_pogo(fdt));
    int n=fdt_path_offset(fdt,UKE_CDSP_PATH),bytes;
    const fdt32_t *p=fdt_getprop(fdt,n,"memory-region",&bytes);assert(p&&bytes==12&&fdt32_to_cpu(p[2])==12);
    assert(!fdt_getprop(fdt,fdt_path_offset(fdt,UKE_CDSP_RPC),"qcom,non-secure-domain",NULL));
    assert(!fdt_getprop(fdt,fdt_path_offset(fdt,UKE_CDSP_RPC),"qcom,vmids",NULL));
    assert(!uke_cp_cells(fdt,fdt_path_offset(fdt,UKE_CDSP_RPC "/compute-cb@2"),"iommus",(unsigned[]){20,0xc02,0},3));
    assert(!uke_cp_string(fdt,fdt_path_offset(fdt,UKE_POGO_BUS),"compatible","qcom,geni-i2c"));
    assert(!uke_cp_cells(fdt,fdt_path_offset(fdt,UKE_POGO_NODE),"reset-gpios",(unsigned[]){30,127,1},3));
    assert(!uke_cp_cells(fdt,fdt_path_offset(fdt,UKE_POGO_NODE),"wake-gpios",(unsigned[]){30,98,0},3));
    memcpy(fdt,base,65536);one(fdt,"/reserved-memory/region0","reg",0);assert(uke_cdsp(fdt)<0);
    memcpy(fdt,base,65536);flag(fdt,UKE_CDSP_RPC,"qcom,non-secure-domain");assert(uke_cdsp(fdt)<0);
    memcpy(fdt,base,65536);one(fdt,UKE_CDSP_RPC,"qcom,vmids",30);assert(uke_cdsp(fdt)<0);
    const char *cb="/soc/qcom,msm_fastrpc/qcom,msm_fastrpc_compute_cb2";
    for(unsigned i=0;i<3;i++) {
        unsigned maps[]={20,0xc02,0};maps[i]++;
        memcpy(fdt,base,65536);cells(fdt,cb,"iommus",maps,3);assert(uke_cdsp(fdt)<0);
    }
    memcpy(fdt,base,65536);one(fdt,cb,"pd-type",1);assert(uke_cdsp(fdt)<0);
    memcpy(fdt,base,65536);flag(fdt,cb,"qcom,secure-context-bank");assert(uke_cdsp(fdt)<0);
    for(unsigned i=0;i<3;i++) {
        unsigned gpio[]={30,127,0};gpio[i]++;
        memcpy(fdt,base,65536);cells(fdt,UKE_POGO_NODE,"reset_pin",gpio,3);assert(uke_pogo(fdt)<0);
    }
    memcpy(fdt,base,65536);one(fdt,"/soc/rpmh-regulator-ldob22/rail","regulator-max-microvolt",3300001);assert(uke_pogo(fdt)<0);
    memcpy(fdt,base,65536);cells(fdt,UKE_POGO_BUS,"dmas",(unsigned[]){40,0,4,3,64,0,40,1,3,3,64,0},12);assert(uke_pogo(fdt)<0);
    memcpy(fdt,base,65536);one(fdt,UKE_POGO_NODE,"reg",0x4d);assert(uke_pogo(fdt)<0);
    free(fdt);free(base);
    puts("PASS: actual CDSP/pogo FDT conversion, exact memory/SID/PD/GPIO/voltage/DMA admission; synthetic tree, COPR only");
}
C
"${CC:-cc}" -std=gnu11 -O1 -Wall -Wextra -Werror ${CFLAGS:-} \
    -I"$owner/src/boot" "$work/check.c" -lfdt -o "$work/check"
"$work/check"
