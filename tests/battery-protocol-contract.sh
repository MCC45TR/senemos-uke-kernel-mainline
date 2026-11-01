#!/usr/bin/env bash
# Host-only requests and replies through the actual battery driver functions.
set -Eeuo pipefail
kernel=${1:?Pass the prepared kernel source directory}
source=$kernel/drivers/power/supply/qcom_battmgr.c
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
cat <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <errno.h>
#include <limits.h>
typedef uint32_t u32;
typedef uint32_t __le32;
typedef uint16_t __le16;
typedef uint8_t u8;
struct work_struct { int unused; };
struct delayed_work { struct work_struct work; };
struct completion { int done; };
struct mutex { int unused; };
struct device_node { bool uke; };
struct device { struct device *parent; struct device_node *of_node; };
struct platform_device { struct device dev; };
struct of_device_id { const char *compatible; const void *data; };
#define BIT(n) (1UL << (n))
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
enum power_supply_property { POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT };
enum { POWER_SUPPLY_USB_TYPE_UNKNOWN, POWER_SUPPLY_USB_TYPE_SDP, POWER_SUPPLY_USB_TYPE_PD };
union power_supply_propval { int intval; };
struct power_supply { void *drvdata; };
static void *power_supply_get_drvdata(struct power_supply *psy) { return psy->drvdata; }
static void mutex_lock(struct mutex *m) { assert(!m->unused); m->unused=1; }
static void mutex_unlock(struct mutex *m) { assert(m->unused); m->unused=0; }
#define cpu_to_le32(v) ((uint32_t)(v))
#define le32_to_cpu(v) ((uint32_t)(v))
#define dev_warn(...) ((void)0)
#define dev_info(...) ((void)0)
#define DIV_ROUND_CLOSEST(x,d) ({ typeof(x) v=(x); typeof(d) n=(d); (v>0 ? (v+n/2)/n : (v-n/2)/n); })
static void complete(struct completion *c) { c->done++; }
static void strscpy(char *dst, const char *src, size_t size) {
 size_t n=strnlen(src,size-1); memcpy(dst,src,n); dst[n]=0;
}
C
awk '/^#define PMIC_GLINK_/ {print}
     /^struct pmic_glink_hdr/ {emit=1} emit {print} emit && /^};/ {emit=0}' \
    "$kernel/include/linux/soc/qcom/pmic_glink.h"
awk '/^#define BATTMGR_CHEMISTRY_LEN/ {emit=1}
     /^static int qcom_battmgr_request\(/ {emit=0} emit {print}' "$source"
awk '/^enum \{/ {emit=1} /^struct pmic_glink_data \{/ {emit=1}
     emit {print} emit && /^};/ {emit=0}' "$kernel/drivers/soc/qcom/pmic_glink.c"
awk '/^static const struct pmic_glink_data pmic_glink_uke_data/ {emit=1}
     emit {print} emit && /^MODULE_DEVICE_TABLE/ {exit}' \
    "$kernel/drivers/soc/qcom/pmic_glink.c" | sed '/^MODULE_DEVICE_TABLE/d'
cat <<'C'
static struct qcom_battmgr_property_request sent;
static int requests, request_result;
static int qcom_battmgr_request(struct qcom_battmgr *b, void *p, size_t n) {
 assert(b && n==sizeof(sent)); memcpy(&sent,p,n); requests++; return request_result;
}
static bool uke_root;
static const struct of_device_id *match_result;
static const struct of_device_id *of_match_device(const void *table, const struct device *dev) {
 (void)table; (void)dev; return match_result;
}
static bool of_machine_is_compatible(const char *name) {
 assert(!strcmp(name,"xiaomi,uke")); return uke_root;
}
static bool of_device_is_compatible(const struct device_node *node, const char *name) {
 assert(!strcmp(name,"qcom,usb-snps-eusb2-phy") || !strcmp(name,"qcom,cliffs-adsp-pas")); return node->uke;
}
struct usb_phy { struct device *dev; int (*set_power)(struct usb_phy *, unsigned int); };
struct dwc3 { struct usb_phy *usb2_phy; struct power_supply *usb_psy; unsigned int current_limit, vbus_draw_retries; struct delayed_work vbus_draw_work; };
struct usb_gadget { struct dwc3 *dwc; };
static int scheduled, legacy;
static struct dwc3 *gadget_to_dwc(struct usb_gadget *g) { return g->dwc; }
#define WRITE_ONCE(x, v) ((x)=(v))
static void *system_wq;
static void mod_delayed_work(void *q, struct delayed_work *w, unsigned int delay) { (void)q; (void)w; assert(delay==0); scheduled++; }
static int usb_phy_set_power(struct usb_phy *p, unsigned int mA) { (void)p; (void)mA; legacy++; return 42; }
static const struct of_device_id qcom_battmgr_of_variants[]={{0}};
C
for name in uke_battery_property request_property usb_set_property usb_is_writeable sm8350_callback; do
    awk -v name="qcom_battmgr_$name" '
        $0 ~ "^static (int|void) " name "\\(" {emit=1}
        emit {print} emit && /^}/ {exit}' "$source"
