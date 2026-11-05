/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint32_t u32;
typedef uint32_t __be32;
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define ARM_SMMU_SMR_ID 0xffff
#define FIELD_GET(mask, value) ((value) & (mask))
#define ARM_SMMU_DOMAIN_S1 1
#define ARM_SMMU_CB_ACTLR 4
#define dev_err_probe(dev, error, ...) (error)
struct device_node { const char *compatible; };
struct iommu_fwspec { unsigned num_ids; u32 ids[2]; };
struct device { struct device_node *of_node; struct iommu_fwspec *spec; };
struct arm_smmu_device {
    struct device *dev; unsigned long context_map[1], boot_context_map[1];
    unsigned num_context_banks;
};
struct arm_smmu_domain {
    struct arm_smmu_device *smmu; unsigned stage;
    struct { unsigned cbndx; } cfg;
};
struct io_pgtable_cfg { unsigned ias; };
static struct device_node cdsp1={"qcom,fastrpc-compute-cb"},cdsp2={"qcom,fastrpc-compute-cb"};
static struct device_node adsp3={"qcom,fastrpc-compute-cb"},adsp5={"qcom,fastrpc-compute-cb"};
static struct device_node foreign={"qcom,fastrpc-compute-cb"},wrong={"foreign"};
static struct device_node boot={"qcom,sm7675-boot-smmu"},usb={"qcom,sm7675-usb-smmu"};
static bool machine,refuse,hide_rules;
static unsigned allocations,writes,reads,fallbacks,references;
static int allocation_error,rule_bytes;
static u32 reg,rules[18];
static struct iommu_fwspec *dev_iommu_fwspec_get(struct device *d) {return d->spec;}
static bool of_machine_is_compatible(const char *s) {assert(!strcmp(s,"xiaomi,uke"));return machine;}
static bool of_device_is_compatible(struct device_node *n,const char *s) {return n&&!strcmp(n->compatible,s);}
static struct device_node *of_find_node_by_path(const char *s) {
    ++references;
    if(strstr(s,"remoteproc-cdsp@32300000"))return strstr(s,"compute-cb@1")?&cdsp1:&cdsp2;
    return strstr(s,"compute-cb@3")?&adsp3:&adsp5;
}
static void of_node_put(struct device_node *n) {assert(n&&references);--references;}
static const void *of_get_property(struct device_node *n,const char *s,int *len) {
    assert(n==&boot||n==&usb);assert(!strcmp(s,"qcom,actlr"));*len=rule_bytes;
    return hide_rules?NULL:rules;
}
static u32 be32_to_cpu(u32 x) {return __builtin_bswap32(x);}
static bool __attribute__((unused)) test_bit(unsigned bit,const unsigned long *map) {return !!(*map&(1UL<<bit));}
static bool qcom_uke_video_domain(struct arm_smmu_device *s,struct device *d) {(void)s;(void)d;return false;}
static bool qcom_uke_video_actlr_matches(struct arm_smmu_device *s) {(void)s;return true;}
static bool qcom_uke_display_domain(struct arm_smmu_device *s,struct device *d) {(void)s;(void)d;return false;}
static bool qcom_uke_display_actlr_matches(struct arm_smmu_device *s) {(void)s;return true;}
static bool __attribute__((unused)) qcom_uke_hdmi_dma(struct device *d) {(void)d;return false;}
static int __arm_smmu_alloc_bitmap(unsigned long *map,int start,unsigned count) {
    assert(map&&start==2&&count==16);++allocations;return allocation_error?allocation_error:3;
}
static int qcom_uke_init_context(struct arm_smmu_domain *d,struct io_pgtable_cfg *c,struct device *dev) {
    (void)d;(void)c;(void)dev;++fallbacks;return 17;
}
static void arm_smmu_cb_write(struct arm_smmu_device *s,unsigned cb,unsigned offset,u32 value) {
    assert(s&&cb==3&&offset==ARM_SMMU_CB_ACTLR&&value==0x303);
    ++writes;if(!refuse)reg=value;
}
static u32 arm_smmu_cb_read(struct arm_smmu_device *s,unsigned cb,unsigned offset) {
    assert(s&&cb==3&&offset==ARM_SMMU_CB_ACTLR);++reads;return reg;
}
#include "actual-admission.inc"
#include "actual-cdsp.inc"
#include "actual-allocation.inc"
static struct iommu_fwspec spec;
static struct device supplier,client;
static struct arm_smmu_device smmu;
static struct arm_smmu_domain domain;
static struct io_pgtable_cfg cfg;
static void rule(unsigned n,u32 sid,u32 mask,u32 value) {
    rules[3*n]=__builtin_bswap32(sid);rules[3*n+1]=__builtin_bswap32(mask);
    rules[3*n+2]=__builtin_bswap32(value);
}
static void reset(unsigned sid) {
    assert(!references);
    spec=(struct iommu_fwspec){1,{sid,0}};
    supplier=(struct device){&boot,NULL};client=(struct device){sid==0xc01?&cdsp1:&cdsp2,&spec};
    smmu=(struct arm_smmu_device){&supplier,{1},{1},16};
    domain=(struct arm_smmu_domain){&smmu,ARM_SMMU_DOMAIN_S1,{3}};cfg.ias=32;
    machine=true;refuse=hide_rules=false;
    allocations=writes=reads=fallbacks=reg=references=0;allocation_error=0;
    memset(rules,0,sizeof(rules));rule(0,0xc01,0,0x303);rule(1,0xc02,0,0x303);
    rule_bytes=6*sizeof(u32);
}
static int allocate(void) {return qcom_uke_smmu_alloc_context_bank(&domain,&smmu,&client,2);}
static int initialize(void) {return qcom_uke_cdsp_init_context(&domain,&cfg,&client);}
int main(void) {
    for(unsigned sid=0xc01;sid<=0xc02;sid++) {
        reset(sid);assert(allocate()==3&&allocations==1&&!writes);
        assert(initialize()==0&&writes==1&&reads==1&&!fallbacks&&reg==0x303);
        assert(smmu.boot_context_map[0]==1&&smmu.context_map[0]==1&&!references);
    }
    reset(0xc01);allocation_error=-ENOSPC;assert(allocate()==-ENOSPC&&!writes);
    reset(0xc01);hide_rules=true;assert(allocate()==-EINVAL&&!allocations);
    reset(0xc01);rule_bytes=13;assert(allocate()==-EINVAL&&!allocations);
    reset(0xc01);rule_bytes=0;assert(allocate()==-EINVAL&&!allocations);
    reset(0xc01);rule(0,0xc03,0,0x303);assert(allocate()==-EINVAL);
    reset(0xc02);rule(1,0xc02,0,0x103);assert(allocate()==-EINVAL);
    reset(0xc01);rule(0,0xc01,1,0x303);assert(allocate()==-EINVAL);
    reset(0xc01);rule(2,0xc00,1,0x303);rule_bytes=9*sizeof(u32);assert(allocate()==-EINVAL);
    reset(0xc01);rule(2,0xc01,0,0x303);rule_bytes=9*sizeof(u32);assert(allocate()==-EINVAL);
    reset(0xc01);assert(allocate()==3);rule(0,0xc01,0,0x103);assert(initialize()==-EINVAL&&!writes);
    reset(0xc01);domain.stage=2;assert(initialize()==-EOPNOTSUPP&&!writes);
    reset(0xc01);cfg.ias=31;assert(initialize()==-EOPNOTSUPP&&!writes);
    reset(0xc01);domain.cfg.cbndx=16;assert(initialize()==-EBUSY&&!writes);
    reset(0xc01);smmu.boot_context_map[0]|=1UL<<3;assert(initialize()==-EBUSY&&!writes);
    reset(0xc01);refuse=true;assert(initialize()==-EACCES&&writes==1&&reads==1&&!fallbacks);
    reset(0xc01);client.of_node=&foreign;assert(allocate()==-EOPNOTSUPP&&!allocations);
    reset(0xc01);client.of_node=&cdsp2;assert(allocate()==-EOPNOTSUPP);
    reset(0xc01);client.of_node=&wrong;assert(allocate()==-EOPNOTSUPP);
    reset(0xc01);client.of_node=NULL;assert(allocate()==-EOPNOTSUPP);
    reset(0xc01);spec.num_ids=2;assert(allocate()==-EOPNOTSUPP);
    reset(0xc01);client.spec=NULL;assert(allocate()==-EINVAL);
    reset(0xc01);machine=false;assert(allocate()==-EOPNOTSUPP);
    reset(0xc01);supplier.of_node=&usb;assert(allocate()==-EOPNOTSUPP);
    const u32 other[]={0xc00,0xc03,0xc04,0x20c01,0x11400,0x40};
    for(unsigned i=0;i<ARRAY_SIZE(other);i++) {
        reset(0xc01);spec.ids[0]=other[i];assert(!qcom_uke_cdsp_domain(&smmu,&client));
        assert(initialize()==17&&fallbacks==1&&!writes);
    }
    reset(0xc01);client.of_node=&adsp3;spec.num_ids=2;spec.ids[0]=0x801003;spec.ids[1]=0x201043;
    assert(qcom_uke_sensor_cb(&client));assert(!qcom_uke_cdsp_domain(&smmu,&client));
    assert(allocate()==3);assert(initialize()==17&&!writes);
    assert(!references);
    puts("PASS: actual CDSP admission, ACTLR allocation/setup/readback, overlap/duplicate/foreign refusal, boot-bank retention and non-CDSP delegation; synthetic only");
}
