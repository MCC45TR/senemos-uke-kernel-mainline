#!/usr/bin/env bash
# Actual TSENS helpers and PM callbacks with host-only IRQ/regmap ownership.
set -Eeuo pipefail
source_file=${1:?Pass prepared tsens.c}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#define __maybe_unused
#define BIT(n) (1U << (n))
#define dev_err(...) ((void)0)
enum { VER_0, VER_0_1, VER_1_X, VER_1_X_NO_RPM, VER_2_X, VER_2_X_NO_RPM };
enum { WDOG_BARK_MASK, CC_MON_MASK, INT_EN };
enum { PM_SUSPEND_ON, PM_SUSPEND_TO_IDLE, PM_SUSPEND_MEM };
static int pm_suspend_target_state;
struct tsens_priv;
struct device { bool wakeup; struct tsens_priv *data; void *of_node; };
struct platform_device { struct device dev; };
typedef int (*irq_handler_t)(int, void *);
#define IRQF_TRIGGER_RISING 1
#define IRQF_ONESHOT 2
struct tsens_features { bool combo_int, crit_int, has_watchdog; };
struct tsens_ops { int (*suspend)(struct tsens_priv *); int (*resume)(struct tsens_priv *); };
struct tsens_priv {
    struct device *dev;
    struct tsens_features *feat;
    const struct tsens_ops *ops;
    int uplow_irq, crit_irq, combined_irq, version;
    unsigned int irq_wake_mask;
    int *rf[3];
};
static int refs[3], enables, disables, enable_fault, disable_fault;
static int field_calls, field_fault, suspend_calls, resume_calls, op_fault;
static struct platform_device platform;
static int irq_lookup, request_error, requested, device_puts;
static bool device_missing;
static bool device_may_wakeup(struct device *dev) { return dev->wakeup; }
static struct tsens_priv *dev_get_drvdata(struct device *dev) { return dev->data; }
static int tsens_version(struct tsens_priv *priv) { return priv->version; }
static int enable_irq_wake(int irq) {
    int idx = irq == 0 ? 2 : irq / 11 - 1; assert(idx >= 0 && idx < 3); enables++;
    if (enable_fault == irq) return -EIO;
    refs[idx]++; return 0;
}
static int disable_irq_wake(int irq) {
    int idx = irq == 0 ? 2 : irq / 11 - 1; assert(idx >= 0 && idx < 3); assert(refs[idx] > 0); disables++;
    if (disable_fault & BIT(idx)) return idx == 1 ? -EAGAIN : -EBUSY;
    refs[idx]--; return 0;
}
static int regmap_field_write(int *field, int value) {
    assert(*field == INT_EN ? value == 7 || value == 1 : value == (*field == CC_MON_MASK));
    field_calls++; return field_fault == *field + 1 ? -EREMOTEIO : 0;
}
static struct platform_device *of_find_device_by_node(void *node) { (void)node; return device_missing ? NULL : &platform; }
static int platform_get_irq_byname(struct platform_device *pdev, char *name) { assert(pdev == &platform && !strcmp(name, "uplow")); return irq_lookup; }
static int devm_request_threaded_irq(struct device *dev, int irq, irq_handler_t handler, irq_handler_t thread, int flags, const char *name, void *data) {
    (void)name; assert(dev == &platform.dev && irq == irq_lookup && data);
    assert(flags == IRQF_TRIGGER_RISING ? handler && !thread : !handler && thread);
    requested++; return request_error;
}
static const char *dev_name(struct device *dev) { (void)dev; return "fixture"; }
static void put_device(struct device *dev) { assert(dev == &platform.dev); device_puts++; }
int tsens_suspend_common(struct tsens_priv *priv);
int tsens_resume_common(struct tsens_priv *priv);
C
awk '/^#define TSENS_WAKE_/ { print }' "$source_file" >> "$work/check.c"
awk '/^(static )?int[[:space:]]+(__maybe_unused )?tsens_(enable_irq|release_irq_wake|suspend|resume|reinit|suspend_common|resume_common|register_irq)\(/ { emit=1 } \
    emit { print } emit && /^}/ { emit=0 }' "$source_file" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static int suspend_hw(struct tsens_priv *priv) { (void)priv; suspend_calls++; return op_fault == 1 ? -ENXIO : 0; }
