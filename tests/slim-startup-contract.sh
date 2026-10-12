#!/usr/bin/env bash
# Host-only fault injection into the production NGD startup functions.
set -Eeuo pipefail
kernel=${1:?Pass the prepared kernel source directory}
source=$kernel/drivers/slimbus/qcom-ngd-ctrl.c
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
cat <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <errno.h>
#define BIT(n) (1U << (n))
#define HZ 100
#define MSEC_PER_SEC 1000
#define EREMOTEIO 121
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
typedef uint32_t u32;
C
awk '/\/\* NGD \(/ {emit=1} /\/\* Slimbus QMI service/ {emit=0} emit {print}
     /^#define SLIM_RX_MSGQ_TIMEOUT_VAL/ {print}
     /^enum qcom_slim_ngd_state/ {states=1} states {print} states && /^};/ {states=0}' "$source"
cat <<'C'
struct qcom_slim_ngd_ctrl;
struct device { struct qcom_slim_ngd_ctrl *data; };
struct work_struct { int unused; };
struct qcom_slim_ngd { unsigned char *base; };
struct qcom_slim_ngd_ctrl {
 struct device *dev;
 struct { struct device *dev; } ctrl;
 struct { void *handle; int qmi_comp; } qmi;
 struct qcom_slim_ngd *ngd;
 enum qcom_slim_ngd_state state;
 unsigned char *base;
 u32 ver;
 int reconf, qmi_up, ssr_lock;
 struct work_struct ngd_up_work;
};
static u32 registers[8];
static int dma_result, power_result, qmi_result, resume_result;
static int dma_calls, writes, registrations, removals, usage, power_calls, resume_calls;
static long qmi_wait;
static unsigned long completion_wait;
static bool runtime_enabled, suspended;
static u32 readl_relaxed(unsigned char *p) {
 assert(p >= (unsigned char *)registers && p <= (unsigned char *)registers + sizeof(registers) - 4);
 return *(u32 *)p;
}
static void writel_relaxed(u32 v, unsigned char *p) {
 assert(p >= (unsigned char *)registers && p <= (unsigned char *)registers + sizeof(registers) - 4);
 *(u32 *)p = v; writes++;
}
static int qcom_slim_ngd_init_dma(struct qcom_slim_ngd_ctrl *c) { (void)c; dma_calls++; return dma_result; }
static int qcom_slim_qmi_power_request(struct qcom_slim_ngd_ctrl *c, bool on) { (void)c; assert(on); power_calls++; return power_result; }
static unsigned long wait_for_completion_timeout(int *p, int timeout) { (void)p; assert(timeout == HZ); return completion_wait; }
static long wait_for_completion_interruptible_timeout(int *p, int timeout) { (void)p; assert(timeout == MSEC_PER_SEC); return qmi_wait; }
static int msecs_to_jiffies(int n) { return n; }
static void reinit_completion(int *p) { *p = 0; }
static void complete(int *p) { *p = 1; }
static void *dev_get_drvdata(struct device *d) { return d->data; }
#define dev_err(...) ((void)0)
#define dev_info(...) ((void)0)
static int qcom_slim_qmi_init(struct qcom_slim_ngd_ctrl *c, bool master) { assert(!master); if (!qmi_result) c->qmi.handle = c; return qmi_result; }
static void qcom_slim_qmi_exit(struct qcom_slim_ngd_ctrl *c) { c->qmi.handle = NULL; }
static bool pm_runtime_enabled(struct device *d) { (void)d; return runtime_enabled; }
static bool pm_runtime_suspended(struct device *d) { (void)d; return suspended; }
static int pm_runtime_resume(struct device *d) { (void)d; resume_calls++; return resume_result; }
static void pm_runtime_mark_last_busy(struct device *d) { (void)d; }
static void pm_runtime_put(struct device *d) { (void)d; usage--; }
static int slim_register_controller(void *c) { (void)c; registrations++; return 0; }
static void slim_unregister_controller(void *c) { (void)c; removals++; }
static void mutex_lock(int *p) { assert(!*p); *p = 1; }
static void mutex_unlock(int *p) { assert(*p == 1); *p = 0; }
C
for name in setup power_up runtime_resume enable up_worker; do
    awk -v name="qcom_slim_ngd_$name" '
        $0 ~ "^static (int|void) " name "\\(" {emit=1}
        emit {print} emit && /^}/ {exit}' "$source"
