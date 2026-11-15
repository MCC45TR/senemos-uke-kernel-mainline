/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual fixed-cap dispatcher, fake firmware only. Never a battery test. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>

typedef uint32_t u32;
typedef uint64_t u64;
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define NSEC_PER_SEC UINT64_C(1000000000)
#define PMIC_GLINK_OWNER_BATTMGR 32778
#define PMIC_GLINK_REQ_RESP 1
#define BATTMGR_CHG_CTRL_LIMIT_EN 0x48
#define BATTMGR_BAT_PROPERTY_GET 0x30
#define BATTMGR_USB_PROPERTY_GET 0x32
#define BATT_PRESENT 1
#define BATT_HEALTH 3
#define BATT_CAPACITY 4
#define USB_ONLINE 0
#define POWER_SUPPLY_HEALTH_GOOD 1
#define CAP_SYS_ADMIN 21
#define cpu_to_le32(x) ((u32)(x))
struct qcom_battmgr_uke_transaction {
 unsigned lock, generation, firmware_generation, source_generation;
 u64 instance_ns;
 bool desynced, suspended, removing;
 size_t response_len;
};
struct qcom_battmgr_uke_settings {
 bool enabled;
 unsigned start, end, generation, firmware, source;
 u64 instance, received_ns;
};
struct pmic_glink_hdr { u32 owner, type, opcode; };
struct qcom_battmgr_charge_ctrl_request {
 struct pmic_glink_hdr hdr;
 u32 enable, target_soc, delta_soc;
};
struct qcom_battmgr {
 unsigned lock;
 void *dev;
 bool service_up;
 struct qcom_battmgr_uke_transaction transaction;
 struct {
  bool preconfigured_uncertain, preconfigured_limit_attempted;
  bool preconfigured_apply;
  u32 preconfigured_generation;
 } control;
 struct { bool present; } info;
 struct { unsigned health, percent; } status;
 struct { bool online; } usb;
 struct { bool wet_latched; u32 faults; } protection;
};
struct device { struct qcom_battmgr *data; };
struct device_attribute { unsigned unused; };
static struct {
 unsigned gets, sets, reads, fail_get, fail_read, late_get;
 unsigned before_start, before_end, percent, after_wrong;
 int send_error;
 bool enabled, admin, mutex_ready, lock_held;
 u64 clock, step;
} fake;
static unsigned scenarios;
static void reset(struct qcom_battmgr *b, bool online)
{
 *b = (struct qcom_battmgr) {
  .service_up = true, .transaction = {
   .instance_ns = 7, .generation = 11, .firmware_generation = 13,
   .source_generation = 17, .response_len = 20,
  }, .info.present = true, .status.health = POWER_SUPPLY_HEALTH_GOOD,
  .usb.online = online,
 };
 memset(&fake, 0, sizeof(fake));
 fake.before_start = 70; fake.before_end = 80; fake.percent = 92;
 fake.enabled = fake.admin = fake.mutex_ready = fake.lock_held = true;
 fake.clock = NSEC_PER_SEC; fake.step = 1;
}
static u64 ktime_get_boottime_ns(void)
{
 fake.clock += fake.step;
 return fake.clock;
}
#define lockdep_assert_held(x) do { (void)(x); assert(fake.lock_held); } while (0)
#define spin_lock_irqsave(x, flags) do { (void)(x); (flags) = 0; } while (0)
#define spin_unlock_irqrestore(x, flags) do { (void)(x); (void)(flags); } while (0)
static void dev_info(void *d, const char *fmt, ...){ (void)d; (void)fmt; }
static void dev_notice(void *d, const char *fmt, ...){ (void)d; (void)fmt; }
static int qcom_battmgr_uke_settings_read(struct qcom_battmgr *b,
 struct qcom_battmgr_uke_settings *s, bool rate_limit)
{
 ++fake.reads;
 assert(fake.reads <= 2 && rate_limit == (fake.reads == 1));
 if (fake.fail_read == fake.reads) return -EIO;
 *s = (struct qcom_battmgr_uke_settings) {
  .enabled = fake.enabled, .start = fake.before_start, .end = fake.before_end,
  .instance = b->transaction.instance_ns,
  .generation = b->transaction.generation,
  .firmware = b->transaction.firmware_generation,
  .source = b->transaction.source_generation,
  .received_ns = ktime_get_boottime_ns(),
 };
 if (fake.reads == 2) {
  switch (fake.after_wrong) {
  case 1: s->enabled = false; break;
  case 2: s->start = 69; break;
  case 3: s->end = 81; break;
  case 4: ++s->instance; break;
  case 5: ++s->generation; break;
  case 6: ++s->firmware; break;
  case 7: ++s->source; break;
  case 8: s->received_ns = 0; break;
  case 9: s->received_ns += 6 * NSEC_PER_SEC; break;
  default: break;
  }
 }
 return 0;
}
static int qcom_battmgr_request_property(struct qcom_battmgr *b,
 unsigned opcode, unsigned prop, unsigned value)
{
 ++fake.gets; assert(value == 0);
 const unsigned props[] = {BATT_PRESENT, BATT_HEALTH, USB_ONLINE, BATT_CAPACITY};
 assert(fake.gets <= 4 && prop == props[fake.gets - 1]);
 assert(opcode == (fake.gets == 3 ? BATTMGR_USB_PROPERTY_GET : BATTMGR_BAT_PROPERTY_GET));
 if (fake.fail_get == fake.gets) return -EIO;
 if (fake.late_get == fake.gets) ++b->transaction.source_generation;
 if (prop == BATT_CAPACITY) b->status.percent = fake.percent;
 return 0;
}
static int qcom_battmgr_request(struct qcom_battmgr *b, void *packet, size_t size)
{
 const struct qcom_battmgr_charge_ctrl_request expected = {
  .hdr = {PMIC_GLINK_OWNER_BATTMGR, PMIC_GLINK_REQ_RESP, BATTMGR_CHG_CTRL_LIMIT_EN},
  .enable = 1, .target_soc = 80, .delta_soc = 10,
 };
 assert(size == sizeof(expected) && !memcmp(packet, &expected, sizeof(expected)));
 assert(b->control.preconfigured_apply && b->control.preconfigured_limit_attempted);
 assert(b->control.preconfigured_uncertain &&
        b->control.preconfigured_generation == b->transaction.generation);
 ++fake.sets;
 assert(fake.sets == 1);
 return fake.send_error;
}
static bool capable(unsigned cap){ assert(cap == CAP_SYS_ADMIN); return fake.admin; }
static bool sysfs_streq(const char *a, const char *b)
{
 size_t n = strlen(a), m = strlen(b);
 return (n == m || (n == m + 1 && a[m] == '\n')) && !memcmp(a, b, m);
}
static bool mutex_trylock(unsigned *lock){ (void)lock; return fake.mutex_ready; }
static void mutex_unlock(unsigned *lock){ (void)lock; }
static struct qcom_battmgr *dev_get_drvdata(struct device *d){ return d->data; }
#include "actual-charge-scope.inc"
#include "actual-charge-offline.inc"
#include "actual-charge-online-store.inc"
static int check(struct qcom_battmgr *b, bool online, int wanted, unsigned sets)
{
 const int ret = qcom_battmgr_uke_apply_existing_cap_scope(b, online);
 assert(ret == wanted && fake.sets == sets && !b->control.preconfigured_apply);
 if (sets) {
  assert(b->control.preconfigured_uncertain && b->control.preconfigured_limit_attempted);
  assert(qcom_battmgr_uke_apply_existing_cap_scope(b, online) == -EUCLEAN);
  assert(fake.sets == sets);
 }
 ++scenarios;
 return ret;
}
int main(void)
{
 struct qcom_battmgr b;
 for (unsigned p = 0; p <= 100; ++p) {
  reset(&b, true); fake.percent = p;
  check(&b, true, p < 80 ? -ERANGE : 0, p < 80 ? 0 : 1);
 }
 for (unsigned p = 0; p < 2; ++p) {
  reset(&b, true); fake.percent = p ? UINT32_MAX : 101;
  check(&b, true, -ERANGE, 0);
 }
 reset(&b, false); check(&b, true, -ERANGE, 0);
 reset(&b, true); check(&b, false, -ERANGE, 0);
 reset(&b, false); assert(qcom_battmgr_uke_apply_existing_cap(&b) == 0);
 assert(fake.gets == 3 && fake.sets == 1 && !b.control.preconfigured_apply); ++scenarios;
 for (unsigned i = 1; i <= 4; ++i) {
  reset(&b, true); fake.fail_get = i; check(&b, true, -EIO, 0);
  reset(&b, true); fake.late_get = i; check(&b, true, -ESTALE, 0);
 }
 for (unsigned i = 1; i <= 2; ++i) {
  reset(&b, true); fake.fail_read = i; check(&b, true, -EIO, i == 2);
 }
 for (unsigned i = 1; i <= 9; ++i) {
  reset(&b, true); fake.after_wrong = i; check(&b, true, -EREMOTEIO, 1);
 }
 reset(&b, true); b.info.present = false; check(&b, true, -ERANGE, 0);
 reset(&b, true); b.status.health = 2; check(&b, true, -ERANGE, 0);
 reset(&b, true); fake.enabled = false; check(&b, true, -EOPNOTSUPP, 0);
 reset(&b, true); fake.before_start = 69; check(&b, true, -EOPNOTSUPP, 0);
 reset(&b, true); fake.before_end = 81; check(&b, true, -EOPNOTSUPP, 0);
 reset(&b, true); fake.send_error = -ETIMEDOUT; check(&b, true, -ETIMEDOUT, 1);
 reset(&b, true); b.control.preconfigured_uncertain = true; check(&b, true, -EUCLEAN, 0);
 reset(&b, true); b.control.preconfigured_limit_attempted = true; check(&b, true, -EALREADY, 0);
 reset(&b, true); b.protection.wet_latched = true; check(&b, true, -EACCES, 0);
 reset(&b, true); b.protection.faults = 1; check(&b, true, -EACCES, 0);
 reset(&b, true); b.service_up = false; check(&b, true, -ESTALE, 0);
 reset(&b, true); b.transaction.desynced = true; check(&b, true, -ESTALE, 0);
 reset(&b, true); b.transaction.suspended = true; check(&b, true, -ESTALE, 0);
 reset(&b, true); b.transaction.removing = true; check(&b, true, -ESTALE, 0);
 reset(&b, true); fake.step = 2 * NSEC_PER_SEC; check(&b, true, -ESTALE, 0);
 const char *bad[] = {"0", "2", "-1", "1 2", "", "1\n\n"};
 struct device d = {.data = &b};
 for (unsigned i = 0; i < ARRAY_SIZE(bad); ++i) {
  reset(&b, true); assert(uke_charge_apply_existing_cap_online_store(&d, NULL, bad[i], strlen(bad[i])) == -EINVAL);
  assert(!fake.sets && !fake.reads); ++scenarios;
 }
 reset(&b, true); fake.admin = false;
 assert(uke_charge_apply_existing_cap_online_store(&d, NULL, "1\n", 2) == -EPERM);
 assert(!fake.reads && !fake.sets); ++scenarios;
 reset(&b, true); fake.mutex_ready = false;
 assert(uke_charge_apply_existing_cap_online_store(&d, NULL, "1\n", 2) == -EBUSY);
 assert(!fake.reads && !fake.sets); ++scenarios;
 reset(&b, true);
 assert(uke_charge_apply_existing_cap_online_store(&d, NULL, "1\n", 2) == 2);
 assert(fake.sets == 1 && b.control.preconfigured_uncertain); ++scenarios;
 printf("Actual online cap scope:%u fixed-target,online/SOC,offline parity,lifecycle,errors,quarantine and privilege scenarios; fake firmware only.\n", scenarios);
 return 0;
}
