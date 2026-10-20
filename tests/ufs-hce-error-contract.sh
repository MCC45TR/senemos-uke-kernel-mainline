#!/usr/bin/env bash
# Actual QCOM callbacks and UFS core entry points with host-only transitions.
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
#define EPROBE_DEFER 517
#define UFSHCD_CAP_CRYPTO 1
#define UFSHCI_QUIRK_BROKEN_HCE 1
#define CONTROLLER_ENABLE 1
#define REG_CONTROLLER_ENABLE 0
#define UFSHCD_UIC_MASK 1
#define dev_err(...) ((void)0)
enum ufs_notify_change_status { PRE_CHANGE, POST_CHANGE };
struct ufs_vps { unsigned int hba_enable_delay_us; };
struct ufs_hba { unsigned int caps, quirks; struct ufs_vps *vps; };
struct ufs_qcom_host { struct ufs_hba *hba; void *ice; };
static struct ufs_qcom_host host;
static int fault, ice_calls, allocator_calls, starts, stops, interrupts, pre_calls, post_calls;
static int wait_failures, wait_calls;
static bool fw_managed, active;
static struct ufs_qcom_host *ufshcd_get_variant(struct ufs_hba *hba) { (void)hba; return &host; }
static int qcom_ice_enable(void *ice) { (void)ice; ice_calls++; return fault == 1 ? -EKEYREJECTED : 0; }
static int ufs_qcom_power_up_sequence(struct ufs_hba *hba) { (void)hba; return fault == 2 ? -EHOSTDOWN : 0; }
static int ufs_qcom_enable_lane_clks(struct ufs_qcom_host *h) { (void)h; return fault == 3 ? -EAGAIN : 0; }
static int ufs_qcom_check_hibern8(struct ufs_hba *hba) { (void)hba; return fault == 4 ? -ENOLINK : 0; }
static void ufs_qcom_enable_hw_clk_gating(struct ufs_hba *hba) { (void)hba; }
static void ufs_qcom_config_ice_allocator(struct ufs_qcom_host *h) { (void)h; allocator_calls++; }
static void ufs_qcom_select_unipro_mode(struct ufs_qcom_host *h) { (void)h; }
C
awk '/^static inline (int|void) ufs_qcom_ice_enable\(/ { emit=1 } emit { print } emit && /^}/ { exit }' \
    "$kernel/drivers/ufs/host/ufs-qcom.c" >> "$work/check.c"
