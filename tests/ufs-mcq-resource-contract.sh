#!/usr/bin/env bash
# Actual UFS callbacks with host-only resources, mappings and readl interception.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint32_t u32;
typedef uint64_t resource_size_t;
#define __iomem
#define GENMASK(h, l) ((UINT32_MAX >> (31 - (h))) & (UINT32_MAX << (l)))
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define U32_MAX UINT32_MAX
#define IORESOURCE_MEM 1
#define dev_err(...) ((void)0)
#define IS_ERR(p) ((uintptr_t)(p) >= (uintptr_t)-4095)
#define PTR_ERR(p) ((int)(intptr_t)(p))
enum { OPR_SQD, OPR_SQIS, OPR_CQD, OPR_CQIS, OPR_MAX };
struct resource { resource_size_t start, end; const char *name; };
struct platform_device { int unused; };
struct device { bool *of_node; };
struct ufshcd_mcq_opr_info_t { u32 offset, stride; unsigned char *base; };
struct ufs_hba {
    struct device *dev;
    unsigned int nr_hw_queues;
    u32 mcq_capabilities;
    unsigned char *mcq_base;
    struct ufshcd_mcq_opr_info_t mcq_opr[OPR_MAX];
};
struct ufs_qcom_host { unsigned char *mcq_sqd_base, *mcq_vs_base; u32 mcq_sqd_offset; };
static struct ufs_qcom_host host;
static struct resource resources[4];
static unsigned char memory[4][0x10000];
static int missing, map_calls, fail_map;
static bool cliffs;
static const void *last_read;
static const char * const names[] = { "std", "mcq", "mcq-sqd", "mcq-vs" };
static inline struct ufs_qcom_host *ufshcd_get_variant(struct ufs_hba *hba) { (void)hba; return &host; }
static struct platform_device *to_platform_device(struct device *dev) { (void)dev; return NULL; }
static inline bool of_device_is_compatible(bool *node, const char *name) {
    return node && *node && !strcmp(name, "qcom,sm7675-ufshc");
}
static struct resource *platform_get_resource_byname(struct platform_device *pdev, int type, const char *name) {
    (void)pdev; (void)type;
    for (int i = 0; i < 4; i++) if (!strcmp(names[i], name)) return missing == i ? NULL : &resources[i];
    return NULL;
}
static inline resource_size_t resource_size(struct resource *res) { return res->end - res->start + 1; }
static unsigned char *devm_ioremap_resource(struct device *dev, struct resource *res) {
    (void)dev;
    if (++map_calls == fail_map) return (void *)(intptr_t)-ENOMEM;
    return memory[res - resources];
}
static u32 readl(const void *addr) {
    u32 value;
    last_read = addr; memcpy(&value, addr, sizeof(value)); return value;
}
C
awk '/^#define MCQ_QCFGPTR_MASK/ { emit=1 } emit { print } /^#define MCQ_QCFG_SIZE/ { exit }' \
    "$kernel/drivers/ufs/host/ufs-qcom.c" >> "$work/check.c"
awk '/^#define UFS_QCOM_MCQCAP_QCFGPTR/ { emit=1 } emit { print } /^#define UFS_MEM_CQIS_VS/ { exit }' \
    "$kernel/drivers/ufs/host/ufs-qcom.h" >> "$work/check.c"
