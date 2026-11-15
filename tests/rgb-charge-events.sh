#!/usr/bin/env bash
# COPR fixture: actual battery worker and selection, simulated power supplies.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <errno.h>
#include "uke-rgb-policy.h"
typedef __u64 u64;
typedef __u32 u32;
struct kref { int unused; };
struct mutex { bool held; };
struct led_classdev;
struct led_classdev_mc;
struct miscdevice { int unused; };
struct work_struct { int unused; };
struct delayed_work { struct work_struct work; };
struct notifier_block { int unused; };
struct power_supply_desc { const char *name; int type; };
struct power_supply { const struct power_supply_desc *desc; };
union power_supply_propval { int intval; };
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
#define to_delayed_work(p) container_of(p,struct delayed_work,work)
#define READ_ONCE(value) (value)
#define HZ 100
#define POWER_SUPPLY_TYPE_BATTERY 1
#define POWER_SUPPLY_PROP_CAPACITY 1
#define POWER_SUPPLY_PROP_STATUS 2
#define POWER_SUPPLY_PROP_CHARGE_CONTROL_END_THRESHOLD 3
#define POWER_SUPPLY_PROP_ONLINE 4
#define POWER_SUPPLY_STATUS_FULL 4
#define POWER_SUPPLY_STATUS_NOT_CHARGING 3
#define PSY_EVENT_PROP_CHANGED 0
#define NOTIFY_OK 1
static const struct power_supply_desc bat_desc={"qcom-battmgr-bat",1};
static const struct power_supply_desc usb_desc={"qcom-battmgr-usb",2};
static const struct power_supply_desc other_desc={"unrelated",1};
static struct power_supply bat={&bat_desc},usb={&usb_desc},other={&other_desc};
static int soc=80,status=POWER_SUPPLY_STATUS_FULL,target=80,target_again=80,online=1;
static int capacity_error,status_error,target_error,online_error,refs,reads,target_reads;
static unsigned pattern_requests,battery_requests,last_retry;
static struct delayed_work *battery_work_address;
static void *system_freezable_wq;
static u64 clock_ms=1000;
static u64 now_ms(void) { return clock_ms; }
static void mutex_lock(struct mutex *m) { assert(!m->held);m->held=true; }
static void mutex_unlock(struct mutex *m) { assert(m->held);m->held=false; }
static struct power_supply *power_supply_get_by_name(const char *name)
{
 if(!strcmp(name,bat_desc.name)){target_reads=0;++refs;return &bat;}
 assert(!strcmp(name,usb_desc.name));++refs;return &usb;
}
static void power_supply_put(struct power_supply *supply) { assert(supply && refs>0);--refs; }
static int power_supply_get_property(struct power_supply *supply,int prop,union power_supply_propval *value)
{
 assert(refs>0);++reads;
 if(prop==POWER_SUPPLY_PROP_ONLINE){assert(supply==&usb);value->intval=online;return online_error;}
 assert(supply==&bat);
 if(prop==POWER_SUPPLY_PROP_CAPACITY){value->intval=soc;return capacity_error;}
 if(prop==POWER_SUPPLY_PROP_STATUS){value->intval=status;return status_error;}
 assert(prop==POWER_SUPPLY_PROP_CHARGE_CONTROL_END_THRESHOLD);
 value->intval=target_reads++?target_again:target;return target_error;
}
static void mod_delayed_work(void *queue,struct delayed_work *work,unsigned delay)
{
 assert(queue==system_freezable_wq);
 if(work==battery_work_address){++battery_requests;last_retry=delay;}
 else {assert(!delay);++pattern_requests;}
}
C
awk '/^struct uke_rgb \{/ {emit=1} emit{print} emit && /^};/{exit}' "$root/src/leds/leds-uke-rgb.c" >> "$work/check.c"
for name in selected battery_work battery_event; do
 awk -v name="$name" '$0 ~ "^static .* "name"\\(" {emit=1} emit{print} emit && /^}/{exit}' "$root/src/leds/leds-uke-rgb.c" >> "$work/check.c"
