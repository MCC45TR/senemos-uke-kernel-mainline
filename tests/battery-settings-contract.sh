#!/usr/bin/env bash
# Actual diagnostic helper and sysfs wrapper; synthetic host I/O only.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
source=$kernel/drivers/power/supply/qcom_battmgr_uke_control.h
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
grep -Fq '__ATTR(uke_charge_settings, 0400, uke_charge_settings_show, NULL)' "$source"
{
cat <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
typedef unsigned long long u64;
typedef uint32_t u32;
#define NSEC_PER_SEC 1000000000ULL
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define IS_ENABLED(x) (x)
#define CAP_SYS_ADMIN 21
#define lockdep_assert_held(l) ((void)(l))
#define spin_lock_irqsave(l,f) ((void)(l),(f)=0)
#define spin_unlock_irqrestore(l,f) ((void)(l),(void)(f))
struct task_struct { int unused; };
static struct task_struct *get_current(void) { return NULL; }
#define current get_current()
enum { QCOM_BATTMGR_UKE=1, BATT_CHG_CTRL_EN=24,
 BATT_CHG_CTRL_START_THR=25, BATT_CHG_CTRL_END_THR=26,
 BATTMGR_BAT_PROPERTY_GET=0x30 };
struct mutex { bool available; };
struct qcom_battmgr_uke_transaction {
 int lock; bool desynced,suspended,removing;
 u64 instance_ns; u32 generation,firmware_generation,source_generation;
};
struct qcom_battmgr {
 int variant; bool service_up; struct mutex lock;
 struct qcom_battmgr_uke_transaction transaction;
 struct { u64 expires_ns,settings_probe_ns; bool enabled,verified,current_verified; } control;
 struct { u32 charge_ctrl_start,charge_ctrl_end; } info;
};
struct device { struct qcom_battmgr *data; };
struct device_attribute { int unused; };
static u64 clock_ns,request_ns;
static unsigned requests,fail_at,change_at;
static bool privileged,remote_enabled;
static u32 remote_start,remote_end;
static u64 ktime_get_boottime_ns(void) { return clock_ns; }
static bool capable(int cap) { assert(cap==CAP_SYS_ADMIN); return privileged; }
static struct qcom_battmgr *dev_get_drvdata(struct device *dev) { return dev->data; }
static bool mutex_trylock(struct mutex *lock) { return lock->available; }
static void mutex_unlock(struct mutex *lock) { assert(lock->available); }
static ssize_t sysfs_emit(char *buf,const char *format,...) {
 va_list args; va_start(args,format); int n=vsnprintf(buf,4096,format,args); va_end(args); return n;
}
static u32 qcom_battmgr_uke_generation(struct qcom_battmgr *b) { return b->transaction.generation; }
static int qcom_battmgr_request_property(struct qcom_battmgr *b,unsigned opcode,unsigned property,int value) {
 assert(opcode==BATTMGR_BAT_PROPERTY_GET && value==0);
 assert(property==BATT_CHG_CTRL_EN+requests); // Exactly three fixed GETs.
 assert(requests<3); requests++; clock_ns+=request_ns;
 if(requests==change_at) b->transaction.generation++;
 if(requests==fail_at) return -EPROTO;
 if(property==BATT_CHG_CTRL_EN) b->control.enabled=remote_enabled;
 if(property==BATT_CHG_CTRL_START_THR) b->info.charge_ctrl_start=remote_start;
 if(property==BATT_CHG_CTRL_END_THR) b->info.charge_ctrl_end=remote_end;
 return 0;
}
C
awk '/^struct qcom_battmgr_uke_settings \{/ {emit=1} emit {print} emit && /^};/ {exit}' "$source"
for function in qcom_battmgr_uke_settings_read uke_charge_settings_show; do
 awk -v name="$function" '$0 ~ "^static (int|ssize_t) " name "\\(" {emit=1}
  emit {print} emit && /^}/ {exit}' "$source"
