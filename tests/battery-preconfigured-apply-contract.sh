#!/usr/bin/env bash
# Actual fixed-limit application helper/wrapper; synthetic host I/O, no device access.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
source=$kernel/drivers/power/supply/qcom_battmgr_uke_control.h
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
grep -Fq '__ATTR(uke_charge_apply_existing_cap, 0200, NULL, uke_charge_apply_existing_cap_store)' "$source"
{
cat <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
typedef unsigned long long u64; typedef uint32_t u32;
#define dev_info(...) ((void)0)
#define NSEC_PER_SEC 1000000000ULL
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define IS_ENABLED(x) (x)
#define CAP_SYS_ADMIN 21
#define lockdep_assert_held(l) ((void)(l))
#define spin_lock_irqsave(l,f) ((void)(l),(f)=0)
#define spin_unlock_irqrestore(l,f) ((void)(l),(void)(f))
#define cpu_to_le32(x) ((u32)(x))
enum { QCOM_BATTMGR_UKE=1, BATT_CHG_CTRL_EN=24, BATT_CHG_CTRL_START_THR=25,
 BATT_CHG_CTRL_END_THR=26, BATT_PRESENT=7, BATT_HEALTH=1,
 BATTMGR_CHG_CTRL_LIMIT_EN=0x48, BATTMGR_BAT_PROPERTY_GET=0x30, BATTMGR_BAT_PROPERTY_SET=0x31,
 BATTMGR_USB_PROPERTY_GET=0x32, USB_ONLINE=0,
 PMIC_GLINK_OWNER_BATTMGR=32778, PMIC_GLINK_REQ_RESP=1, POWER_SUPPLY_HEALTH_GOOD=1 };
struct pmic_glink_hdr { u32 owner,type,opcode; };
struct qcom_battmgr_property_request { struct pmic_glink_hdr hdr; u32 battery_id,property,value; };
struct qcom_battmgr_charge_ctrl_request { struct pmic_glink_hdr hdr; u32 enable,target_soc,delta_soc; };
struct mutex { bool available; };
struct qcom_battmgr_uke_transaction {
 int lock; bool desynced,suspended,removing;
 u64 instance_ns; u32 generation,firmware_generation,source_generation;
};
struct qcom_battmgr {
 int variant; bool service_up; struct mutex lock;
 struct qcom_battmgr_uke_transaction transaction;
 struct { u64 expires_ns,settings_probe_ns,verified_until_ns,current_until_ns;
  bool enabled,verified,current_verified,preconfigured_enable,preconfigured_uncertain,preconfigured_apply,preconfigured_limit_attempted;
  u32 preconfigured_generation; } control;
 struct { u32 charge_ctrl_start,charge_ctrl_end; bool present; } info;
 struct { unsigned health; } status; struct { bool online; } usb;
};
struct device { struct qcom_battmgr *data; }; struct device_attribute { int unused; };
static u64 clock_ns,request_ns;
static unsigned calls,writes,fail_at,change_at;
static bool privileged,remote_enabled,remote_present,remote_online,ignore_set;
static u32 remote_start,remote_end,remote_health;
static u64 ktime_get_boottime_ns(void) { return clock_ns; }
static bool capable(int cap) { assert(cap==CAP_SYS_ADMIN); return privileged; }
static struct qcom_battmgr *dev_get_drvdata(struct device *dev) { return dev->data; }
static bool mutex_trylock(struct mutex *lock) { return lock->available; }
static void mutex_unlock(struct mutex *lock) { assert(lock->available); }
static bool sysfs_streq(const char *a,const char *b) { return !strcmp(a,b)||(!strcmp(a,"1\n")&&!strcmp(b,"1")); }
static u32 qcom_battmgr_uke_generation(struct qcom_battmgr *b) { return b->transaction.generation; }
static int step(struct qcom_battmgr *b) {
 calls++;clock_ns+=request_ns;
 if(calls==change_at)b->transaction.generation++;
 return calls==fail_at?-EIO:0;
}
static int qcom_battmgr_request_property(struct qcom_battmgr *b,unsigned opcode,unsigned property,int value) {
 assert(!b->control.preconfigured_enable && !value);
 int ret=step(b);if(ret)return ret;
 if(opcode==BATTMGR_BAT_PROPERTY_GET) {
  switch(property) {
  case BATT_CHG_CTRL_EN:b->control.enabled=remote_enabled;break;
  case BATT_CHG_CTRL_START_THR:b->info.charge_ctrl_start=remote_start;break;
  case BATT_CHG_CTRL_END_THR:b->info.charge_ctrl_end=remote_end;break;
  case BATT_PRESENT:b->info.present=remote_present;break;
  case BATT_HEALTH:b->status.health=remote_health;break;
  default:assert(false);
  }
 } else {assert(opcode==BATTMGR_USB_PROPERTY_GET && property==USB_ONLINE);b->usb.online=remote_online;}
 return 0;
}
static int qcom_battmgr_request(struct qcom_battmgr *b,void *data,size_t len) {
 const struct qcom_battmgr_charge_ctrl_request *r=data;
 assert(b->control.preconfigured_apply && !b->control.preconfigured_enable);
 assert(b->control.preconfigured_generation==b->transaction.generation);
 assert(b->control.preconfigured_uncertain && b->control.preconfigured_limit_attempted);
 assert(!b->control.expires_ns && !b->usb.online && remote_enabled);
 assert(len==sizeof(*r) && r->hdr.owner==PMIC_GLINK_OWNER_BATTMGR && r->hdr.type==PMIC_GLINK_REQ_RESP);
 assert(r->hdr.opcode==BATTMGR_CHG_CTRL_LIMIT_EN && r->enable==1 && r->target_soc==80 && r->delta_soc==10);
 writes++;return step(b); /* Opaque reply, never an actuator-success claim. */
}
C
awk '/^struct qcom_battmgr_uke_settings \{/ {emit=1} emit {print} emit && /^};/ {exit}' "$source"
for function in qcom_battmgr_uke_settings_read qcom_battmgr_uke_apply_existing_cap uke_charge_apply_existing_cap_store; do
 awk -v name="$function" '$0 ~ "^static (int|ssize_t) " name "\\(" {emit=1}
  emit {print} emit && /^}/ {exit}' "$source"
