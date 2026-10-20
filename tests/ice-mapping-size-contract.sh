#!/usr/bin/env bash
# Actual provider creation; all clocks, allocations and SCM checks are host stubs.
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
#define EPROBE_DEFER 517
#define GFP_KERNEL 0
#define ERR_PTR(e) ((void *)(intptr_t)(e))
#define IS_ERR(p) ((uintptr_t)(p) >= (uintptr_t)-4095)
#define ERR_CAST(p) ((void *)(p))
#define dev_warn(...) ((void)0)
#define dev_dbg(...) ((void)0)
struct device { int unused; };
struct clk { int unused; };
struct qcom_ice { struct device *dev; void *base; struct clk *core_clk, *iface_clk; bool use_hwkm; };
static struct qcom_ice storage;
static struct clk core;
static int fault, scm_calls, support_calls;
static bool wrapped;
static bool qcom_scm_is_available(void) { scm_calls++; return fault != 1; }
static bool qcom_scm_ice_available(void) { scm_calls++; return fault != 2; }
static void *devm_kzalloc(struct device *dev, size_t size, int flags) {
    (void)dev; (void)size; (void)flags; memset(&storage, 0, sizeof(storage));
    return fault == 3 ? NULL : &storage;
}
static struct clk *devm_clk_get_optional_enabled(struct device *dev, const char *name) {
    (void)dev;
    if (fault == 4 && !strcmp(name, "ice_core_clk")) return ERR_PTR(-EIO);
    if (fault == 5 && !strcmp(name, "iface")) return ERR_PTR(-EPROBE_DEFER);
    return NULL;
}
static struct clk *devm_clk_get_enabled(struct device *dev, const char *name) { (void)dev; (void)name; return &core; }
static bool qcom_ice_check_supported(struct qcom_ice *ice) { support_calls++; ice->use_hwkm = wrapped; return fault != 6; }
C
awk '/^#define QCOM_ICE_REG_ADVANCED_CONTROL/ || /^#define HWKM_OFFSET/ || /^#define QCOM_ICE_REG_HWKM_BANK0_BBAC_4/ { print }' \
    "$kernel/drivers/soc/qcom/ice.c" >> "$work/check.c"
awk '/^static struct qcom_ice \*qcom_ice_create\(/ { emit=1 } emit { print } emit && /^}/ { exit }' \
    "$kernel/drivers/soc/qcom/ice.c" >> "$work/check.c"
if grep -q 'resource_size_t size)' "$kernel/drivers/soc/qcom/ice.c"; then
    printf '#define CREATE(dev, base, size) qcom_ice_create(dev, base, size)\n' >> "$work/check.c"
else
    printf '#define CREATE(dev, base, size) qcom_ice_create(dev, base)\n' >> "$work/check.c"
fi
cat >> "$work/check.c" <<'C'
int main(void) {
    struct device dev = {0}; unsigned char memory = 0;
    const resource_size_t short_sizes[] = {0, 1, 8, 0x1000, 0x1003};
    for (unsigned int i = 0; i < sizeof(short_sizes) / sizeof(short_sizes[0]); i++) {
        scm_calls = support_calls = 0;
        assert(CREATE(&dev, &memory, short_sizes[i]) == ERR_PTR(-EINVAL));
        assert(!scm_calls && !support_calls);
    }
    const resource_size_t raw_sizes[] = {0x1004, 0x8000, 0x11000};
    for (unsigned int i = 0; i < sizeof(raw_sizes) / sizeof(raw_sizes[0]); i++) {
        wrapped = false; assert(CREATE(&dev, &memory, raw_sizes[i]) == &storage);
        assert(storage.base == &memory && storage.core_clk == &core && !storage.use_hwkm);
    }
    wrapped = true;
    assert(CREATE(&dev, &memory, 0x8000) == ERR_PTR(-EINVAL));
    assert(CREATE(&dev, &memory, 0xd013) == ERR_PTR(-EINVAL));
    assert(CREATE(&dev, &memory, 0xd014) == &storage);
    assert(CREATE(&dev, &memory, 0x11000) == &storage);
    const int errors[] = {0, EPROBE_DEFER, EOPNOTSUPP, ENOMEM, EIO, EPROBE_DEFER, EOPNOTSUPP};
    for (fault = 1; fault <= 6; fault++)
        assert(CREATE(&dev, &memory, 0x11000) == ERR_PTR(-errors[fault]));
    puts("Actual ICE creation: short raw/HWKM windows rejected, exact bounds accepted and six existing error paths retained");
}
C
"${CC:-gcc}" -std=gnu11 -O2 -Wall -Wextra -Werror ${UFS_TEST_CFLAGS:-} \
    "$work/check.c" -o "$work/check"
"$work/check"
