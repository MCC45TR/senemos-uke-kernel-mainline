#!/usr/bin/env bash
# Host fixtures execute the native release function with virtualized SMR writes.
set -Eeuo pipefail
file=${1:?Pass the native display SMMU source}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <errno.h>
#include <string.h>
typedef uint32_t u32;
#define EPROBE_DEFER 517
#define ARM_SMMU_SMR_VALID (1U << 31)
#define ARM_SMMU_SMR_ID 0xffffU
#define ARM_SMMU_SMR_MASK 0xffff0000U
#define ARM_SMMU_GR0_SMR(i) (i)
#define ARM_SMMU_GR0_S2CR(i) (16 + (i))
#define FIELD_PREP(mask, value) (((u32)(value) << __builtin_ctz(mask)) & (mask))
#define S2CR_TYPE_FAULT 2
#define dev_err(...) ((void)0)
struct arm_smmu_smr { bool valid; u32 id, mask; };
struct arm_smmu_s2cr { bool boot_reserved; int count, type, cbndx; };
struct arm_smmu_device {
    int num_mapping_groups, stream_map_mutex;
    bool uke_display_quiesced;
    struct arm_smmu_smr smrs[4];
    struct arm_smmu_s2cr s2crs[4];
};
struct device { const char *of_node; struct arm_smmu_device *data; };
static u32 regs[32];
static int writes, resume_result, refs, locks, reads;
static bool refuse, change_owner;
static void *dev_get_drvdata(struct device *d) { return d->data; }
static int of_device_is_compatible(const char *node, const char *name) { return !strcmp(node, name); }
static int pm_runtime_resume_and_get(struct device *d) { (void)d; if (resume_result < 0) return resume_result; ++refs; return 0; }
static void pm_runtime_put(struct device *d) { (void)d; --refs; }
static void mutex_lock(int *m) { (void)m; ++locks; }
static void mutex_unlock(int *m) { (void)m; --locks; }
static u32 arm_smmu_gr0_read(struct arm_smmu_device *s, int reg) {
    (void)s;
    if (reg==0 && ++reads==2 && change_owner) regs[0]=0x80001c01;
    return regs[reg];
}
static void arm_smmu_gr0_write(struct arm_smmu_device *s, int reg, u32 value) {
    (void)s;
    assert(reg < 4 && (regs[reg] & 0xffff) != 0x1c01);
    assert(value == (regs[reg] & ~ARM_SMMU_SMR_VALID));
    ++writes;
    if (!refuse) regs[reg] = value;
}
C
awk '/^int qcom_uke_display_release/ {emit=1}
     emit && /^EXPORT_SYMBOL/ {exit} emit {print}' "$file" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static struct arm_smmu_device smmu;
static struct device supplier = { "qcom,sm7675-boot-smmu", &smmu };
static struct device display = { "qcom,sm7675-mdss", 0 };
static void setup(void) {
    memset(&smmu, 0, sizeof(smmu)); memset(regs, 0, sizeof(regs));
    writes=refs=locks=resume_result=reads=0; refuse=change_owner=false;
    smmu.num_mapping_groups=4;
    smmu.smrs[0]=(struct arm_smmu_smr){true,0x1c00,2};
    smmu.smrs[1]=(struct arm_smmu_smr){true,0x1c01,0};
    smmu.smrs[2]=(struct arm_smmu_smr){true,0x1400,1};
    for (int i=0;i<3;i++) {
        regs[i]=ARM_SMMU_SMR_VALID | (smmu.smrs[i].mask<<16) | smmu.smrs[i].id;
        smmu.s2crs[i]=(struct arm_smmu_s2cr){true,0,0,7};
    }
}
static int release(void) {
    int ret=qcom_uke_display_release(&supplier,&display);
    assert(refs==0 && locks==0); return ret;
}
int main(void) {
    setup(); assert(release()==0 && writes==1 && regs[0]==0x00021c00);
    assert(!smmu.smrs[0].valid && !smmu.s2crs[0].boot_reserved && smmu.uke_display_quiesced);
    assert(smmu.s2crs[0].type==S2CR_TYPE_FAULT && smmu.s2crs[0].cbndx==0xff);
    assert(regs[1]==0x80001c01 && regs[2]==0x80011400 && smmu.s2crs[1].boot_reserved);
    setup(); refuse=true; assert(release()==-EACCES && writes==1);
    assert(smmu.smrs[0].valid && smmu.s2crs[0].boot_reserved && !smmu.uke_display_quiesced);
    setup(); regs[0]^=1; assert(release()==-EBUSY && writes==0 && !smmu.uke_display_quiesced);
    setup(); change_owner=true; assert(release()==-EBUSY && writes==0 && regs[0]==0x80001c01);
    setup(); smmu.s2crs[0].count=1; assert(release()==-EBUSY && writes==0);
    setup(); smmu.s2crs[0].boot_reserved=false; assert(release()==-EBUSY && writes==0);
    setup(); resume_result=-EAGAIN; assert(release()==-EAGAIN && writes==0);
    setup(); display.of_node="foreign"; assert(release()==-EINVAL && writes==0);
    display.of_node="qcom,sm7675-mdss";
    setup(); supplier.data=0; assert(release()==-EPROBE_DEFER && writes==0);
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror "$work/check.c" -o "$work/check"
"$work/check"
printf 'Native SMMU: identity-preserving release, ownership refusal and secure-stream isolation passed\n'
