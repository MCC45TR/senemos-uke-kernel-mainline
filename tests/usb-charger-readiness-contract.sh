#!/usr/bin/env bash
# Host-only execution of the actual DWC3 worker and supplier-admission function.
set -Eeuo pipefail
kernel=${1:?Pass the prepared kernel source directory}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
cat <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>
struct work_struct { int unused; };
struct delayed_work { struct work_struct work; };
struct device { struct device *parent; };
struct power_supply { struct device dev; };
struct dwc3 { struct delayed_work vbus_draw_work; struct power_supply *usb_psy; struct device *dev; unsigned int current_limit, vbus_draw_retries; };
union power_supply_propval { int intval; };
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
#define to_delayed_work(p) container_of(p,struct delayed_work,work)
#define READ_ONCE(x) (x)
#define WRITE_ONCE(x,v) ((x)=(v))
#define POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT 1
#define DL_FLAG_AUTOREMOVE_CONSUMER 2
#define EPROBE_DEFER 517
#define ERR_PTR(n) ((void *)(intptr_t)(n))
#define dev_dbg(...) ((void)0)
#define dev_info(...) ((void)0)
#define INIT_DELAYED_WORK(w,f) ((void)(w), (void)(f))
static bool uke=true, link_ok=true, replace_request, property_present=true, supply_present=true;
static int response, requests, queued, last_value, puts, links;
static struct power_supply supply;
static struct dwc3 *active;
static bool of_machine_is_compatible(const char *s) { assert(!strcmp(s,"xiaomi,uke")); return uke; }
static unsigned int msecs_to_jiffies(unsigned int ms) { return ms; }
static bool schedule_delayed_work(struct delayed_work *w, unsigned int delay) { assert(w==&active->vbus_draw_work && delay==100); queued++; return true; }
static int power_supply_set_property(struct power_supply *p, int prop, const union power_supply_propval *v) {
 assert(p==&supply && prop==POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT);
 requests++; last_value=v->intval;
 if (replace_request) active->current_limit=0;
 return response;
}
static int device_property_read_string(struct device *d, const char *key, const char **v) { (void)d; assert(!strcmp(key,"usb-psy-name")); *v="qcom-battmgr-usb"; return property_present ? 0 : -EINVAL; }
static struct power_supply *power_supply_get_by_name(const char *name) { assert(!strcmp(name,"qcom-battmgr-usb")); return supply_present ? &supply : NULL; }
static void power_supply_put(struct power_supply *p) { assert(p==&supply); puts++; }
static void *device_link_add(struct device *consumer, struct device *supplier, unsigned int flags) { assert(consumer==active->dev && supplier==supply.dev.parent && flags==DL_FLAG_AUTOREMOVE_CONSUMER); links++; return link_ok ? &supply : NULL; }
C
for name in dwc3_vbus_draw_work dwc3_get_usb_power_supply; do
    awk -v name="$name" '
      $0 ~ "^static (void|struct power_supply \\*) ?" name "\\(" {emit=1}
      emit {print} emit && /^}/ {exit}' "$kernel/drivers/usb/dwc3/core.c"
done
cat <<'C'
int main(void) {
 struct device consumer={0}, supplier={0};
 struct dwc3 d={.usb_psy=&supply,.dev=&consumer,.current_limit=500};
 active=&d; supply.dev.parent=&supplier;
 assert(dwc3_get_usb_power_supply(&d)==&supply && links==1 && puts==0);
 link_ok=false;
 assert(dwc3_get_usb_power_supply(&d)==ERR_PTR(-EINVAL) && links==2 && puts==1);
 uke=false;
 assert(dwc3_get_usb_power_supply(&d)==&supply && links==2);
 property_present=false; assert(dwc3_get_usb_power_supply(&d)==NULL);
 property_present=true; supply_present=false;
 assert(dwc3_get_usb_power_supply(&d)==ERR_PTR(-EPROBE_DEFER));
 supply_present=true;
 uke=true; response=-EAGAIN;
 for(int i=0;i<51;i++) dwc3_vbus_draw_work(&d.vbus_draw_work.work);
 assert(requests==51 && queued==50 && last_value==500000);
 response=0; dwc3_vbus_draw_work(&d.vbus_draw_work.work); assert(queued==50);
 d.vbus_draw_retries=0; response=-EINVAL;
 dwc3_vbus_draw_work(&d.vbus_draw_work.work); assert(queued==50);
 response=-EAGAIN; uke=false;
 dwc3_vbus_draw_work(&d.vbus_draw_work.work); assert(queued==50);
 uke=true; replace_request=true;
 dwc3_vbus_draw_work(&d.vbus_draw_work.work); assert(queued==50 && d.current_limit==0);
 replace_request=false; response=0;
 dwc3_vbus_draw_work(&d.vbus_draw_work.work); assert(last_value==0);
 return 0;
}
C
} > "$work/contract.c"
gcc -std=gnu11 -O2 -Wall -Wextra -Werror "$work/contract.c" -o "$work/contract"
"$work/contract"
echo 'DWC3 bounded readiness retry, terminal errors, superseding budgets and supplier-link admission passed; physical lifecycle remains unverified'