done
awk '/^static int dwc3_gadget_vbus_draw\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$kernel/drivers/usb/dwc3/gadget.c"
cat <<'C'
static void select_variant(struct qcom_battmgr *battmgr, struct device *dev) {
 const struct of_device_id *match;
C
awk '/match = of_match_device\(qcom_battmgr_of_variants/ {emit=1}
     emit && /ret = qcom_battmgr_charge_control_thresholds_init/ {exit}
     emit {print}' "$source"
cat <<'C'
}
struct rproc_policy { bool auto_boot, recovery_disabled; };
static void select_rproc_policy(struct rproc_policy *rproc, struct device *dev) {
 const struct rproc_policy baseline={0}, *desc=&baseline;
 struct platform_device platform={.dev=*dev}, *pdev=&platform;
C
awk '/rproc->auto_boot = desc->auto_boot;/ {emit=1} emit {print} emit && /^\t}/ {exit}' "$kernel/drivers/remoteproc/qcom_q6v5_pas.c"
cat <<'C'
}
static void reply(struct qcom_battmgr *b, unsigned int opcode,
                  unsigned int property, uint32_t value, uint32_t error) {
 struct qcom_battmgr_message m={.hdr.opcode=opcode};
 m.intval.property=property; m.intval.value=value; m.intval.result=error;
 b->ack.done=0; b->error=0;
 qcom_battmgr_sm8350_callback(b,&m,sizeof(m.hdr)+sizeof(m.intval));
 assert(b->ack.done==1);
}
int main(void) {
 assert(pmic_glink_uke_data.client_mask==BIT(PMIC_GLINK_CLIENT_BATT));
 assert(!strcmp(pmic_glink_uke_data.charger_pdr_service_name,"tms/servreg"));
 assert(!strcmp(pmic_glink_uke_data.charger_pdr_service_path,"msm/adsp/charger_pd"));
 assert(!strcmp(pmic_glink_of_match[0].compatible,"xiaomi,uke-pmic-glink"));
 assert(pmic_glink_of_match[0].data==&pmic_glink_uke_data);
 assert(pmic_glink_adsp_data.client_mask==(BIT(PMIC_GLINK_CLIENT_BATT)|BIT(PMIC_GLINK_CLIENT_ALTMODE)|BIT(PMIC_GLINK_CLIENT_UCSI)));
 struct qcom_battmgr b={.variant=QCOM_BATTMGR_UKE};
 /* Independent wire IDs from the pinned Uke OEM enum, including its inserted ID 12. */
 const int wire[]={0,1,2,3,4,5,6,7,8,9,10,11,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27};
 for (unsigned int i=0;i<sizeof(wire)/sizeof(wire[0]);i++) {
  assert(qcom_battmgr_uke_battery_property(i,true)==wire[i]);
  assert(qcom_battmgr_uke_battery_property(wire[i],false)==(int)i);
  if (i==BATT_POWER_NOW) {
   int count=requests;
   assert(qcom_battmgr_request_property(&b,BATTMGR_BAT_PROPERTY_GET,i,0)==-ENODATA && requests==count);
   continue;
  }
  assert(qcom_battmgr_request_property(&b,BATTMGR_BAT_PROPERTY_GET,i,0)==0);
  assert(sent.property==(unsigned int)wire[i] && sent.hdr.owner==32778 && sent.value==0);
 }
 int before=requests;
 for (int id=-1;id<=30;id++) {
  if (id<0 || id>26) assert(qcom_battmgr_request_property(&b,BATTMGR_BAT_PROPERTY_GET,id,0)==-EINVAL);
 }
 assert(requests==before);
 assert(qcom_battmgr_uke_battery_property(12,false)==-EINVAL);
 assert(qcom_battmgr_uke_battery_property(28,false)==-EINVAL);
 assert(qcom_battmgr_request_property(&b,BATTMGR_BAT_PROPERTY_SET,10,900)==-EOPNOTSUPP && requests==before);
 request_result=-ETIMEDOUT;
 assert(qcom_battmgr_request_property(&b,BATTMGR_BAT_PROPERTY_GET,12,0)==-ETIMEDOUT);
 request_result=0;
 assert(qcom_battmgr_request_property(&b,BATTMGR_USB_PROPERTY_GET,12,0)==0 && sent.property==12);
 reply(&b,BATTMGR_BAT_PROPERTY_GET,13,2550,0); assert((int)b.status.temperature==255);
 reply(&b,BATTMGR_BAT_PROPERTY_GET,13,(uint32_t)-500,0); assert((int)b.status.temperature==-50);
 reply(&b,BATTMGR_BAT_PROPERTY_GET,15,8850,0); assert(b.info.charge_count==8850000);
 reply(&b,BATTMGR_BAT_PROPERTY_GET,15,2147484,0); assert(b.error==-ERANGE && b.info.charge_count==8850000);
 reply(&b,BATTMGR_BAT_PROPERTY_GET,9,(uint32_t)-500000,0); assert(b.status.current_now==500000);
 reply(&b,BATTMGR_BAT_PROPERTY_GET,9,500000,0); assert(b.status.current_now==-500000);
 reply(&b,BATTMGR_BAT_PROPERTY_GET,9,(uint32_t)INT_MIN,0); assert(b.error==-ERANGE && b.status.current_now==-500000);
 b.variant=QCOM_BATTMGR_SM8350;
 reply(&b,BATTMGR_BAT_PROPERTY_GET,14,8850,0); assert(b.info.charge_count==8850);
 reply(&b,BATTMGR_BAT_PROPERTY_GET,9,(uint32_t)-500000,0); assert(b.status.current_now==-500000);
 b.variant=QCOM_BATTMGR_UKE;
 reply(&b,BATTMGR_BAT_PROPERTY_GET,4,1250,0); assert(b.status.percent==12);
 reply(&b,BATTMGR_BAT_PROPERTY_GET,12,1000000,0); assert(b.error==-ENODATA && (int)b.status.temperature==-50);
 reply(&b,BATTMGR_BAT_PROPERTY_GET,28,9,0); assert(b.error==-ENODATA);
 reply(&b,BATTMGR_BAT_PROPERTY_GET,13,1000,EPERM); assert(b.error==EPERM && (int)b.status.temperature==-50);
 struct qcom_battmgr_message m={.hdr.opcode=BATTMGR_BAT_PROPERTY_GET};
 m.strval.property=19; strcpy(m.strval.model,"OEM protocol fixture");
 b.ack.done=0;
 qcom_battmgr_sm8350_callback(&b,&m,sizeof(m.hdr)+sizeof(m.strval));
 assert(!strcmp(b.info.model_number,"OEM protocol fixture") && b.ack.done==1);
 b.ack.done=0; b.error=0;
 qcom_battmgr_sm8350_callback(&b,&m,sizeof(m.hdr)+sizeof(m.intval));
 assert(b.error==-ENODATA && b.ack.done==0);
 reply(&b,BATTMGR_USB_PROPERTY_GET,0,1,0); assert(b.usb.online);
 struct power_supply usb={.drvdata=&b};
 union power_supply_propval budget={.intval=500000};
 assert(qcom_battmgr_usb_is_writeable(&usb,POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT));
 before=requests;
 assert(qcom_battmgr_usb_set_property(&usb,POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT,&budget)==-EAGAIN && requests==before);
 b.service_up=true; b.usb.usb_type=POWER_SUPPLY_USB_TYPE_SDP; b.usb.current_max=500000;
 assert(qcom_battmgr_usb_set_property(&usb,POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT,&budget)==0);
 assert(requests==before+4 && sent.hdr.opcode==BATTMGR_USB_PROPERTY_SET && sent.property==5 && sent.value==500000);
 for (int invalid=0;invalid<3;invalid++) {
  before=requests; budget.intval=invalid==0?-1:invalid==1?500001:1000000;
  assert(qcom_battmgr_usb_set_property(&usb,POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT,&budget)==-EINVAL && requests==before);
 }
 budget.intval=500000; b.usb.current_max=100000;
 assert(qcom_battmgr_usb_set_property(&usb,POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT,&budget)==-EINVAL);
 b.usb.current_max=500000; b.usb.online=false;
 before=requests;
 assert(qcom_battmgr_usb_set_property(&usb,POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT,&budget)==-EAGAIN && requests==before+3);
 b.usb.online=true; b.usb.usb_type=POWER_SUPPLY_USB_TYPE_UNKNOWN;
 before=requests;
 assert(qcom_battmgr_usb_set_property(&usb,POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT,&budget)==-EAGAIN && requests==before+3);
 b.usb.usb_type=POWER_SUPPLY_USB_TYPE_SDP; b.usb.current_max=0;
 before=requests;
 assert(qcom_battmgr_usb_set_property(&usb,POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT,&budget)==-EAGAIN && requests==before+3);
 b.usb.current_max=500000; b.usb.usb_type=POWER_SUPPLY_USB_TYPE_PD;
 before=requests;
 assert(qcom_battmgr_usb_set_property(&usb,POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT,&budget)==-EINVAL && requests==before+3);
 b.usb.usb_type=POWER_SUPPLY_USB_TYPE_UNKNOWN;
 assert(qcom_battmgr_usb_set_property(&usb,POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT,&budget)==-EAGAIN);
 b.usb.usb_type=POWER_SUPPLY_USB_TYPE_SDP; request_result=-ETIMEDOUT;
 assert(qcom_battmgr_usb_set_property(&usb,POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT,&budget)==-ETIMEDOUT && !b.lock.unused);
 request_result=0;
 reply(&b,BATTMGR_USB_PROPERTY_SET,5,500000,EPERM); assert(b.error==EPERM);
 m.hdr.opcode=0x50; b.ack.done=0;
 qcom_battmgr_sm8350_callback(&b,&m,sizeof(m.hdr)+sizeof(m.intval)); assert(!b.ack.done);
 m.hdr.opcode=0xdead;
 qcom_battmgr_sm8350_callback(&b,&m,sizeof(m.hdr)+sizeof(m.intval)); assert(!b.ack.done);
 b.variant=QCOM_BATTMGR_SM8350;
 assert(!qcom_battmgr_usb_is_writeable(&usb,POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT));
 assert(qcom_battmgr_usb_set_property(&usb,POWER_SUPPLY_PROP_INPUT_CURRENT_LIMIT,&budget)==-EOPNOTSUPP);
 assert(qcom_battmgr_request_property(&b,BATTMGR_BAT_PROPERTY_GET,12,0)==0 && sent.property==12);
 reply(&b,BATTMGR_BAT_PROPERTY_GET,12,2550,0); assert(b.status.temperature==255);
 struct device d={0};
 struct of_device_id matched={.data=(void *)QCOM_BATTMGR_SM8550};
 uke_root=false; match_result=NULL; select_variant(&b,&d); assert(b.variant==QCOM_BATTMGR_SM8350);
 match_result=&matched; select_variant(&b,&d); assert(b.variant==QCOM_BATTMGR_SM8550);
 uke_root=true; select_variant(&b,&d); assert(b.variant==QCOM_BATTMGR_UKE && b.unit==QCOM_BATTMGR_UNIT_mAh);
 match_result=NULL; select_variant(&b,&d); assert(b.variant==QCOM_BATTMGR_UKE);
 struct device_node node={.uke=true}; struct device phydev={.of_node=&node};
 struct usb_phy phy={.dev=&phydev}; struct dwc3 dwc={.usb2_phy=&phy,.usb_psy=&usb};
 struct usb_gadget gadget={.dwc=&dwc};
 assert(dwc3_gadget_vbus_draw(&gadget,500)==0 && dwc.current_limit==500 && scheduled==1 && !legacy);
 dwc.usb_psy=NULL;
 assert(dwc3_gadget_vbus_draw(&gadget,500)==-EOPNOTSUPP && scheduled==1);
 node.uke=false;
 assert(dwc3_gadget_vbus_draw(&gadget,500)==42 && legacy==1 && scheduled==1);
 node.uke=true; phy.set_power=usb_phy_set_power;
 assert(dwc3_gadget_vbus_draw(&gadget,500)==42 && legacy==2);
 struct rproc_policy r={0}; uke_root=false; node.uke=true;
 select_rproc_policy(&r,&phydev); assert(!r.auto_boot && !r.recovery_disabled);
 uke_root=true; node.uke=false;
 select_rproc_policy(&r,&phydev); assert(!r.auto_boot && !r.recovery_disabled);
 node.uke=true;
 select_rproc_policy(&r,&phydev); assert(r.auto_boot && r.recovery_disabled);
}
C
} > "$work/check.c"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror "$work/check.c" -o "$work/check"
"$work/check"
echo 'Uke battery: OEM request/reply IDs, signed temperature/current, model shape, errors and unchanged non-Uke/USB paths passed; charging hardware is unverified'
