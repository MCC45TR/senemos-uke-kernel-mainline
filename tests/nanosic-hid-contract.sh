#!/usr/bin/env bash
# COPR only: decode the actual HID descriptor and execute its feature callback.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
cat > "$stage/check.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
typedef uint8_t u8;
#define HID_FEATURE_REPORT 2
#define HID_REQ_GET_REPORT 1
struct hid_device {unsigned product;};
#include "nanosic-uke-hid.h"
C
awk '/^#define NANOSIC_TOUCH_/ {print}' "$owner/src/pogo/nanosic-uke-protocol.h" >> "$stage/check.c"
awk '/^static int uke_nano_hid_raw\(/ {p=1} p{print} p&&/^}/{exit}' \
 "$owner/src/pogo/hid-nanosic-uke.c" >> "$stage/check.c"
cat >> "$stage/check.c" <<'C'
static void descriptor(void) {
 unsigned page=0,logical=0,physical=0,unit=0,exponent=0,size=0,count=0,id=0;
 unsigned usage[8]={0},usages=0,x=0,y=0,fingers=0,max_fields=0;
 unsigned input_bits=0,feature_bits=0,depth=0;
 assert(sizeof(hid_keyboard_descriptor)>61&&sizeof(hid_touchpad_descriptor)==277);
 for(size_t offset=0;offset<sizeof(hid_touchpad_descriptor);) {
  unsigned prefix=hid_touchpad_descriptor[offset++];assert(prefix!=0xfe);
  unsigned bytes=prefix&3;bytes=bytes==3?4:bytes;
  assert(offset+bytes<=sizeof(hid_touchpad_descriptor));
  unsigned value=0;for(unsigned j=0;j<bytes;j++)value|=(unsigned)hid_touchpad_descriptor[offset++]<<(8*j);
  unsigned type=(prefix>>2)&3,tag=prefix>>4;
  if(type==1) {
   switch(tag) {
   case 0:page=value;break;case 2:logical=value;break;case 4:physical=value;break;
   case 5:exponent=value;break;case 6:unit=value;break;case 7:size=value;break;
   case 8:id=value;break;case 9:count=value;break;
   default:break;
   }
  } else if(type==2&&tag==0) {
   assert(usages<8);usage[usages++]=(page<<16)|value;
  } else if(type==0) {
   assert(id==0||id==0x19);
   if(tag==10) {
    depth++;if(usages&&usage[0]==0x0d0022)fingers++;
   } else if(tag==12) {assert(depth);depth--;}
   else if(tag==8||tag==11) {
    assert(id==0x19&&size&&count);
    if(tag==8)input_bits+=size*count;else feature_bits+=size*count;
    for(unsigned j=0;j<usages;j++) {
     if(tag==8&&(usage[j]==0x10030||usage[j]==0x10031)) {
      assert(size==16&&count==1&&unit==0x11&&exponent==0x0f);
      if(usage[j]==0x10030){assert(logical==3199&&physical==94);x++;}
      else {assert(logical==2135&&physical==42);y++;}
     }
     if(usage[j]==0x0d0054||usage[j]==0x0d0055) {
      assert(size==8&&count==1&&logical==8);
      if(tag==11&&usage[j]==0x0d0055)max_fields++;
     }
    }
   }
   usages=0;
  }
 }
 /* OEM has three repeated logical collections; only the first repeats Finger. */
 assert(!depth&&fingers==1&&x==3&&y==3&&max_fields==1);
 assert(input_bits==160&&feature_bits==2056); /*21-byte input,258-byte feature.*/
 assert(NANOSIC_TOUCH_X_MAX==3199&&NANOSIC_TOUCH_Y_MAX==2135);
 assert(NANOSIC_TOUCH_CONTACTS_PER_REPORT==3&&NANOSIC_TOUCH_MAX_CONTACTS==8);
}
int main(void) {
 descriptor();
 struct hid_device touch={.product=0xa1},keyboard={.product=0xa3};u8 data[258];
 memset(data,0xa5,sizeof(data));
 assert(uke_nano_hid_raw(&touch,0x19,data,sizeof(data),2,1)==2&&data[0]==0x19&&data[1]==8&&data[2]==0xa5);
 assert(uke_nano_hid_raw(&touch,0x19,data,2,2,1)==2);
 for(size_t len=0;len<2;len++)assert(uke_nano_hid_raw(&touch,0x19,data,len,2,1)==-EOPNOTSUPP);
 assert(uke_nano_hid_raw(&keyboard,0x19,data,sizeof(data),2,1)==-EOPNOTSUPP);
 assert(uke_nano_hid_raw(&touch,0x18,data,sizeof(data),2,1)==-EOPNOTSUPP);
 assert(uke_nano_hid_raw(&touch,0x19,data,sizeof(data),0,1)==-EOPNOTSUPP);
 assert(uke_nano_hid_raw(&touch,0x19,data,sizeof(data),2,9)==-EOPNOTSUPP);
 puts("PASS: actual OEM HID geometry/units,21-byte hybrid input,8-contact limit and bounded feature callback; synthetic only");
}
C
"${CC:-cc}" -std=gnu11 -O1 -g -Wall -Wextra -Werror ${CFLAGS:-} \
 -I"$owner/src/pogo" "$stage/check.c" -o "$stage/check"
"$stage/check"
