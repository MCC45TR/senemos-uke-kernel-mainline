/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
typedef uint32_t u32;
typedef uint32_t __be32;
#define FIELD_GET(mask, value) ((value) & (mask))
#define ARM_SMMU_SMR_ID 0xffff
#define dev_err_probe(dev, error, ...) (error)
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
struct property {const char *name;void *value;int length;bool present;};
struct device_node {const char *path,*compatible;struct device_node *parent;bool enabled;unsigned phandle;struct property props[4];int refs;};
struct iommu_fwspec {unsigned num_ids;u32 ids[3];};
struct device {struct device_node *of_node;struct iommu_fwspec *spec;};
struct arm_smmu_device {struct device *dev;unsigned long context_map[1],boot_context_map[1];unsigned num_context_banks;};
struct arm_smmu_domain {unsigned unused;};
static struct device_node nodes[12],*of_root=&nodes[0];
static bool machine,soc,display,video,cdsp,actlr_match;
static unsigned allocations;static int allocation_error;
static u32 props[6],feprops[6],cells,rules[9];
static unsigned dummy;
static struct iommu_fwspec *dev_iommu_fwspec_get(struct device *d){return d->spec;}
static bool of_machine_is_compatible(const char *s){if(!strcmp(s,"xiaomi,uke"))return machine;assert(!strcmp(s,"qcom,sm7675"));return soc;}
static bool of_device_is_compatible(const struct device_node *n,const char *s){return n&&n->compatible&&!strcmp(n->compatible,s);}
static bool of_device_is_available(const struct device_node *n){return n&&n->enabled;}
static struct device_node *of_find_node_by_path(const char *s){for(unsigned i=0;i<ARRAY_SIZE(nodes);i++)if(nodes[i].path&&!strcmp(s,nodes[i].path)){nodes[i].refs++;return &nodes[i];}return NULL;}
static struct device_node *of_find_node_by_phandle(unsigned id){for(unsigned i=0;i<ARRAY_SIZE(nodes);i++)if(id&&nodes[i].phandle==id){nodes[i].refs++;return &nodes[i];}return NULL;}
static void of_node_put(struct device_node *n){if(n){assert(n->refs>0);n->refs--;}}
static struct property *of_find_property(const struct device_node *n,const char *s,int *len){if(!n)return NULL;for(unsigned i=0;i<ARRAY_SIZE(n->props);i++)if(n->props[i].present&&!strcmp(n->props[i].name,s)){if(len)*len=n->props[i].length;return (struct property *)&n->props[i];}return NULL;}
static const void *of_get_property(const struct device_node *n,const char *s,int *len){struct property *p=of_find_property(n,s,len);return p?p->value:NULL;}
static bool of_property_read_bool(const struct device_node *n,const char *s){return of_find_property(n,s,NULL)!=NULL;}
static u32 be32_to_cpu(u32 x){return __builtin_bswap32(x);}
static u32 be(u32 x){return __builtin_bswap32(x);}
static bool qcom_uke_cdsp_domain(struct arm_smmu_device *s,struct device *d){(void)s;(void)d;return cdsp;}
static bool qcom_uke_video_domain(struct arm_smmu_device *s,struct device *d){(void)s;(void)d;return video;}
static bool qcom_uke_display_domain(struct arm_smmu_device *s,struct device *d){(void)s;(void)d;return display;}
static bool qcom_uke_cdsp_actlr_matches(struct arm_smmu_device *s,struct device *d){(void)s;(void)d;return actlr_match;}
static bool qcom_uke_video_actlr_matches(struct arm_smmu_device *s){(void)s;return actlr_match;}
static bool qcom_uke_display_actlr_matches(struct arm_smmu_device *s){(void)s;return actlr_match;}
static int __arm_smmu_alloc_bitmap(unsigned long *map,int start,unsigned count){assert(map&&*map==1&&start==2&&count==16);allocations++;return allocation_error?allocation_error:7;}
#include "actual-sensor.inc"
#include "actual-hdmi.inc"
#ifndef ORIGINAL
#include "actual-config.inc"
#endif
#include "actual-allocation.inc"
static struct iommu_fwspec spec;
static struct device supplier,client;
static struct arm_smmu_device smmu;
static struct arm_smmu_domain domain;
static void balanced(void){for(unsigned i=0;i<ARRAY_SIZE(nodes);i++)assert(!nodes[i].refs);}
static void property(unsigned node,unsigned index,const char *name,void *value,int length){nodes[node].props[index]=(struct property){name,value,length,true};}
static void reset(void){
 balanced();memset(nodes,0,sizeof(nodes));memset(rules,0,sizeof(rules));
 nodes[0]=(struct device_node){.path="/",.enabled=true};
 nodes[1]=(struct device_node){.path="/audio-config-memory",.compatible="xiaomi,uke-audio-config-memory",.parent=of_root,.enabled=true};
 nodes[2]=(struct device_node){.path="/soc/remoteproc-adsp@03000000/glink-edge/qcom,gpr/service@1",.compatible="qcom,q6apm",.enabled=true};
 nodes[3]=(struct device_node){.path="/soc/remoteproc-adsp@03000000/glink-edge/qcom,gpr/service@1/dais",.compatible="qcom,q6apm-dais",.parent=&nodes[2],.enabled=true};
 nodes[4]=(struct device_node){.path="/soc/iommu",.compatible="qcom,sm7675-boot-smmu",.enabled=true,.phandle=77};
 nodes[5]=(struct device_node){.path="/soc/foreign-iommu",.compatible="qcom,sm7675-boot-smmu",.enabled=true,.phandle=78};
 nodes[6]=(struct device_node){.path="/soc/remoteproc-adsp@03000000/glink-edge/qcom,msm_fastrpc_rpmsg/compute-cb@3",.compatible="qcom,fastrpc-compute-cb",.enabled=true};
 nodes[7]=(struct device_node){.path="/soc/remoteproc-adsp@03000000/glink-edge/qcom,msm_fastrpc_rpmsg/compute-cb@5",.compatible="qcom,fastrpc-compute-cb",.enabled=true};
 const u32 raw[]={77,0x1001,0x80,77,0x1061,0};
 for(unsigned i=0;i<6;i++){props[i]=feprops[i]=be(raw[i]);}
 cells=be(2);
 property(1,0,"iommus",props,sizeof(props));property(2,0,"xiaomi,fs19xx-protected",&dummy,0);
 property(3,0,"iommus",feprops,sizeof(feprops));property(3,1,"xiaomi,hdmi-only",&dummy,0);
 property(5,0,"#iommu-cells",&cells,sizeof(cells));
 property(4,0,"#iommu-cells",&cells,sizeof(cells));property(4,1,"qcom,actlr",rules,0);
 spec=(struct iommu_fwspec){2,{0x801001,0x1061,0}};
 supplier=(struct device){&nodes[4],NULL};client=(struct device){&nodes[1],&spec};
 smmu=(struct arm_smmu_device){&supplier,{1},{1},16};
 machine=soc=actlr_match=true;display=video=cdsp=false;allocations=0;allocation_error=0;
}
static int allocate(void){int ret=qcom_uke_smmu_alloc_context_bank(&domain,&smmu,&client,2);balanced();assert(smmu.context_map[0]==1&&smmu.boot_context_map[0]==1);return ret;}
static void refuse(int error){assert(allocate()==error&&!allocations);}
int main(void){
 reset();assert(allocate()==7&&allocations==1); /* Root first; no FE device lookup. */
#ifndef ORIGINAL
 reset();allocation_error=-ENOSPC;assert(allocate()==-ENOSPC&&allocations==1);
 reset();machine=false;refuse(-EOPNOTSUPP);reset();soc=false;refuse(-EOPNOTSUPP);
 reset();client.of_node=NULL;refuse(-EOPNOTSUPP);reset();client.spec=NULL;refuse(-EINVAL);
 for(unsigned n=0;n<=3;n++){if(n==2)continue;reset();spec.num_ids=n;refuse(n?-EOPNOTSUPP:-EINVAL);}
 for(unsigned i=0;i<2;i++){reset();spec.ids[i]^=1;refuse(-EOPNOTSUPP);}
 reset();nodes[1].parent=&nodes[2];refuse(-EOPNOTSUPP);
 reset();nodes[1].path="/foreign/audio-config-memory";refuse(-EOPNOTSUPP);
 reset();client.of_node=&nodes[8];nodes[8]=nodes[1];nodes[8].path="/foreign";refuse(-EOPNOTSUPP);
 for(unsigned n=1;n<=4;n++){
  reset();nodes[n].compatible="foreign";refuse(-EOPNOTSUPP);
  reset();nodes[n].enabled=false;refuse(-EOPNOTSUPP);
  reset();nodes[n].path=NULL;if(n<4)refuse(-EOPNOTSUPP);
 }
 reset();nodes[2].props[0].present=false;refuse(-EOPNOTSUPP);
 reset();nodes[2].props[0].length=4;refuse(-EOPNOTSUPP);
 reset();nodes[3].parent=&nodes[0];refuse(-EOPNOTSUPP);
 reset();nodes[3].props[1].present=false;refuse(-EOPNOTSUPP);
 reset();nodes[3].props[1].length=4;refuse(-EOPNOTSUPP);
 for(unsigned n=1;n<=3;n+=2){
  reset();nodes[n].props[0].present=false;refuse(-EOPNOTSUPP);
  const int sizes[]={0,4,20,25,28,-1};
  for(unsigned i=0;i<ARRAY_SIZE(sizes);i++){reset();nodes[n].props[0].length=sizes[i];refuse(-EOPNOTSUPP);}
  reset();nodes[n].props[0].value=NULL;refuse(-EOPNOTSUPP);
 }
 for(unsigned i=0;i<6;i++){
  reset();props[i]^=be(1);refuse(-EOPNOTSUPP);
  reset();feprops[i]^=be(1);refuse(-EOPNOTSUPP);
  reset();props[i]^=be(1);feprops[i]=props[i];refuse(-EOPNOTSUPP);
 }
 reset();props[0]=props[3]=feprops[0]=feprops[3]=0;refuse(-EOPNOTSUPP);
 reset();props[0]=props[3]=feprops[0]=feprops[3]=be(78);refuse(-EOPNOTSUPP);
 reset();nodes[4].phandle=0;refuse(-EOPNOTSUPP);
 reset();nodes[4].props[0].present=false;refuse(-EOPNOTSUPP);
 reset();nodes[4].props[0].value=NULL;refuse(-EOPNOTSUPP);
 const int sizes[]={0,3,5,8};for(unsigned i=0;i<ARRAY_SIZE(sizes);i++){reset();nodes[4].props[0].length=sizes[i];refuse(-EOPNOTSUPP);}
 reset();cells=be(1);refuse(-EOPNOTSUPP);
 reset();nodes[4].props[1].length=1;refuse(-EINVAL);
 for(unsigned i=0;i<2;i++){reset();rules[0]=be(i?0x1061:0x1001);rules[1]=0;rules[2]=be(0x103);nodes[4].props[1].length=12;refuse(-EOPNOTSUPP);}
 /* Existing ordinary streams and all three special delegates are unchanged. */
 const u32 legacy[]={0x40,0xb6,0x60,0xa3,0x423,0x436,0x11400};
 for(unsigned i=0;i<ARRAY_SIZE(legacy);i++){reset();client.of_node=&nodes[8];spec.num_ids=1;spec.ids[0]=legacy[i];assert(allocate()==7&&allocations==1);}
 reset();supplier.of_node=&nodes[5];nodes[5].compatible="qcom,sm7675-usb-smmu";spec.num_ids=1;spec.ids[0]=0x40;assert(allocate()==7);
 const u32 foreign[]={0x1c00,0xc03,0x1000,0x1001,0x1060,0x1061,0xffff};
 for(unsigned i=0;i<ARRAY_SIZE(foreign);i++){reset();spec.num_ids=1;spec.ids[0]=foreign[i];refuse(-EOPNOTSUPP);}
 reset();client.of_node=&nodes[3];assert(allocate()==7);
 for(unsigned i=6;i<=7;i++){reset();client.of_node=&nodes[i];spec.ids[0]=i==6?0x801003:0x801005;spec.ids[1]=i==6?0x201043:0x201045;assert(allocate()==7);}
 for(unsigned n=0;n<3;n++){reset();if(n==0)cdsp=true;else if(n==1)video=true;else display=true;assert(allocate()==7);actlr_match=false;allocations=0;refuse(-EINVAL);}
 balanced();puts("Actual root-supplier SMMU allocator: root-first normal DMA, exact OF/SID/controller, property/ACTLR/foreign refusals and legacy delegation passed; synthetic only.");
#endif
}
