#!/usr/bin/env bash
# Actual ICE resume with counted clock ownership and BIST fault injection.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
struct device { int unused; };
struct clk { unsigned int id; int refs; };
struct qcom_ice { struct device *dev; struct clk *core_clk, *iface_clk; bool hwkm_init_complete; };
static int fault, init_calls, bist_calls;
#define dev_err(...) ((void)dev)
static int clk_prepare_enable(struct clk *clock) {
    if (!clock) return 0;
    if (fault == (int)clock->id) return -EREMOTEIO;
    clock->refs++; return 0;
}
static inline void clk_disable_unprepare(struct clk *clock) { if (clock) { assert(clock->refs > 0); clock->refs--; } }
static void qcom_ice_hwkm_init(struct qcom_ice *ice) { init_calls++; ice->hwkm_init_complete = true; }
static int qcom_ice_wait_bist_status(struct qcom_ice *ice) { (void)ice; bist_calls++; return fault == 3 ? -ETIMEDOUT : 0; }
C
awk '/^int qcom_ice_resume\(/ { emit=1 } emit { print } emit && /^}/ { exit }' \
    "$kernel/drivers/soc/qcom/ice.c" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
int main(void) {
    struct device dev = {0}; struct clk core = {1, 1}, iface = {2, 1};
    struct qcom_ice ice = {&dev, &core, &iface, false};
    for (int stage = 1; stage <= 3; stage++) {
        fault = stage; init_calls = bist_calls = 0; ice.hwkm_init_complete = false;
        assert(qcom_ice_resume(&ice) == (stage == 3 ? -ETIMEDOUT : -EREMOTEIO));
        assert(core.refs == 1 && iface.refs == 1);
        assert(!ice.hwkm_init_complete);
        assert(init_calls == (stage == 3) && bist_calls == (stage == 3));
    }
    fault = 0; assert(qcom_ice_resume(&ice) == 0);
    assert(core.refs == 2 && iface.refs == 2 && ice.hwkm_init_complete);
    clk_disable_unprepare(&core); clk_disable_unprepare(&iface);
    ice.iface_clk = NULL; fault = 3; ice.hwkm_init_complete = false;
    assert(qcom_ice_resume(&ice) == -ETIMEDOUT && core.refs == 1 && !ice.hwkm_init_complete);
    fault = 0; assert(qcom_ice_resume(&ice) == 0 && core.refs == 2);
    puts("Actual ICE resume: core/iface/BIST failures unwind owned references; success and optional iface passed");
}
C
"${CC:-gcc}" -std=gnu11 -O2 -Wall -Wextra -Werror ${UFS_TEST_CFLAGS:-} \
    "$work/check.c" -o "$work/check"
"$work/check"
