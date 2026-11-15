/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual crash worker extracted from the current cumulative source. */
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
struct work_struct { int unused; };
struct kobject { int unused; };
struct device { struct kobject kobj;struct device *parent; };
struct mutex { bool held; };
enum { RPROC_OFFLINE,RPROC_RUNNING,RPROC_CRASHED,RPROC_SUSPENDED,KOBJ_CHANGE=9 };
struct rproc { struct work_struct crash_handler;struct device dev;struct mutex lock;bool deleting,recovery_disabled;int state;unsigned int crash_cnt;const char *name; };
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
#define READ_ONCE(v) (v)
static struct rproc *active;
static unsigned int notifications,events,recoveries,relaxes;
static bool event_fail;
static void mutex_lock(struct mutex *m) { assert(!m->held);m->held=true; }
static void mutex_unlock(struct mutex *m) { assert(m->held);m->held=false; }
static void log_message(struct device *dev,const char *fmt,...) { (void)dev;(void)fmt; }
#define dev_dbg log_message
#define dev_err log_message
#define dev_warn log_message
static void sysfs_notify(struct kobject *k,const char *dir,const char *attr) {
 assert(k==&active->dev.kobj && !dir && !strcmp(attr,"state"));
 assert(!active->lock.held && active->state==RPROC_CRASHED);notifications++;
}
static int kobject_uevent_env(struct kobject *k,int action,char **env) {
 assert(k==&active->dev.kobj && action==KOBJ_CHANGE && !active->lock.held);
 assert(active->state==RPROC_CRASHED && !strcmp(env[0],"RPROC_EVENT=crash") && !env[1]);
 assert(notifications==1);events++;return event_fail?-1:0;
}
static void rproc_trigger_recovery(struct rproc *r) {
 assert(r==active && !r->lock.held && events==1);recoveries++;
}
static void pm_relax(struct device *p) { (void)p;assert(!active->lock.held);relaxes++; }
#include "rproc-crash-worker.h"
int main(void) {
 unsigned int cases=0;
 for(int state=0;state<4;state++)for(unsigned int deleting=0;deleting<2;deleting++)
 for(unsigned int disabled=0;disabled<2;disabled++)for(unsigned int failure=0;failure<2;failure++) {
  struct rproc r={.deleting=deleting,.recovery_disabled=disabled,.state=state,.name="fixture"};
  active=&r;notifications=events=recoveries=relaxes=0;event_fail=failure;
  rproc_crash_handler_work(&r.crash_handler);
  bool report=!deleting && state!=RPROC_OFFLINE && state!=RPROC_CRASHED;
  assert(notifications==(unsigned int)report && events==(unsigned int)report);
  assert(recoveries==(unsigned int)(report && !disabled));
  assert(r.crash_cnt==(unsigned int)report && !r.lock.held);
  assert(relaxes<=1);cases++;
 }
 printf("Actual remoteproc crash worker: %u lifecycle/notification/recovery/error cases passed; controlled providers only.\n",cases);
}