done
cat >> "$work/check.c" <<'C'
static void sample(struct uke_rgb *rgb)
{
 battery_work_address=&rgb->battery_work;
 battery_work(&rgb->battery_work.work);
 assert(!refs && !rgb->lock.held);
}
int main(void)
{
 struct uke_rgb rgb={.active=true};
 sample(&rgb);assert(!rgb.charge_notice && !rgb.charge.armed && !battery_requests);
 for(unsigned i=0;i<50;++i)sample(&rgb);
 assert(!rgb.charge_notice && !battery_requests);
 soc=79;status=1;sample(&rgb);
 soc=80;status=POWER_SUPPLY_STATUS_FULL;sample(&rgb);assert(!rgb.charge_notice);
 soc=78;status=1;sample(&rgb);assert(rgb.charge.armed);
 soc=80;sample(&rgb);assert(!rgb.charge_notice);
 status=POWER_SUPPLY_STATUS_FULL;online=0;sample(&rgb);assert(!rgb.charge_notice);
 online=1;status_error=-EIO;sample(&rgb);assert(!rgb.charge_notice);
 status_error=0;target_again=81;sample(&rgb);assert(!rgb.charge_notice && rgb.charge.armed);
 target_again=80;sample(&rgb);
 assert(rgb.charge_notice && !rgb.charge.armed && rgb.charge_epoch_ms==1000);
 assert(selected(&rgb,1000)==UKE_RGB_CHARGE_COMPLETE);
 for(unsigned i=0;i<50;++i){++clock_ms;sample(&rgb);assert(rgb.charge_epoch_ms==1000);}
 assert(selected(&rgb,5499)==UKE_RGB_CHARGE_COMPLETE);
 assert(selected(&rgb,5500)==UKE_RGB_OFF);
 rgb.manual=true;assert(selected(&rgb,5500)==UKE_RGB_MANUAL);
 rgb.camera=true;assert(selected(&rgb,1000)==UKE_RGB_FRONT_CAMERA);rgb.camera=false;
 rgb.battery_mode=UKE_RGB_CRITICAL_BATTERY;
 assert(selected(&rgb,1000)==UKE_RGB_CRITICAL_BATTERY);
 soc=5;status=1;sample(&rgb);assert(rgb.battery_mode==UKE_RGB_CRITICAL_BATTERY);
 soc=15;sample(&rgb);assert(rgb.battery_mode==UKE_RGB_LOW_BATTERY);
 soc=16;sample(&rgb);assert(rgb.battery_mode==UKE_RGB_OFF);
 rgb.battery_mode=UKE_RGB_CRITICAL_BATTERY;capacity_error=-EIO;
 for(unsigned i=0;i<5;++i)sample(&rgb);
 assert(rgb.battery_mode==UKE_RGB_CRITICAL_BATTERY && battery_requests==3 && last_retry==4*HZ);
 capacity_error=0;soc=50;sample(&rgb);assert(!rgb.telemetry_retries && !rgb.battery_mode);
 unsigned before=battery_requests;
 battery_event(&rgb.battery_notifier,PSY_EVENT_PROP_CHANGED,&other);assert(battery_requests==before);
 battery_event(&rgb.battery_notifier,PSY_EVENT_PROP_CHANGED,&bat);assert(battery_requests==before+1 && !last_retry);
 battery_event(&rgb.battery_notifier,PSY_EVENT_PROP_CHANGED,&usb);assert(battery_requests==before+2);
 rgb.dead=true;before=reads;sample(&rgb);assert(reads==(int)before);
 before=battery_requests;battery_event(&rgb.battery_notifier,PSY_EVENT_PROP_CHANGED,&bat);
 assert(battery_requests==before && !refs);
}
C
${CC:-cc} -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined -fno-omit-frame-pointer \
 -I "$root/src/leds" "$work/check.c" -o "$work/check"
"$work/check"
printf 'Actual RGB battery worker: valid completion/power, stable target, no repeat, 2-point rearm, camera priority, stale warning, bounded retry, event ownership and balanced references passed; no hardware.\n'
