#!/usr/bin/env bash
# Actual BIST status policy with host-only polling and register reads.
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
typedef uint32_t u32;
#define BIT(n) (1U << (n))
#define GENMASK(h, l) ((UINT32_MAX >> (31 - (h))) & (UINT32_MAX << (l)))
#define QCOM_ICE_HWKM_V1 1
#define dev_err(...) ((void)0)
struct qcom_ice { unsigned char *base; bool use_hwkm, hwkm_init_complete; unsigned int hwkm_version; };
static int poll_error, reads, polls;
static u32 status;
static u32 fake_readl(struct qcom_ice *ice, unsigned int offset) { (void)ice; assert(offset == 0x9004); reads++; return status; }
#define qcom_ice_readl(ice, reg) fake_readl(ice, reg)
#define readl_poll_timeout(addr, val, cond, delay, timeout) (polls++, (void)(addr), (val)=0, (void)(cond), poll_error)
C
awk '/^#define (QCOM_ICE_REG_BIST_STATUS|QCOM_ICE_BIST_STATUS_MASK|HWKM_OFFSET|QCOM_ICE_REG_HWKM_TZ_KM_STATUS|QCOM_ICE_HWKM_(KT_CLEAR_DONE|BOOT_CMD_LIST[01]_DONE|CRYPTO_BIST_DONE|BIST_DONE))/ { print }' \
    "$kernel/drivers/soc/qcom/ice.c" >> "$work/check.c"
awk '/^static int qcom_ice_wait_bist_status\(/ { emit=1 } emit { print } emit && /^}/ { exit }' \
    "$kernel/drivers/soc/qcom/ice.c" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
int main(void) {
    unsigned char memory = 0;
    struct qcom_ice ice = {&memory, true, true, 2};
    status = 0;
    assert(qcom_ice_wait_bist_status(&ice) == -EIO && !ice.hwkm_init_complete);
    for (unsigned int version = 1; version <= 2; version++) {
        ice.hwkm_version = version;
        u32 expected = QCOM_ICE_HWKM_KT_CLEAR_DONE | QCOM_ICE_HWKM_BOOT_CMD_LIST0_DONE |
            QCOM_ICE_HWKM_BOOT_CMD_LIST1_DONE | QCOM_ICE_HWKM_CRYPTO_BIST_DONE(version) |
            QCOM_ICE_HWKM_BIST_DONE(version);
        for (unsigned int bit = 0; bit < 32; bit++) if (expected & BIT(bit)) {
            status = expected & ~BIT(bit); ice.hwkm_init_complete = true;
            assert(qcom_ice_wait_bist_status(&ice) == -EIO && !ice.hwkm_init_complete);
        }
        status = expected | BIT(20); ice.hwkm_init_complete = true;
        assert(qcom_ice_wait_bist_status(&ice) == -EIO && !ice.hwkm_init_complete);
        status = expected; ice.hwkm_init_complete = true;
        assert(qcom_ice_wait_bist_status(&ice) == 0 && ice.hwkm_init_complete);
    }
    reads = polls = 0; poll_error = -ETIMEDOUT; ice.hwkm_init_complete = true;
    assert(qcom_ice_wait_bist_status(&ice) == -ETIMEDOUT && !ice.hwkm_init_complete && polls == 1 && !reads);
    poll_error = 0; ice.use_hwkm = false; status = 0; reads = 0;
    assert(qcom_ice_wait_bist_status(&ice) == 0 && !reads);
    puts("Actual ICE BIST: both HWKM versions, missing/extra status, timeout and raw mode passed");
}
C
"${CC:-gcc}" -std=gnu11 -O2 -Wall -Wextra -Werror ${UFS_TEST_CFLAGS:-} \
    "$work/check.c" -o "$work/check"
"$work/check"