awk '/^static int ufs_qcom_(hce_enable_notify|fw_managed_hce_enable_notify)\(/ { emit=1 } \
    emit { print } emit && /^}/ { emit=0 }' \
    "$kernel/drivers/ufs/host/ufs-qcom.c" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static int ufshcd_vops_hce_enable_notify(struct ufs_hba *hba, enum ufs_notify_change_status status) {
    if (status == PRE_CHANGE) { pre_calls++; if (fault == 6) return -EPROBE_DEFER; }
    else { post_calls++; if (fault == 7) return -EUCLEAN; }
    return fw_managed ? ufs_qcom_fw_managed_hce_enable_notify(hba, status) : ufs_qcom_hce_enable_notify(hba, status);
}
static bool ufshcd_is_hba_active(struct ufs_hba *hba) { (void)hba; return active; }
static void ufshcd_hba_stop(struct ufs_hba *hba) { (void)hba; stops++; active = false; }
static void ufshcd_set_link_off(struct ufs_hba *hba) { (void)hba; }
static void ufshcd_hba_start(struct ufs_hba *hba) { (void)hba; starts++; active = true; }
static void ufshcd_delay_us(unsigned int delay, unsigned int range) { (void)delay; (void)range; }
static int ufshcd_wait_for_register(struct ufs_hba *hba, unsigned int reg, unsigned int mask, unsigned int value, unsigned int delay, unsigned int timeout) {
    (void)hba; (void)reg; (void)mask; (void)value; (void)delay; (void)timeout;
    return wait_calls++ < wait_failures ? -ETIMEDOUT : 0;
}
static void ufshcd_enable_intr(struct ufs_hba *hba, unsigned int mask) { (void)hba; (void)mask; interrupts++; }
static int ufshcd_dme_reset(struct ufs_hba *hba) { (void)hba; return fault == 8 ? -ETIME : 0; }
static int ufshcd_dme_enable(struct ufs_hba *hba) { (void)hba; return fault == 9 ? -ENXIO : 0; }
C
awk '/^(static )?int ufshcd_(hba_execute_hce|hba_enable)\(/ { emit=1 } \
    emit { print } emit && /^}/ { emit=0 }' \
    "$kernel/drivers/ufs/core/ufshcd.c" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static void reset(struct ufs_hba *hba, bool firmware, bool broken) {
    hba->caps = UFSHCD_CAP_CRYPTO; hba->quirks = broken ? UFSHCI_QUIRK_BROKEN_HCE : 0;
    host.hba = hba; fw_managed = firmware; active = false;
    fault = ice_calls = allocator_calls = starts = stops = interrupts = pre_calls = post_calls = wait_failures = wait_calls = 0;
}
int main(void) {
    struct ufs_vps vps = {0}; struct ufs_hba hba = {.vps = &vps};
    reset(&hba, false, false); fault = 1;
    assert(ufshcd_hba_enable(&hba) == -EKEYREJECTED && !allocator_calls);
    for (int firmware = 0; firmware <= 1; firmware++) for (int broken = 0; broken <= 1; broken++) {
        reset(&hba, firmware, broken); fault = 1;
        assert(ufshcd_hba_enable(&hba) == -EKEYREJECTED && ice_calls == 1 && !allocator_calls);
        reset(&hba, firmware, broken); fault = 6;
        assert(ufshcd_hba_enable(&hba) == -EPROBE_DEFER && !starts && !interrupts && !ice_calls && !post_calls);
        reset(&hba, firmware, broken); fault = 7;
        assert(ufshcd_hba_enable(&hba) == -EUCLEAN && post_calls == 1 && !ice_calls);
        reset(&hba, firmware, broken);
        assert(ufshcd_hba_enable(&hba) == 0 && pre_calls == 1 && post_calls == 1 && ice_calls == 1);
        reset(&hba, firmware, broken); hba.caps = 0; fault = 1;
        assert(ufshcd_hba_enable(&hba) == 0 && !ice_calls);
        if (!firmware) {
            const int errors[] = {0, 0, EHOSTDOWN, EAGAIN, ENOLINK};
            for (int stage = 2; stage <= 4; stage++) {
                reset(&hba, firmware, broken); fault = stage;
                assert(ufshcd_hba_enable(&hba) == -errors[stage] && !ice_calls && !allocator_calls);
                if (stage < 4) assert(!starts && !post_calls);
            }
        }
        if (broken) {
            reset(&hba, firmware, broken); fault = 8;
            assert(ufshcd_hba_enable(&hba) == -ETIME && !post_calls);
            reset(&hba, firmware, broken); fault = 9;
            assert(ufshcd_hba_enable(&hba) == -ENXIO && !post_calls);
        }
    }
    reset(&hba, false, false); wait_failures = 3;
    assert(ufshcd_hba_enable(&hba) == -EIO && starts == 3 && stops == 2 && !post_calls);
    reset(&hba, false, false); wait_failures = 1;
    assert(ufshcd_hba_enable(&hba) == 0 && starts == 2 && stops == 1 && ice_calls == 1);
    assert(ufs_qcom_hce_enable_notify(&hba, 99) == -EINVAL);
    assert(ufs_qcom_fw_managed_hce_enable_notify(&hba, 99) == -EINVAL);
    puts("Actual UFS HCE chain: normal/firmware-managed, regular/broken HCE, ICE/PRE/POST/PHY/DME faults and retries passed");
}
C
"${CC:-gcc}" -std=gnu11 -O2 -Wall -Wextra -Werror ${UFS_TEST_CFLAGS:-} \
    "$work/check.c" -o "$work/check"
"$work/check"