done
cat <<'C'
static void initialize(struct qcom_battmgr *b) {
 *b=(struct qcom_battmgr){.variant=QCOM_BATTMGR_UKE,.service_up=true,.lock.available=true,
  .transaction={.instance_ns=71,.generation=7,.firmware_generation=2,.source_generation=3}};
 clock_ns=5*NSEC_PER_SEC; request_ns=1000000;
 requests=fail_at=change_at=0; privileged=remote_enabled=true; remote_start=70;remote_end=80;
}
int main(void) {
 struct qcom_battmgr b;initialize(&b);struct device dev={.data=&b};char output[4096];
 assert(get_current()==NULL);
#if !CONFIG_BATTERY_QCOM_BATTMGR_UKE_THRESHOLDS
 assert(uke_charge_settings_show(&dev,NULL,output)==-EOPNOTSUPP && !requests);
#else
 struct qcom_battmgr_uke_settings result,unchanged;
 memset(&result,0xa5,sizeof(result));unchanged=result;
 assert(!qcom_battmgr_uke_settings_read(&b,&result) && requests==3);
 assert(result.instance==71 && result.generation==7 && result.firmware==2 && result.source==3);
 assert(result.received_ns==clock_ns && result.enabled==1 && result.start==70 && result.end==80);
 assert(!b.control.expires_ns && !b.control.verified && !b.control.current_verified);
 requests=0;assert(qcom_battmgr_uke_settings_read(&b,&result)==-EAGAIN && !requests);
 clock_ns=6*NSEC_PER_SEC;
 assert(!qcom_battmgr_uke_settings_read(&b,&result) && requests==3);
 initialize(&b);remote_enabled=false;remote_start=remote_end=0;
 assert(!qcom_battmgr_uke_settings_read(&b,&result));
 assert(!result.enabled && !result.start && !result.end);
 for(unsigned fail=1;fail<=3;fail++) {
  initialize(&b);fail_at=fail;result=unchanged;
  assert(qcom_battmgr_uke_settings_read(&b,&result)==-EPROTO && requests==fail);
  assert(!memcmp(&result,&unchanged,sizeof(result)));
 }
 for(unsigned change=1;change<=3;change++) {
  initialize(&b);change_at=change;result=unchanged;
  assert(qcom_battmgr_uke_settings_read(&b,&result)==-ESTALE && requests==change);
  assert(!memcmp(&result,&unchanged,sizeof(result)));
 }
 for(unsigned state=0;state<5;state++) {
  initialize(&b);
  if(state==0)b.service_up=false;
  if(state==1)b.transaction.desynced=true;
  if(state==2)b.transaction.suspended=true;
  if(state==3)b.transaction.removing=true;
  if(state==4)b.transaction.instance_ns=0;
  assert(qcom_battmgr_uke_settings_read(&b,&result)==-EHOSTDOWN && !requests);
 }
 initialize(&b);b.control.expires_ns=clock_ns+1;
 assert(qcom_battmgr_uke_settings_read(&b,&result)==-EBUSY && !requests);
 initialize(&b);b.variant=0;
 assert(qcom_battmgr_uke_settings_read(&b,&result)==-EOPNOTSUPP && !requests);
 initialize(&b);remote_end=101;result=unchanged;
 assert(qcom_battmgr_uke_settings_read(&b,&result)==-ENODATA);
 assert(!memcmp(&result,&unchanged,sizeof(result)));
 initialize(&b);remote_start=90;
 assert(qcom_battmgr_uke_settings_read(&b,&result)==-ENODATA);
 initialize(&b);request_ns=2*NSEC_PER_SEC;result=unchanged;
 assert(qcom_battmgr_uke_settings_read(&b,&result)==-ESTALE);
 assert(!memcmp(&result,&unchanged,sizeof(result)));
 initialize(&b);privileged=false;
 assert(uke_charge_settings_show(&dev,NULL,output)==-EPERM && !requests);
 initialize(&b);b.lock.available=false;
 assert(uke_charge_settings_show(&dev,NULL,output)==-EBUSY && !requests);
 initialize(&b);
 assert(uke_charge_settings_show(&dev,NULL,output)>0 && requests==3);
 assert(!strncmp(output,"1 71 7 2 3 ",11) && strstr(output," 1 70 80\n"));
#endif
 return 0;
}
C
} > "$work/settings.c"
for enabled in 0 1; do
 "${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
  -DCONFIG_BATTERY_QCOM_BATTMGR_UKE_THRESHOLDS="$enabled" "$work/settings.c" -o "$work/settings-$enabled"
 "$work/settings-$enabled"
done
printf '%s\n' 'Actual read-only settings, root/lease/rate/lifecycle/error boundaries passed off/on; no firmware or device access'
