#!/usr/bin/bash
# COPR only. Extract actual read/cache/show functions; firmware is synthetic.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
source=${1:?Prepared kernel}/drivers/power/supply/qcom_battmgr_uke_control.h
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
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
typedef unsigned long long u64;typedef uint32_t u32;
#define NSEC_PER_SEC 1000000000ULL
enum {BATTMGR_USB_PROPERTY_GET=0x32,USB_MOISTURE_EN=8,USB_MOISTURE_STATUS=9};
struct qcom_battmgr_uke_transaction {int lock;u64 instance_ns;u32 generation,firmware_generation,source_generation;bool desynced,suspended,removing;};
struct qcom_battmgr {
 int lock;bool service_up;struct qcom_battmgr_uke_transaction transaction;
 struct {u32 moisture_enabled,moisture_status;} usb;
 struct {u64 received_ns,dry_since_ns,dry_last_ns,inhibit_readback_ns;
 u32 generation,firmware,source,enabled,moisture,dry_samples,faults;
 bool wet_latched,inhibit_owned,inhibit_verified,inhibit_uncertain;} protection;
 struct {u64 expires_ns,verified_until_ns;bool verified,standard_clients;} control;
};
struct device {struct qcom_battmgr *data;};struct device_attribute {int unused;};
static bool mutex_held,spin_held;static unsigned requests,fail_at,change_at,format_calls,unlocks,mutate_unlock;
static u64 clock_ns,request_ns;static u32 remote_enabled,remote_wet;static struct qcom_battmgr *active;
static u64 ktime_get_boottime_ns(void){return clock_ns;}
static struct qcom_battmgr *dev_get_drvdata(struct device *dev){return dev->data;}
static u32 qcom_battmgr_uke_generation(struct qcom_battmgr *b){return b->transaction.generation;}
static void mutex_lock(int *lock){(void)lock;assert(!mutex_held&&!spin_held);mutex_held=true;}
static void mutex_unlock(int *lock){(void)lock;assert(mutex_held&&!spin_held);mutex_held=false;}
static void spin_enter(int *lock,unsigned long *flags){(void)lock;*flags=0;assert(mutex_held&&!spin_held);spin_held=true;}
static void spin_leave(int *lock,unsigned long flags){(void)lock;(void)flags;assert(mutex_held&&spin_held);spin_held=false;unlocks++;if(unlocks==mutate_unlock)active->transaction.generation++;}
#define spin_lock_irqsave(lock,flags) spin_enter((lock),&(flags))
#define spin_unlock_irqrestore(lock,flags) spin_leave((lock),(flags))
static int qcom_battmgr_request_property(struct qcom_battmgr *b,unsigned opcode,unsigned property,int value){
 assert(mutex_held&&!spin_held&&opcode==BATTMGR_USB_PROPERTY_GET&&value==0);
 assert(property==USB_MOISTURE_EN+requests);
 if(b->transaction.removing)return -ENODEV;
 if(b->transaction.suspended)return -EBUSY;
 if(b->transaction.desynced||!b->service_up)return -ENOTCONN;
 assert(requests<2);requests++;clock_ns+=request_ns;
 if(requests==change_at)b->transaction.generation++;
 if(requests==fail_at)return -ETIMEDOUT;
 if(property==USB_MOISTURE_EN)b->usb.moisture_enabled=remote_enabled;
 else b->usb.moisture_status=remote_wet;
 return 0;
}
static ssize_t sysfs_emit(char *buf,const char *format,...){
 assert(mutex_held&&spin_held);format_calls++;
 va_list args;va_start(args,format);int n=vsnprintf(buf,4096,format,args);va_end(args);return n;
}
C
awk '/^struct qcom_battmgr_uke_protection \{/ {emit=1} emit{print} emit&&/^};/{exit}' "$source"
for function in qcom_battmgr_uke_protection_read qcom_battmgr_uke_protection_cache_live uke_charge_protection_state_show;do
 awk -v name="$function" '$0~"^static (int|bool|ssize_t) "name"\\("{emit=1} emit{print} emit&&/^}/{found=1;exit} END{if(!found)exit 1}' "$source"
