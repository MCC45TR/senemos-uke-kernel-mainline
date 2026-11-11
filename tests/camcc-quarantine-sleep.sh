#!/usr/bin/env bash
# COPR only: actual system callbacks with synthetic ownership and power state.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
profile=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
sed '/^#include /d' "$profile/src/camera/provider/camcc-sm7675-sleep.h" > "$work/sleep.h"
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>
#define __maybe_unused
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define CAM_CC_POWER_RAILS 7
#define PM_SUSPEND_TO_IDLE 1
#define RUNTIME_PM_OPS(s,r,i) .runtime_suspend=s,.runtime_resume=r,
#define SYSTEM_SLEEP_PM_OPS(s,r) .suspend=s,.resume=r,
#define dev_info(...) ((void)0)
struct device;
struct dev_pm_ops { int (*runtime_suspend)(struct device *); int (*runtime_resume)(struct device *);int (*suspend)(struct device *);int (*resume)(struct device *); };
struct driver { const struct dev_pm_ops *pm; };
struct device { struct driver *driver;void *pm_domain,*data;struct { int usage_count,child_count; } power; };
static const struct dev_pm_ops cam_cc_native_pm_ops;
static struct { struct device *dev;int fault,primary_error,rollback_error;unsigned uncertain_rails,votes;bool iface_on,publication_started; } cam_cc_power;
static struct { struct { bool complete;int error;const char *phase; } probe;unsigned proxy_votes;bool pm_enabled,probe_pm_held,ready,registered[3];void *boot_rcgs[3]; } cam_cc_native;
struct domain { bool controller_pm_held; };
static struct domain domains[2];static struct domain *cam_cc_sm7675_gdscs[]={&domains[0],&domains[1]};
static int pm_suspend_target_state,forced_suspend,forced_resume;
static void *dev_get_drvdata(struct device *dev) { return dev->data; }
static int atomic_read(int *value) { return *value; }
static int pm_runtime_force_suspend(struct device *dev) { (void)dev;forced_suspend++;return -EIO; }
static int pm_runtime_force_resume(struct device *dev) { (void)dev;forced_resume++;return -ENODEV; }
static int cam_cc_power_suspend(struct device *dev) { (void)dev;return -EIO; }
static int cam_cc_power_resume(struct device *dev) { (void)dev;return -EIO; }
#include "sleep.h"
static struct driver driver={.pm=&cam_cc_native_pm_ops};
static struct device dev={.driver=&driver};
static void reset(void) {
 memset(&cam_cc_power,0,sizeof(cam_cc_power));memset(&cam_cc_native,0,sizeof(cam_cc_native));memset(domains,0,sizeof(domains));
 cam_cc_power.dev=&dev;dev.data=&cam_cc_power;dev.pm_domain=NULL;dev.driver=&driver;dev.power.usage_count=2;dev.power.child_count=0;
 cam_cc_power.fault=-EIO;cam_cc_power.primary_error=-EOPNOTSUPP;cam_cc_power.iface_on=true;cam_cc_power.votes=7;
 cam_cc_native.probe.complete=true;cam_cc_native.probe.error=-EOPNOTSUPP;cam_cc_native.probe.phase="crm-admission";
 cam_cc_native.proxy_votes=7;cam_cc_native.pm_enabled=true;cam_cc_native.probe_pm_held=true;
 pm_suspend_target_state=PM_SUSPEND_TO_IDLE;forced_suspend=forced_resume=0;cam_cc_system_sleep_held=false;
}
int main(void) {
 reset();assert(cam_cc_quarantine_sleep_hold(&dev));
 unsigned char before_power[sizeof(cam_cc_power)],before_native[sizeof(cam_cc_native)];
 memcpy(before_power,&cam_cc_power,sizeof(cam_cc_power));memcpy(before_native,&cam_cc_native,sizeof(cam_cc_native));
 for(unsigned i=0;i<20;i++) {
  assert(!cam_cc_native_pm_ops.suspend(&dev) && cam_cc_system_sleep_held);
  assert(cam_cc_native_pm_ops.suspend(&dev)==-EBUSY);
  assert(!cam_cc_native_pm_ops.resume(&dev) && !cam_cc_system_sleep_held);
  assert(!forced_suspend&&!forced_resume);
  assert(!memcmp(before_power,&cam_cc_power,sizeof(cam_cc_power))&&!memcmp(before_native,&cam_cc_native,sizeof(cam_cc_native)));
 }
 for(unsigned fault=0;fault<22;fault++) {
  reset();
  switch(fault) {
  case 0:dev.data=NULL;break;case 1:dev.driver=NULL;break;case 2:dev.pm_domain=&dev;break;
  case 3:cam_cc_native.probe.complete=false;break;case 4:cam_cc_native.probe.error=-EIO;break;
  case 5:cam_cc_native.probe.phase="clock-registration";break;case 6:cam_cc_power.primary_error=-EIO;break;
  case 7:cam_cc_power.rollback_error=-EIO;break;case 8:cam_cc_power.uncertain_rails=1;break;
  case 9:cam_cc_power.iface_on=false;break;case 10:cam_cc_power.votes=3;break;
  case 11:cam_cc_native.proxy_votes=3;break;case 12:cam_cc_native.pm_enabled=false;break;
  case 13:cam_cc_native.probe_pm_held=false;break;case 14:cam_cc_native.ready=true;break;
  case 15:cam_cc_power.publication_started=true;break;case 16:dev.power.usage_count=3;break;
  case 17:dev.power.child_count=1;break;case 18:cam_cc_native.registered[1]=true;break;
  case 19:cam_cc_native.boot_rcgs[1]=&dev;break;case 20:domains[1].controller_pm_held=true;break;
  case 21:cam_cc_power.fault=0;break;
  }
  assert(!cam_cc_quarantine_sleep_hold(&dev));assert(cam_cc_system_suspend(&dev)==-EIO && forced_suspend==1 && !cam_cc_system_sleep_held);
 }
 reset();pm_suspend_target_state=3;assert(cam_cc_system_suspend(&dev)==-EIO && forced_suspend==1);
 reset();assert(!cam_cc_system_suspend(&dev));cam_cc_power.uncertain_rails=1;
 assert(cam_cc_system_resume(&dev)==-EIO && cam_cc_system_sleep_held && !forced_resume);
 reset();assert(cam_cc_system_resume(&dev)==-ENODEV && forced_resume==1);
 puts("Actual CAMCC sleep callbacks: exact unpublished s2idle holds, repeated cycles,22 refusal controls, deep sleep and changed-resume rejection pass.");
}
C
for compiler in gcc clang; do
 "$compiler" -std=gnu11 -O1 -g -Wall -Wextra -Werror -fsanitize=address,undefined -fno-sanitize-recover=all -I"$work" "$work/check.c" -o "$work/$compiler"
 ASAN_OPTIONS=detect_leaks=1:halt_on_error=1 "$work/$compiler"
done