done
cat <<'C'
static void initialize(struct qcom_battmgr *b) {
 *b=(struct qcom_battmgr){.variant=QCOM_BATTMGR_UKE,.service_up=true,.lock.available=true,
  .transaction={.instance_ns=71,.generation=7,.firmware_generation=2,.source_generation=3}};
 clock_ns=5*NSEC_PER_SEC;request_ns=1000000;calls=writes=fail_at=change_at=0;
 privileged=remote_present=remote_enabled=true;remote_online=ignore_set=false;
 remote_start=70;remote_end=80;remote_health=POWER_SUPPLY_HEALTH_GOOD;
}
int main(void) {
 struct qcom_battmgr b;initialize(&b);struct device dev={.data=&b};
#if !CONFIG_BATTERY_QCOM_BATTMGR_UKE_THRESHOLDS
 assert(uke_charge_apply_existing_cap_store(&dev,NULL,"1",1)==-EOPNOTSUPP && !calls && !writes);
#else
 assert(uke_charge_apply_existing_cap_store(&dev,NULL,"1",1)==1 && writes==1 && calls==10);
 assert(!b.control.preconfigured_apply && b.control.preconfigured_limit_attempted);
 assert(b.control.preconfigured_uncertain); /* A reply is not actuator proof. */
 assert(!b.control.verified && !b.control.current_verified && !b.control.expires_ns);
 unsigned previous=calls;
 assert(qcom_battmgr_uke_apply_existing_cap(&b)==-EUCLEAN && calls==previous);
 for(unsigned failure=1;failure<=10;failure++) {
  initialize(&b);fail_at=failure;
  assert(qcom_battmgr_uke_apply_existing_cap(&b)<0 && calls==failure);
  assert(!b.control.preconfigured_apply && writes==(failure>=7));
  if(failure>=7) {
   previous=calls;
   assert(b.control.preconfigured_uncertain && b.control.preconfigured_limit_attempted);
   assert(qcom_battmgr_uke_apply_existing_cap(&b)==-EUCLEAN && calls==previous);
  }
 }
 for(unsigned change=1;change<=10;change++) {
  initialize(&b);change_at=change;
  assert(qcom_battmgr_uke_apply_existing_cap(&b)<0 && !b.control.preconfigured_apply);
  assert(writes==(change>=7));
 }
 for(unsigned fault=0;fault<9;fault++) {
  initialize(&b);
  if(fault==0)remote_start=75;
  if(fault==1)remote_end=100;
  if(fault==2)remote_present=false;
  if(fault==3)remote_health=0;
  if(fault==4)remote_online=true;
  if(fault==5){b.control.verified=true;b.control.verified_until_ns=clock_ns+1;}
  if(fault==6)remote_enabled=false;
  if(fault==7)b.control.preconfigured_limit_attempted=true;
  if(fault==8)b.control.preconfigured_uncertain=true;
  assert(qcom_battmgr_uke_apply_existing_cap(&b)<0 && !writes);
 }
 initialize(&b);request_ns=2*NSEC_PER_SEC;
 assert(qcom_battmgr_uke_apply_existing_cap(&b)==-ESTALE && !writes);
 initialize(&b);privileged=false;
 assert(uke_charge_apply_existing_cap_store(&dev,NULL,"1",1)==-EPERM && !calls);
 initialize(&b);b.lock.available=false;
 assert(uke_charge_apply_existing_cap_store(&dev,NULL,"1",1)==-EBUSY && !calls);
 for(unsigned i=0;i<3;i++) {
  const char *bad[]={"0","true","1 extra"};initialize(&b);
  assert(uke_charge_apply_existing_cap_store(&dev,NULL,bad[i],strlen(bad[i]))==-EINVAL && !calls);
 }
#endif
 return 0;
}
C
} > "$work/apply.c"
for enabled in 0 1; do
 "${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
  -DCONFIG_BATTERY_QCOM_BATTMGR_UKE_THRESHOLDS="$enabled" "$work/apply.c" -o "$work/cap-$enabled"
 "$work/cap-$enabled"
done
printf '%s\n' 'Actual existing-band request: fixed wire, offline/health/ownership, readback and persistent uncertainty passed off/on; no physical qualification'