done
cat <<'C'
static void initialize(struct qcom_battmgr *b){
 *b=(struct qcom_battmgr){.service_up=true,.transaction={.instance_ns=41,.generation=7,.firmware_generation=2,.source_generation=3},
 .control={.expires_ns=91,.verified_until_ns=93,.verified=false,.standard_clients=false}};
 active=b;mutex_held=spin_held=false;requests=fail_at=change_at=format_calls=unlocks=mutate_unlock=0;
 clock_ns=10*NSEC_PER_SEC;request_ns=1000000;remote_enabled=1;remote_wet=0;
}
static void cache(struct qcom_battmgr *b,u64 age){
 b->protection.received_ns=clock_ns-age;b->protection.generation=7;b->protection.firmware=2;b->protection.source=3;b->protection.enabled=1;
}
static ssize_t show(struct qcom_battmgr *b,char *text){
 struct device d={.data=b};memset(text,'X',4096);
 ssize_t ret=uke_charge_protection_state_show(&d,NULL,text);
 assert(!mutex_held&&!spin_held&&b->control.expires_ns==91&&b->control.verified_until_ns==93&&!b->control.verified&&!b->control.standard_clients);
 return ret;
}
static void record(const char *text,unsigned valid,unsigned wet){
 unsigned version,g,f,s,en,m,v,latch,inh,faults;u64 instance,received,dry;
 assert(sscanf(text,"%u %llu %u %u %u %llu %u %u %u %u %u %llu %u",&version,&instance,&g,&f,&s,&received,&en,&m,&v,&latch,&inh,&dry,&faults)==13);
 assert(version==1&&instance==41&&v==valid&&m==wet&&received>0);
}
int main(void){
 struct qcom_battmgr b;char text[4096];
 initialize(&b);assert(show(&b,text)>0&&requests==2&&format_calls==1);record(text,1,0);
 const u64 ages[]={0,1,5*NSEC_PER_SEC};
 for(unsigned i=0;i<3;i++){initialize(&b);cache(&b,ages[i]);assert(show(&b,text)>0&&!requests);record(text,1,0);}
 initialize(&b);cache(&b,5*NSEC_PER_SEC+1);assert(show(&b,text)>0&&requests==2);record(text,1,0);
 initialize(&b);cache(&b,1);b.protection.received_ns=clock_ns+1;assert(show(&b,text)>0&&requests==2);record(text,1,0);
 for(unsigned reason=0;reason<3;reason++){
  initialize(&b);cache(&b,1);if(reason==0)b.protection.generation--;if(reason==1)b.protection.firmware--;if(reason==2)b.protection.source--;
  assert(show(&b,text)>0&&requests==2);record(text,1,0);
 }
 for(unsigned reason=0;reason<4;reason++){
  initialize(&b);cache(&b,1);int error=-ENOTCONN;
  if(reason==0)b.service_up=false;
  if(reason==1)b.transaction.desynced=true;
  if(reason==2){b.transaction.suspended=true;error=-EBUSY;}
  if(reason==3){b.transaction.removing=true;error=-ENODEV;}
  assert(show(&b,text)==error&&!requests&&!format_calls&&text[0]=='X');
 }
 for(unsigned i=1;i<=2;i++){
  initialize(&b);fail_at=i;b.protection.wet_latched=true;b.protection.faults=7;
  assert(show(&b,text)==-ETIMEDOUT&&requests==i&&!format_calls&&text[0]=='X'&&b.protection.wet_latched&&b.protection.faults==7);
  initialize(&b);change_at=i;assert(show(&b,text)==-ESTALE&&requests==2&&!format_calls);
 }
 initialize(&b);request_ns=3*NSEC_PER_SEC;assert(show(&b,text)==-ESTALE&&requests==2&&!format_calls);
 for(unsigned i=0;i<2;i++){
  initialize(&b);if(i)remote_wet=2;else remote_enabled=2;assert(show(&b,text)==-ESTALE&&requests==2&&!format_calls);
 }
 initialize(&b);remote_wet=1;assert(show(&b,text)>0&&requests==2&&b.protection.wet_latched);record(text,1,1);
 initialize(&b);cache(&b,1);mutate_unlock=1;assert(show(&b,text)>0&&!requests);record(text,0,0);
 puts("Actual demand protection: fresh/boundary/clock/epoch/error/partial/quiescent/wet/race checks; no SET,lease or retry.");
}
C
} > "$work/test.c"
flags=(-std=gnu11 -O2 -g -Wall -Wextra -Werror -Wno-unused-parameter)
if [[ ${SANITIZE:-0} == 1 ]];then flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -fno-pie -no-pie);fi
"${CC:-cc}" "${flags[@]}" "$work/test.c" -o "$work/test"
"$work/test"