done
cat <<'C'
int main(void) {
 struct qcom_slim_ngd ngd = { (unsigned char *)registers };
 struct device dev = {0};
 struct qcom_slim_ngd_ctrl c = {
  .dev = &dev, .ctrl = { &dev }, .qmi = { &dev, 0 }, .ngd = &ngd,
  .state = QCOM_SLIM_NGD_CTRL_DOWN, .base = (unsigned char *)registers
 };
 dev.data = &c;
 completion_wait = 1;
 int errors[] = { -ENOMEM, -ENODEV, -EIO };
 for (unsigned int i = 0; i < sizeof(errors) / sizeof(errors[0]); i++) {
  dma_result = errors[i];
  writes = 0;
  int before = dma_calls;
  assert(qcom_slim_ngd_setup(&c) == errors[i] && dma_calls == before + 1 && writes == 0);
  registers[NGD_STATUS / 4] = NGD_LADDR;
  assert(qcom_slim_ngd_power_up(&c) == errors[i] && writes == 0);
  registers[NGD_STATUS / 4] = 0;
  assert(qcom_slim_ngd_power_up(&c) == errors[i] && !(registers[0] & NGD_CFG_ENABLE));
 }
 dma_result = 0;
 writes = 0;
 assert(qcom_slim_ngd_setup(&c) == 0 && writes == 1 && (registers[0] & 7) == 7);
 c.state = QCOM_SLIM_NGD_CTRL_AWAKE;
 int calls = dma_calls;
 assert(qcom_slim_ngd_setup(&c) == 0 && dma_calls == calls);
 c.state = QCOM_SLIM_NGD_CTRL_DOWN;
 power_result = -ETIMEDOUT;
 assert(qcom_slim_ngd_runtime_resume(&dev) == -ETIMEDOUT && c.state == QCOM_SLIM_NGD_CTRL_DOWN);
 c.state = QCOM_SLIM_NGD_CTRL_ASLEEP;
 int before_power = power_calls;
 assert(qcom_slim_ngd_runtime_resume(&dev) == -ETIMEDOUT && c.state == QCOM_SLIM_NGD_CTRL_ASLEEP);
 assert(power_calls == before_power + 1);
 usage = 1;
 runtime_enabled = true;
 assert(qcom_slim_ngd_enable(&c, true) == -ETIMEDOUT && usage == 1 && registrations == 0);
 suspended = true;
 resume_result = -EIO;
 assert(qcom_slim_ngd_enable(&c, true) == -EIO && resume_calls == 1 && usage == 1 && registrations == 0);
 /* pm_runtime_resume may return positive when the device is already active. */
 resume_result = 1;
 assert(qcom_slim_ngd_enable(&c, true) == 0 && usage == 0 && registrations == 1);
 assert(qcom_slim_ngd_enable(&c, false) == 0 && removals == 1 && !c.qmi.handle);
 registrations = 0;
 usage = 1;
 qmi_result = -ENOMEM;
 assert(qcom_slim_ngd_enable(&c, true) == -ENOMEM && usage == 1 && registrations == 0);
 qmi_result = 0;
 c.qmi.qmi_comp = 0;
 for (int i = 0; i < 2; i++) {
  qmi_wait = i ? -EINTR : 0;
  qcom_slim_ngd_up_worker(&c.ngd_up_work);
  assert(!c.qmi.qmi_comp && !c.ssr_lock && registrations == 0 && usage == 1);
 }
 qmi_wait = 1;
 qcom_slim_ngd_up_worker(&c.ngd_up_work);
 assert(c.qmi.qmi_comp && !c.ssr_lock && registrations == 1 && usage == 0);
}
C
} > "$work/check.c"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror "$work/check.c" -o "$work/check"
"$work/check"
echo 'SLIM startup: DMA/power/PM/QMI failures propagate; queues/registration stay gated; interrupted waits and positive PM returns handled'
