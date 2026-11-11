#!/usr/bin/env bash
# COPR-only actual notification and counter validation. No device operations.
set -Eeuo pipefail
source=${1:?Pass prepared drivers/power/supply/qcom_battmgr.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
cat <<'C'
#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <sys/types.h>
typedef uint32_t u32;
typedef int32_t s32;
typedef uint32_t __le32;
typedef uint16_t __le16;
typedef uint8_t u8;
struct pmic_glink_hdr { __le32 owner, type, opcode; };
enum { QCOM_BATTMGR_OTHER, QCOM_BATTMGR_UKE };
struct power_supply { unsigned changes; };
struct qcom_battmgr {
 int variant;
 void *dev;
 struct power_supply *bat_psy, *usb_psy, *wls_psy;
 struct { bool valid; } info;
};
static unsigned errors;
#define le32_to_cpu(value) (value)
#define dev_warn(...) ((void)0)
#define dev_err(...) ((void)errors++)
#define fallthrough __attribute__((fallthrough))
static void power_supply_changed(struct power_supply *s) { assert(s); s->changes++; }
C
awk '/^#define (BATT_|BATTMGR_STRING_LEN|BATTMGR_CHEMISTRY_LEN|NOTIF_)/ {print}
 /^struct qcom_battmgr_message / {emit=1}
 emit {print} emit && /^};/ {emit=0}' "$source"
awk '/^static void qcom_battmgr_notification\(/ {emit=1}
 emit {print} emit && /^}/ {found=1;exit} END {if(!found)exit 1}' "$source"
awk '/^static int qcom_battmgr_uke_validate\(/ {emit=1}
 emit {print} emit && /^}/ {found=1;exit} END {if(!found)exit 1}' "$source"
cat <<'C'
int main(void) {
 struct power_supply bat={0}, usb={0}, wls={0};
 struct qcom_battmgr b={.variant=QCOM_BATTMGR_UKE,.bat_psy=&bat,.usb_psy=&usb,.wls_psy=&wls};
 struct qcom_battmgr_message m={.notification=0x50};
 const int len=sizeof(m.hdr)+sizeof(m.notification);
 qcom_battmgr_notification(&b,&m,len);
 assert(bat.changes==1 && usb.changes==0 && wls.changes==0 && errors==0);
 m.notification=0x12340050;
 qcom_battmgr_notification(&b,&m,len);
 assert(bat.changes==2);
 qcom_battmgr_notification(&b,&m,len-1);
 qcom_battmgr_notification(&b,&m,len+1);
 qcom_battmgr_notification(&b,&m,0);
 assert(bat.changes==2 && errors==0);
 b.variant=QCOM_BATTMGR_OTHER;
 m.notification=0x50;
 qcom_battmgr_notification(&b,&m,len);
 assert(bat.changes==2 && errors==1);
 const unsigned battery_events[]={NOTIF_BAT_INFO,NOTIF_BAT_STATUS,NOTIF_BAT_PROPERTY,NOTIF_BAT_CHARGING_STATE};
 for(unsigned i=0;i<sizeof(battery_events)/sizeof(battery_events[0]);i++) {
  m.notification=battery_events[i]; b.info.valid=true;
  qcom_battmgr_notification(&b,&m,len);
  assert(bat.changes==3+i);
  assert(b.info.valid==(battery_events[i]!=NOTIF_BAT_INFO));
 }
 m.notification=NOTIF_USB_PROPERTY; qcom_battmgr_notification(&b,&m,len);
 m.notification=NOTIF_WLS_PROPERTY; qcom_battmgr_notification(&b,&m,len);
 assert(bat.changes==6 && usb.changes==1 && wls.changes==1 && errors==1);
 m.notification=0x66; qcom_battmgr_notification(&b,&m,len);
 assert(bat.changes==6 && errors==2);
 const unsigned cycles[]={0,1,7,INT_MAX};
 for(unsigned i=0;i<sizeof(cycles)/sizeof(cycles[0]);i++)assert(qcom_battmgr_uke_validate(BATT_CYCLE_COUNT,cycles[i])==0);
 assert(qcom_battmgr_uke_validate(BATT_CYCLE_COUNT,(u32)INT_MAX+1)==-ENODATA);
 assert(qcom_battmgr_uke_validate(BATT_CYCLE_COUNT,UINT_MAX)==-ENODATA);
 const unsigned positive[]={BATT_VOLT_OCV,BATT_VOLT_NOW,BATT_VOLT_MAX,BATT_CHG_FULL_DESIGN,BATT_CHG_FULL,BATT_TTF_AVG,BATT_TTE_AVG,BATT_RESISTANCE};
 for(unsigned i=0;i<sizeof(positive)/sizeof(positive[0]);i++){
  assert(qcom_battmgr_uke_validate(positive[i],0)==-ENODATA);
  assert(qcom_battmgr_uke_validate(positive[i],1)==0);
  assert(qcom_battmgr_uke_validate(positive[i],UINT_MAX)==-ENODATA);
 }
 assert(qcom_battmgr_uke_validate(BATT_CAPACITY,0)==0);
 assert(qcom_battmgr_uke_validate(BATT_CAPACITY,10000)==0);
 assert(qcom_battmgr_uke_validate(BATT_CAPACITY,10001)==-ENODATA);
 assert(qcom_battmgr_uke_validate(BATT_SOH,100)==0);
 assert(qcom_battmgr_uke_validate(BATT_SOH,101)==-ENODATA);
 return 0;
}
C
} > "$work/check.c"
flags=(-std=gnu11 -O2 -Wall -Wextra -Werror)
if [[ ${SANITIZE:-0} == 1 ]];then flags+=(-O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer);fi
"${CC:-cc}" "${flags[@]}" "$work/check.c" -o "$work/check"
"$work/check"
printf 'Actual battmgr event/health callbacks passed:%s/sanitize%s; no firmware or physical acceptance.\n' "${CC:-cc}" "${SANITIZE:-0}"