static int resume_hw(struct tsens_priv *priv) { (void)priv; resume_calls++; return op_fault == 2 ? -ETIME : 0; }
static int irq_thread(int irq, void *data) { (void)irq; (void)data; assert(false); return 0; }
static void reset(struct tsens_priv *priv) {
    priv->irq_wake_mask = 0; priv->dev->wakeup = true; priv->version = VER_2_X;
    *priv->feat = (struct tsens_features){false, true, true};
    enables = disables = enable_fault = disable_fault = field_calls = field_fault = suspend_calls = resume_calls = op_fault = 0;
    enable_fault = -1;
    memset(refs, 0, sizeof(refs)); pm_suspend_target_state = PM_SUSPEND_TO_IDLE;
    priv->uplow_irq = 11; priv->crit_irq = 22; priv->combined_irq = 33;
    irq_lookup = 11; request_error = requested = device_puts = 0; device_missing = false;
}
int main(void) {
    int fields[] = {WDOG_BARK_MASK, CC_MON_MASK, INT_EN};
    struct tsens_features feat;
    const struct tsens_ops ops = {suspend_hw, resume_hw};
    struct device dev = {0};
    struct tsens_priv priv = {&dev, &feat, &ops, 11, 22, 33, VER_2_X, 0, {&fields[0], &fields[1], &fields[2]}};
    dev.data = &priv;
    reset(&priv); feat.combo_int = true; enable_fault = 33;
    assert(tsens_suspend(&dev) == -EIO && !refs[2] && !priv.irq_wake_mask && resume_calls == 1);
    reset(&priv); enable_fault = 22;
    assert(tsens_suspend(&dev) == -EIO && !refs[0] && !refs[1] && disables == 1 && resume_calls == 1);
    reset(&priv); enable_fault = 22; op_fault = 2;
    assert(tsens_suspend(&dev) == -EIO && resume_calls == 1 && !priv.irq_wake_mask);
    reset(&priv); enable_fault = 22; disable_fault = BIT(0);
    assert(tsens_suspend(&dev) == -EIO && refs[0] == 1 && priv.irq_wake_mask == 1);
    dev.wakeup = false;
    assert(tsens_suspend_common(&priv) == -EBUSY && enables == 2);
    disable_fault = 0;
    assert(tsens_resume_common(&priv) == 0 && !refs[0] && !priv.irq_wake_mask);
    reset(&priv); feat.combo_int = true; assert(tsens_suspend(&dev) == 0);
    disable_fault = BIT(2);
    assert(tsens_resume(&dev) == -EBUSY && refs[2] == 1 && priv.irq_wake_mask == 1);
    disable_fault = 0;
    assert(tsens_resume(&dev) == 0 && !refs[2] && !priv.irq_wake_mask);
    for (int combo = 0; combo <= 1; combo++) for (int critical = 0; critical <= 1; critical++) {
        reset(&priv); feat.combo_int = combo; feat.crit_int = critical;
        assert(tsens_suspend(&dev) == 0 && enables == (combo || !critical ? 1 : 2));
        int old_enables = enables;
        assert(tsens_suspend_common(&priv) == -EBUSY && enables == old_enables);
        dev.wakeup = false;
        assert(tsens_resume(&dev) == 0 && !refs[0] && !refs[1] && !refs[2] && !priv.irq_wake_mask);
        assert(!field_calls && suspend_calls == 1 && resume_calls == 1);
    }
    reset(&priv); dev.wakeup = false;
    assert(tsens_suspend(&dev) == 0 && !enables);
    assert(tsens_resume(&dev) == 0 && !disables);
    reset(&priv); irq_lookup = -ENXIO;
    assert(tsens_register_irq(&priv, "uplow", irq_thread, &priv.uplow_irq) == 0 && priv.uplow_irq == -1 && !requested && device_puts == 1);
    priv.crit_irq = -1;
    assert(tsens_suspend(&dev) == 0 && !enables && tsens_resume(&dev) == 0 && !disables);
    reset(&priv); priv.crit_irq = -1;
    assert(tsens_suspend(&dev) == 0 && enables == 1 && tsens_resume(&dev) == 0);
    reset(&priv); priv.uplow_irq = -1;
    assert(tsens_suspend(&dev) == 0 && enables == 1 && refs[1] == 1 && tsens_resume(&dev) == 0);
    reset(&priv); feat.combo_int = true; priv.combined_irq = -1;
    assert(tsens_suspend(&dev) == 0 && !enables && tsens_resume(&dev) == 0);
    reset(&priv); irq_lookup = 0;
    assert(tsens_register_irq(&priv, "uplow", irq_thread, &priv.uplow_irq) == 0 && priv.uplow_irq == 0 && requested == 1 && device_puts == 1);
    assert(tsens_suspend(&dev) == 0 && refs[2] == 1 && tsens_resume(&dev) == 0 && !refs[2]);
    reset(&priv); irq_lookup = -EAGAIN;
    assert(tsens_register_irq(&priv, "uplow", irq_thread, &priv.uplow_irq) == -EAGAIN && priv.uplow_irq == -1 && !requested && device_puts == 1);
    reset(&priv); request_error = -EBUSY;
    assert(tsens_register_irq(&priv, "uplow", irq_thread, &priv.uplow_irq) == -EBUSY && priv.uplow_irq == -1 && requested == 1 && device_puts == 1);
    reset(&priv); device_missing = true;
    assert(tsens_register_irq(&priv, "uplow", irq_thread, &priv.uplow_irq) == -ENODEV && priv.uplow_irq == -1 && !device_puts);
    reset(&priv); priv.version = VER_0;
    assert(tsens_register_irq(&priv, "uplow", irq_thread, &priv.uplow_irq) == 0 && requested == 1 && device_puts == 1);
    reset(&priv); op_fault = 1;
    assert(tsens_suspend(&dev) == -ENXIO && !enables && !resume_calls);
    reset(&priv); assert(tsens_suspend(&dev) == 0); op_fault = 2;
    assert(tsens_resume(&dev) == -ETIME && !refs[0] && !refs[1] && !priv.irq_wake_mask && !field_calls);
    reset(&priv); assert(tsens_suspend(&dev) == 0); op_fault = 2; disable_fault = BIT(0) | BIT(1);
    assert(tsens_resume(&dev) == -ETIME && priv.irq_wake_mask == 3 && refs[0] == 1 && refs[1] == 1);
    op_fault = disable_fault = 0;
    assert(tsens_resume(&dev) == 0 && !priv.irq_wake_mask && !refs[0] && !refs[1]);
    for (int fault = 1; fault <= 3; fault++) {
        reset(&priv); assert(tsens_suspend(&dev) == 0);
        pm_suspend_target_state = PM_SUSPEND_MEM; field_fault = fault;
        assert(tsens_resume(&dev) == -EREMOTEIO && field_calls == fault);
        assert(!priv.irq_wake_mask && !refs[0] && !refs[1]);
    }
    reset(&priv); assert(tsens_suspend(&dev) == 0);
    pm_suspend_target_state = PM_SUSPEND_MEM; field_fault = 1; disable_fault = BIT(0) | BIT(1);
    assert(tsens_resume(&dev) == -EREMOTEIO && priv.irq_wake_mask == 3 && disables == 2);
    field_fault = 0;
    assert(tsens_resume(&dev) == -EAGAIN && priv.irq_wake_mask == 3 && disables == 4);
    disable_fault = 0;
    assert(tsens_resume(&dev) == 0 && !priv.irq_wake_mask && !refs[0] && !refs[1]);
    reset(&priv); priv.ops = NULL; feat.has_watchdog = false;
    pm_suspend_target_state = PM_SUSPEND_MEM;
    assert(tsens_suspend(&dev) == 0 && tsens_resume(&dev) == 0 && field_calls == 1);
    for (int version = VER_0_1; version <= VER_2_X; version++) {
        reset(&priv); priv.version = version; feat.has_watchdog = false;
        assert(tsens_enable_irq(&priv) == 0 && field_calls == 1);
        field_fault = INT_EN + 1;
        assert(tsens_enable_irq(&priv) == -EREMOTEIO);
    }
    for (int version = VER_0; version < VER_2_X; version++) {
        reset(&priv); priv.version = version; feat.has_watchdog = false;
        pm_suspend_target_state = PM_SUSPEND_MEM;
        assert(tsens_suspend(&dev) == 0 && tsens_resume(&dev) == 0 && !field_calls);
    }
    puts("Actual TSENS PM: combo/split wake ownership, failed unwind/retry, custom PM and regmap errors passed");
}
C
"${CC:-gcc}" -std=gnu11 -O2 -Wall -Wextra -Werror ${THERMAL_TEST_CFLAGS:-} \
    "$work/check.c" -o "$work/check"
"$work/check"