awk '/^static int ufs_qcom_(mcq_config_cliffs|mcq_config_resource|op_runtime_config|get_outstanding_cqs)\(/ { emit=1 } \
    emit { print } emit && /^}/ { emit=0 }' \
    "$kernel/drivers/ufs/host/ufs-qcom.c" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static void reset(struct ufs_hba *hba) {
    memset(&host, 0, sizeof(host)); memset(hba->mcq_opr, 0, sizeof(hba->mcq_opr));
    hba->mcq_base = NULL; hba->nr_hw_queues = 8; hba->mcq_capabilities = 0xe00007;
    missing = -1; map_calls = fail_map = 0; last_read = NULL; cliffs = true;
    resources[0] = (struct resource){0x1d84000, 0x1d86fff, names[0]};
    resources[1] = (struct resource){0x1da0000, 0x1da01ff, names[1]};
    resources[2] = (struct resource){0x1da5000, 0x1da6fff, names[2]};
    resources[3] = (struct resource){0x1da4000, 0x1da400f, names[3]};
}
int main(void) {
    struct device dev = {&cliffs}; struct ufs_hba hba = {.dev = &dev};
    unsigned long status; u32 value = 0xa5a5;
    for (int i = 0; i < 4; i++) {
        reset(&hba); missing = i;
        assert(ufs_qcom_mcq_config_resource(&hba) == -ENODEV && !map_calls);
    }
    for (int fault = 0; fault < 13; fault++) {
        reset(&hba);
        switch (fault) {
        case 0: hba.nr_hw_queues = 0; break;
        case 1: hba.nr_hw_queues = 33; break;
        case 2: hba.mcq_capabilities = 0xe00003; break;
        case 3: resources[1].end--; break;
        case 4: resources[1].start += 0x200; resources[1].end += 0x200; break;
        case 5: resources[2].end = resources[2].start + 0x7ff - 1; break;
        case 6: resources[3].end = resources[3].start + 0xb - 1; break;
        case 7: resources[3].start = resources[2].start; resources[3].end = resources[2].end; break;
        case 8: resources[2].start = resources[0].start - 0x2000; resources[2].end = resources[0].start - 1; break;
        case 9: resources[2].start += UINT64_C(0x100000000); resources[2].end += UINT64_C(0x100000000); break;
        case 10: resources[2].end = resources[2].start - 1; break;
        case 11: resources[3].start = 0; resources[3].end = UINT64_MAX; break;
        case 12: resources[0].start += UINT64_C(0x100000000); resources[0].end += UINT64_C(0x100000000); break;
        }
        assert(ufs_qcom_mcq_config_resource(&hba) == -EINVAL && !map_calls);
        assert(!hba.mcq_base && !host.mcq_sqd_base && !host.mcq_vs_base);
    }
    for (int i = 1; i <= 3; i++) {
        reset(&hba); fail_map = i;
        assert(ufs_qcom_mcq_config_resource(&hba) == -ENOMEM && map_calls == i);
        assert(!hba.mcq_base && !host.mcq_sqd_base && !host.mcq_vs_base);
        assert(ufs_qcom_op_runtime_config(&hba) == -EINVAL);
        status = 0x55; assert(ufs_qcom_get_outstanding_cqs(&hba, &status) == -EINVAL && status == 0x55 && !last_read);
    }
    for (unsigned int count = 1; count <= 32; count++) {
        reset(&hba); hba.nr_hw_queues = count; hba.mcq_capabilities = 0xe0001f;
        resources[1].end = resources[1].start + count * 0x40 - 1;
        resources[2].end = resources[2].start + count * 0x100 - 1;
        assert(ufs_qcom_mcq_config_resource(&hba) == 0 && map_calls == 3);
        assert(hba.mcq_base == memory[1] && host.mcq_sqd_base == memory[2] && host.mcq_vs_base == memory[3]);
        assert(ufs_qcom_op_runtime_config(&hba) == 0);
        for (int i = 0; i < OPR_MAX; i++) {
            assert(hba.mcq_opr[i].base == memory[2] + i * 0x40);
            assert(hba.mcq_opr[i].offset == 0x21000 + (unsigned int)i * 0x40 && hba.mcq_opr[i].stride == 0x100);
        }
        memcpy(memory[3] + 8, &value, 4);
        assert(ufs_qcom_get_outstanding_cqs(&hba, &status) == 0 && status == value && last_read == memory[3] + 8);
    }
    reset(&hba); cliffs = false;
    assert(ufs_qcom_mcq_config_resource(&hba) == 0 && map_calls == 1);
    assert(ufs_qcom_op_runtime_config(&hba) == 0);
    assert(hba.mcq_opr[OPR_SQD].base == memory[1] + 0x5000);
    assert(hba.mcq_opr[OPR_CQIS].offset == 0x210c0);
    memcpy(memory[1] + UFS_MEM_CQIS_VS, &value, 4);
    assert(ufs_qcom_get_outstanding_cqs(&hba, &status) == 0 && status == value && last_read == memory[1] + UFS_MEM_CQIS_VS);
    puts("Actual UFS MCQ callbacks: split windows, bounds, faults, 1-32 queues and legacy path passed");
}
C
"${CC:-gcc}" -std=gnu11 -O2 -Wall -Wextra -Werror ${UFS_TEST_CFLAGS:-} \
    "$work/check.c" -o "$work/check"
"$work/check"
