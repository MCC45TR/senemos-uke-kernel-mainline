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
typedef uint32_t u32;
typedef uint32_t __le32;
typedef uint16_t __le16;
typedef uint8_t u8;
struct work_struct { int unused; };
struct completion { int done; };
struct mutex { int unused; };
struct device { struct device *parent; };
struct of_device_id { const char *compatible; const void *data; };
#define BIT(n) (1UL << (n))
#define cpu_to_le32(v) ((uint32_t)(v))
#define le32_to_cpu(v) ((uint32_t)(v))
#define dev_warn(...) ((void)0)
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
static const struct of_device_id qcom_battmgr_of_variants[]={{0}};
C
for name in uke_battery_property request_property sm8350_callback; do
    awk -v name="qcom_battmgr_$name" '
        $0 ~ "^static (int|void) " name "\\(" {emit=1}
        emit {print} emit && /^}/ {exit}' "$source"
done
cat <<'C'
static void select_variant(struct qcom_battmgr *battmgr, struct device *dev) {
 const struct of_device_id *match;
C
awk '/match = of_match_device\(qcom_battmgr_of_variants/ {emit=1}
     emit && /ret = qcom_battmgr_charge_control_thresholds_init/ {exit}
     emit {print}' "$source"
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
 reply(&b,BATTMGR_BAT_PROPERTY_GET,15,123456,0); assert(b.info.charge_count==123456);
 reply(&b,BATTMGR_BAT_PROPERTY_GET,9,(uint32_t)-500000,0); assert(b.status.current_now==-500000);
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
 b.variant=QCOM_BATTMGR_SM8350;
 assert(qcom_battmgr_request_property(&b,BATTMGR_BAT_PROPERTY_GET,12,0)==0 && sent.property==12);
 reply(&b,BATTMGR_BAT_PROPERTY_GET,12,2550,0); assert(b.status.temperature==255);
 struct device d={0};
 struct of_device_id matched={.data=(void *)QCOM_BATTMGR_SM8550};
 uke_root=false; match_result=NULL; select_variant(&b,&d); assert(b.variant==QCOM_BATTMGR_SM8350);
 match_result=&matched; select_variant(&b,&d); assert(b.variant==QCOM_BATTMGR_SM8550);
 uke_root=true; select_variant(&b,&d); assert(b.variant==QCOM_BATTMGR_UKE);
 match_result=NULL; select_variant(&b,&d); assert(b.variant==QCOM_BATTMGR_UKE);
}
C
} > "$work/check.c"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror "$work/check.c" -o "$work/check"
"$work/check"
echo 'Uke battery: OEM request/reply IDs, signed temperature/current, model shape, errors and unchanged non-Uke/USB paths passed; charging hardware is unverified'
